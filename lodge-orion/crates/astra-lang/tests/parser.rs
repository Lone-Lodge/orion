//! The parser falsified through its public face: source in, AST out. The headline
//! case is the whole `place_mark` rule — the same source the evaluator will run —
//! plus the two things a hand-rolled parser most often gets wrong: operator
//! precedence and a malformed write target.

use astra::{BinOp, Expr, Rule, Stmt, lex, parse};

fn rule_of(src: &str) -> Rule {
    parse(&lex(src).unwrap()).unwrap().rules.remove(0)
}

const PLACE_MARK: &str = "rule place_mark(cell):\n\
     require cell.mark == empty\n\
     let placed = count(c in all Cell where c.mark != empty)\n\
     let turn = if placed % 2 == 0 then \"X\" else \"O\"\n\
     require by.plays == turn\n\
     set cell.mark = turn\n";

#[test]
fn parses_the_whole_place_mark_rule() {
    let r = rule_of(PLACE_MARK);
    assert_eq!(r.name, "place_mark");
    assert_eq!(r.params.len(), 1);
    assert_eq!(r.params[0].name, "cell");
    assert_eq!(r.body.len(), 5);
    match &r.body[4] {
        Stmt::Set { field, .. } => assert_eq!(field, "mark"),
        other => panic!("expected a final `set cell.mark`, found {other:?}"),
    }
}

#[test]
fn arithmetic_binds_tighter_than_comparison() {
    // `placed % 2 == 0` must parse as `(placed % 2) == 0`, not `placed % (2 == 0)`.
    let r = rule_of("rule r():\n    require placed % 2 == 0\n");
    let Stmt::Require(expr) = &r.body[0] else {
        panic!("expected a require")
    };
    let Expr::Binary { op, lhs, .. } = expr else {
        panic!("expected a binary op")
    };
    assert_eq!(*op, BinOp::Eq);
    assert!(matches!(**lhs, Expr::Binary { op: BinOp::Rem, .. }));
}

#[test]
fn set_without_a_field_target_is_an_error() {
    let err = parse(&lex("rule r():\n    set x = 1\n").unwrap()).unwrap_err();
    assert!(err.message.contains("field target"), "got: {}", err.message);
}

#[test]
fn parses_a_spawn_with_fields() {
    let r = rule_of("rule drop():\n    spawn LootBag { gold: 50, rare: true }\n");
    match &r.body[0] {
        Stmt::Spawn { kind, fields } => {
            assert_eq!(kind, "LootBag");
            assert_eq!(fields.len(), 2);
            assert_eq!(fields[0].0, "gold");
        }
        other => panic!("expected a spawn, found {other:?}"),
    }
}

#[test]
fn parses_a_destroy() {
    let r = rule_of("rule kill(goblin):\n    destroy goblin\n");
    match &r.body[0] {
        Stmt::Destroy { entity } => assert!(matches!(entity, Expr::Var(n) if n == "goblin")),
        other => panic!("expected a destroy, found {other:?}"),
    }
}

#[test]
fn parses_an_emit() {
    let r = rule_of("rule finish():\n    emit GameOver { winner: by }\n");
    match &r.body[0] {
        Stmt::Emit { event, fields } => {
            assert_eq!(event, "GameOver");
            assert_eq!(fields.len(), 1);
            assert_eq!(fields[0].0, "winner");
        }
        other => panic!("expected an emit, found {other:?}"),
    }
}

#[test]
fn parses_an_on_handler() {
    // An `on` handler parses into a `Rule` whose `trigger` carries the event.
    let r = rule_of("on GoalScored(player):\n    set player.celebrating = true\n");
    assert_eq!(r.trigger.as_deref(), Some("GoalScored"));
    assert_eq!(r.params.len(), 1);
    assert_eq!(r.params[0].name, "player");
    assert!(matches!(r.body[0], Stmt::Set { .. }));
}

#[test]
fn a_plain_rule_has_no_trigger() {
    let r = rule_of("rule r():\n    require true\n");
    assert_eq!(r.trigger, None);
}

#[test]
fn parses_an_entity_declaration_with_typed_fields() {
    let program = parse(
        &lex(
            "entity firetype:\n\
                 kind = \"firetype\"\n\
                 burn_rate = 1\n\
                 feed_amount = 3\n",
        )
        .unwrap(),
    )
    .unwrap();
    assert_eq!(program.entities.len(), 1, "one entity declaration was parsed");
    let entity = &program.entities[0];
    assert_eq!(entity.name, "firetype");
    assert_eq!(entity.fields.len(), 3);
    assert_eq!(entity.fields[0].0, "kind");
    assert!(matches!(entity.fields[0].1, Expr::Str(ref s) if s == "firetype"));
    assert_eq!(entity.fields[1].0, "burn_rate");
    assert!(matches!(entity.fields[1].1, Expr::Int(1)));
}

#[test]
fn an_entity_field_may_reference_another_entity_by_bare_name() {
    // `type = firetype` parses as `Var("firetype")` — the loader turns it into a
    // `Ref` at fold time once the global name pool is built.
    let program = parse(
        &lex("entity you:\n    type = firetype\n").unwrap(),
    )
    .unwrap();
    let entity = &program.entities[0];
    assert_eq!(entity.fields[0].0, "type");
    assert!(matches!(entity.fields[0].1, Expr::Var(ref name) if name == "firetype"));
}

#[test]
fn parses_a_test_declaration_with_applies_and_expects() {
    let program = parse(
        &lex(
            "test feed_consumes_a_log:\n\
                 apply feed\n\
                 expect wood = 2\n\
                 expect fire = 13\n",
        )
        .unwrap(),
    )
    .unwrap();
    assert_eq!(program.tests.len(), 1);
    let test = &program.tests[0];
    assert_eq!(test.name, "feed_consumes_a_log");
    assert_eq!(test.actions, vec![astra::TestAction::Apply("feed".into())]);
    assert_eq!(test.expects.len(), 2);
    assert_eq!(test.expects[0].0, "wood");
    assert!(matches!(test.expects[0].1, Expr::Int(2)));
}

#[test]
fn an_ident_followed_by_parens_is_a_builtin_call() {
    // `t("camp.heading")` is the i18n plugin's lookup; the language parses the
    // shape, the host implements the meaning. Args are full expressions.
    let r = rule_of("rule r():\n    let s = t(\"camp.heading\")\n");
    let Stmt::Let { value: Expr::Call { name, args }, .. } = &r.body[0] else {
        panic!("expected a call, got {:?}", r.body[0]);
    };
    assert_eq!(name, "t");
    assert_eq!(args.len(), 1);
    assert!(matches!(&args[0], Expr::Str(s) if s == "camp.heading"));
}

#[test]
fn a_call_takes_no_args_or_many() {
    // Zero-arg and multi-arg both parse — `now()` and `max(a, b, c)`.
    let r0 = rule_of("rule r():\n    let n = now()\n");
    let Stmt::Let { value: Expr::Call { args, .. }, .. } = &r0.body[0] else { panic!() };
    assert_eq!(args.len(), 0);
    let r3 = rule_of("rule r():\n    let m = max(1, 2, 3)\n");
    let Stmt::Let { value: Expr::Call { args, .. }, .. } = &r3.body[0] else { panic!() };
    assert_eq!(args.len(), 3);
}
