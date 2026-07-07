//! Tests for the M1 parser. Run with `cargo test`.

use orion::ast::*;
use orion::{lex, parse};

fn program(src: &str) -> Program {
    parse(&lex(src).unwrap()).unwrap()
}

#[test]
fn data_with_range_type() {
    let p = program("data Health: hp: 0...1000, max: int");
    assert_eq!(
        p.decls,
        vec![Decl::Data(DataDecl {
            public: false,
            repr_c: false,
            layout: orion::ast::LayoutHint::Auto,
            name: "Health".into(),
            fields: vec![
                Field {
                    name: "hp".into(),
                    ty: Type::Range { lo: 0, hi: 1000, inclusive: true },
                },
                Field {
                    name: "max".into(),
                    ty: Type::Named("int".into()),
                },
            ],
            file: 0,
        })]
    );
}

#[test]
fn fn_expression_form_with_precedence() {
    // `x * 2 + 1` must parse as `(x * 2) + 1`.
    let p = program("fn f(x: int) -> int = x * 2 + 1");
    let Decl::Fn(f) = &p.decls[0] else {
        panic!("expected fn");
    };
    assert_eq!(f.name, "f");
    assert_eq!(f.ret, Some(Type::Named("int".into())));
    let FnBody::Expr(Expr::Binary { op: BinOp::Add, lhs, .. }) = &f.body else {
        panic!("expected top-level Add");
    };
    assert!(matches!(
        **lhs,
        Expr::Binary { op: BinOp::Mul, .. }
    ));
}

#[test]
fn block_body_with_contracts_and_assignment() {
    let p = program(
        "fn damage(target: Entity, amount: int):\n    require amount > 0\n    mut h = target.Health\n    h.hp = max(0, h.hp - amount)\n    ensure h.hp >= 0\n",
    );
    let Decl::Fn(f) = &p.decls[0] else {
        panic!("expected fn");
    };
    let FnBody::Block(stmts) = &f.body else {
        panic!("expected block body");
    };
    assert_eq!(stmts.len(), 4);
    assert!(matches!(stmts[0], Stmt::Require(_)));
    assert!(matches!(stmts[1], Stmt::Bind { .. }));
    assert!(matches!(
        stmts[2],
        Stmt::Assign { op: AssignOp::Set, .. }
    ));
    assert!(matches!(stmts[3], Stmt::Ensure(_)));
}

#[test]
fn param_qualifier_and_default() {
    let p = program("fn f(target: mut Health, gold: int = 0): require true");
    let Decl::Fn(f) = &p.decls[0] else {
        panic!("expected fn");
    };
    assert_eq!(f.params[0].qualifier, Some(Qualifier::Mut));
    assert_eq!(f.params[1].default, Some(Expr::Int(0)));
}

#[test]
fn spawn_with_components() {
    let p = program("fn s() -> Entity = spawn Player{gold: 0}, Position{x: 0, y: 0}");
    let Decl::Fn(f) = &p.decls[0] else {
        panic!("expected fn");
    };
    let FnBody::Expr(Expr::Spawn(comps)) = &f.body else {
        panic!("expected spawn");
    };
    assert_eq!(comps.len(), 2);
    assert!(matches!(&comps[0], Expr::Struct { name, .. } if name == "Player"));
}

#[test]
fn if_is_an_expression() {
    let p = program("fn f(v: int) -> int = if v < 0 then 0 else v");
    let Decl::Fn(f) = &p.decls[0] else {
        panic!("expected fn");
    };
    assert!(matches!(f.body, FnBody::Expr(Expr::If { .. })));
}
