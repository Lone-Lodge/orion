//! The AST — the shape the parser builds and the evaluator walks. Small on
//! purpose: two node types (`Rule`, `Record`) — an `on` handler is just a `Rule`
//! with a trigger — six statements, and an expression grammar with no surprises.
//! `view` reserves its keyword in the lexer but does not appear here until its
//! slice.

/// A whole parsed source unit: the rules that propose effects and the records
/// that give each kind's fields a type. The evaluator reads only `rules`; the
/// typechecker reads both.
#[derive(Clone, Debug, PartialEq)]
pub struct Program {
    pub rules: Vec<Rule>,
    pub records: Vec<RecordDecl>,
    /// View declarations — the read side: each renders a host-agnostic node tree.
    pub views: Vec<View>,
    /// Entity declarations — authored facts. Each `entity NAME { field = value }`
    /// folds into one `EntitySpawned` plus one `FieldSet` per field.
    pub entities: Vec<EntityDecl>,
    /// Test declarations — executable specifications. Each `test NAME { apply
    /// [...] expect ... }` runs in a fresh session and asserts the expected state.
    pub tests: Vec<TestDecl>,
}

/// One authored entity in source form: a stable name and its initial Facts as
/// (field, expression) pairs. Names resolve globally at load — an identifier on
/// the right-hand side that names another entity becomes a `Ref` automatically.
#[derive(Clone, Debug, PartialEq)]
pub struct EntityDecl {
    pub name: String,
    pub fields: Vec<(String, Expr)>,
}

/// One step a test takes before its assertions: fire a rule, or advance the
/// scheduler. Order matters — `apply gather; tick 5; apply feed` is different
/// from `tick 5; apply gather; apply feed`.
#[derive(Clone, Debug, PartialEq)]
pub enum TestAction {
    /// Apply a named rule to the acting entity.
    Apply(String),
    /// Advance the scheduler `n` ticks, submitting whatever it makes due.
    Tick(u32),
    /// Stamp a field on the acting entity before the next apply — the test's
    /// setup. Auto-require uses this to seed the failing state.
    Set { field: String, value: Expr },
}

/// One test in source form: an ordered list of actions, and a list of
/// (field, expected-expr) pairs checked against the acting entity afterwards.
/// Parsed straight from authored Astra — no Rust per test.
#[derive(Clone, Debug, PartialEq)]
pub struct TestDecl {
    pub name: String,
    pub actions: Vec<TestAction>,
    pub expects: Vec<(String, Expr)>,
}

/// A record: a kind's name and the typed fields its entities carry. This is the
/// schema a field access types against — `record cell { mark: Text }` makes
/// `cell.mark` a `Text` and any other field on a `cell` a type error.
#[derive(Clone, Debug, PartialEq)]
pub struct RecordDecl {
    pub name: String,
    pub fields: Vec<Field>,
}

/// One typed field of a record. `ty` is the written type name (`Int`/`Text`/
/// `Bool` or a kind), resolved to a `Type` by the checker.
#[derive(Clone, Debug, PartialEq)]
pub struct Field {
    pub name: String,
    pub ty: String,
}

/// A named rule: parameters in, a body of statements that propose effects.
#[derive(Clone, Debug, PartialEq)]
pub struct Rule {
    pub name: String,
    pub params: Vec<Param>,
    pub body: Vec<Stmt>,
    /// `Some(event)` when this is an `on Event(...)` handler the host fires via
    /// `dispatch`; `None` for a plain `rule`.
    pub trigger: Option<String>,
    /// Inline postconditions: `expect FIELD = EXPR` lines. Read by the auto-test
    /// generator; ignored at runtime.
    pub expects: Vec<(String, Expr)>,
    /// `every N` modifier: this rule is a TIMER, fired every N ticks by the
    /// scheduler. Auto-registers the rule entity with this Fact at load.
    pub every: Option<i64>,
    /// `on NAME` modifier: this timer rule acts on the named entity. Lands on
    /// the auto-registered rule entity as `on = { ref = NAME }`.
    pub on_target: Option<String>,
}

/// A named view: parameters in, a single root element out — a host-agnostic node
/// tree (the read-side analogue of a rule's effects). The reserved keyword, real.
#[derive(Clone, Debug, PartialEq)]
pub struct View {
    pub name: String,
    pub params: Vec<Param>,
    pub root: ViewElem,
}

/// A node in a view body: an `Element` (a kind, argument expressions, and nested
/// children) or a `For` that expands to one element per row of a source.
#[derive(Clone, Debug, PartialEq)]
pub enum ViewElem {
    Element {
        kind: String,
        args: Vec<Expr>,
        children: Vec<ViewElem>,
    },
    For {
        var: String,
        source: Expr,
        body: Box<ViewElem>,
    },
}

/// A rule parameter, with the optional `: Cell` annotation kept for the
/// typechecker and ignored by the evaluator.
#[derive(Clone, Debug, PartialEq)]
pub struct Param {
    pub name: String,
    pub ty: Option<String>,
}

/// A statement: the six things a rule body can say.
#[derive(Clone, Debug, PartialEq)]
pub enum Stmt {
    /// A guard — a false condition aborts the rule with zero effects.
    Require(Expr),
    /// An immutable binding, in scope for the statements that follow.
    Let { name: String, value: Expr },
    /// Write one field on `entity` — the `Set` effect's source form.
    Set {
        entity: Expr,
        field: String,
        value: Expr,
    },
    /// Mint a fresh entity of a kind with initial field values — the `Spawn`
    /// effect's source form, the second of the two writes. The host mints the id,
    /// so the new entity is not referenceable from within the same rule.
    Spawn {
        kind: String,
        fields: Vec<(String, Expr)>,
    },
    /// Retire an entity — the `Destroy` effect's source form, `spawn`'s inverse.
    /// Names an entity expression; the host decides what retiring means.
    Destroy { entity: Expr },
    /// Announce an event with named data — the `Emit` effect's source form. Shares
    /// `spawn`'s `Kind { field: value }` shape; what an emitted event triggers is
    /// the host's call, not the rule's.
    Emit {
        event: String,
        fields: Vec<(String, Expr)>,
    },
}

/// An expression — what a guard tests, a binding holds, a write stores.
#[derive(Clone, Debug, PartialEq)]
pub enum Expr {
    Int(i64),
    Str(String),
    Bool(bool),
    /// The absent value — what a missing field reads as, what `== empty` tests.
    Empty,
    /// A parameter or `let` binding, resolved against the scope at eval.
    Var(String),
    Field {
        base: Box<Expr>,
        name: String,
    },
    Unary {
        op: UnOp,
        rhs: Box<Expr>,
    },
    Binary {
        op: BinOp,
        lhs: Box<Expr>,
        rhs: Box<Expr>,
    },
    If {
        cond: Box<Expr>,
        then: Box<Expr>,
        otherwise: Box<Expr>,
    },
    /// Every entity of a kind — the host enumerates, the core folds.
    All {
        kind: String,
    },
    /// `count(var in source where filter)` — bound rows that pass the filter.
    Count {
        var: String,
        source: Box<Expr>,
        filter: Option<Box<Expr>>,
    },
    /// `name(arg1, arg2, …)` — a host-registered builtin function. Resolved at
    /// runtime against the host's builtin registry; unknown names raise a
    /// RunError. Plugins (i18n, math, random) install themselves through here.
    Call {
        name: String,
        args: Vec<Expr>,
    },
}

/// A prefix operator.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum UnOp {
    Not,
    Neg,
}

/// An infix operator.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum BinOp {
    Or,
    And,
    Eq,
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
    Add,
    Sub,
    Mul,
    Div,
    Rem,
}

impl BinOp {
    /// Left/right binding power for precedence climbing: left < right makes every
    /// operator left-associative; a higher pair binds tighter.
    pub(crate) fn bp(self) -> (u8, u8) {
        use BinOp::*;
        match self {
            Or => (1, 2),
            And => (3, 4),
            Eq | Ne => (5, 6),
            Lt | Le | Gt | Ge => (7, 8),
            Add | Sub => (9, 10),
            Mul | Div | Rem => (11, 12),
        }
    }
}
