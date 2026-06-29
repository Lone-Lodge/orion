//! Expressions, patterns, and the operator vocabulary.

use super::Span;

#[derive(Clone, Debug, PartialEq)]
pub enum Expr {
    Int(i64),
    Float(f64),
    Str(String),
    Bool(bool),
    /// `none` — the absent optional value.
    None,
    /// A name. Carries its span so semantic errors can point at it.
    Var(String, Span),
    /// `base.name` or `base?.name`. `safe = true` short-circuits the whole
    /// chain to `none` on a `none` base or missing component.
    Field { base: Box<Expr>, name: String, safe: bool },
    /// `callee(args)` — usually a `Var` callee, or a `Field` for UFCS.
    Call { callee: Box<Expr>, args: Vec<Expr> },
    Unary { op: UnOp, rhs: Box<Expr> },
    Binary { op: BinOp, lhs: Box<Expr>, rhs: Box<Expr> },
    /// `if cond then a else b` — the expression form.
    If {
        cond: Box<Expr>,
        then: Box<Expr>,
        otherwise: Box<Expr>,
    },
    /// `lo..<hi` (exclusive) or `lo...hi` (inclusive).
    Range {
        lo: Box<Expr>,
        hi: Box<Expr>,
        inclusive: bool,
    },
    /// `[a, b, c]` — a list literal.
    List(Vec<Expr>),
    /// `{key: value, …}` — a map literal (`{}` is the empty map).
    Map(Vec<(Expr, Expr)>),
    /// `value else default` — yields default when value is `none`.
    OrElse {
        value: Box<Expr>,
        default: Box<Expr>,
    },
    /// `[projection for var with components [where filter]]`.
    Comprehension {
        projection: Box<Expr>,
        var: String,
        components: Vec<String>,
        filter: Option<Box<Expr>>,
    },
    /// `Kind{ field: value, … }` — a struct / component literal.
    Struct {
        name: String,
        fields: Vec<(String, Expr)>,
    },
    /// `spawn Kind{…}, Kind{…}` — yields an Entity.
    Spawn(Vec<Expr>),
    /// `match scrutinee:` + arms.
    Match {
        scrutinee: Box<Expr>,
        arms: Vec<MatchArm>,
    },
    /// `"text {expr} more"` — concatenated into Text at runtime.
    Interp(Vec<Expr>),
    /// `fn(x, y) = expr` — an anonymous function. Captures every variable
    /// in scope when evaluated (value-capture; the closure is a snapshot).
    Lambda {
        params: Vec<String>,
        body: Box<Expr>,
    },
    /// `comptime EXPR` — §10 metaprogramming. The constant folder evaluates
    /// the inner expression at parse/check time and the entire node
    /// reduces to a literal. Falls through at runtime (Zig-style).
    Comptime(Box<Expr>),
    /// `name = EXPR` inside a call argument list — §11 named call form.
    /// `spawn(x = 3, y = 4)` produces two of these; the interpreter
    /// matches them by name against the callee's declared param list.
    NamedArg { name: String, value: Box<Expr> },
}

#[derive(Clone, Debug, PartialEq)]
pub struct MatchArm {
    pub pattern: Pattern,
    pub body: Expr,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Pattern {
    Variant {
        name: String,
        bindings: Vec<String>,
        span: Span,
    },
    /// String literal pattern — matches by value equality. Lets
    /// `match name: "mon" -> 1 ...` work without wrapping every label
    /// in an enum variant.
    Str(String),
    /// Integer literal pattern — matches by value.
    Int(i64),
    Wildcard,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum UnOp {
    Not,    // not x
    Neg,    // -x
    BitNot, // ~x  (int only)
}

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
    // bitwise — int operands only
    BitOr,
    BitXor,
    BitAnd,
    Shl,
    Shr,
    Add,
    Sub,
    Mul,
    Div,
    Rem,
}

impl BinOp {
    /// Left/right binding power for precedence climbing. `left < right` makes
    /// the operator left-associative; a higher pair binds tighter. Rust-style
    /// order: shift > & > ^ > | > comparison > and/or.
    pub(crate) fn bp(self) -> (u8, u8) {
        use BinOp::*;
        match self {
            Or => (1, 2),
            And => (3, 4),
            Eq | Ne | Lt | Le | Gt | Ge => (5, 6),
            BitOr => (7, 8),
            BitXor => (9, 10),
            BitAnd => (11, 12),
            Shl | Shr => (13, 14),
            Add | Sub => (15, 16),
            Mul | Div | Rem => (17, 18),
        }
    }
}
