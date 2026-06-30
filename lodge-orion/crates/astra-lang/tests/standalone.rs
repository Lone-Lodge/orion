//! Astra running *standalone* — the proof the language executes with no Atlas in
//! sight, the way one embeds Rhai or Luau. A `World` is a HashMap behind the
//! `Host` seam; `place_mark` is the very source the parser test parses. Four
//! moves of tic-tac-toe fall out of the rule alone: X opens, O is refused out of
//! turn, an occupied cell commits nothing, and O answers once X has moved — each
//! an `Outcome` whose effects the host would fold into its world.

use astra::{Effect, Host, TraceEntry, Value, dispatch, run};
use std::collections::HashMap;

/// A toy world behind the host seam: fields keyed by `(entity, name)`, and the
/// entities of each kind. It holds no logic — every game decision is the rule's.
struct World {
    fields: HashMap<(u64, String), Value>,
    kinds: HashMap<String, Vec<u64>>,
}

impl Host for World {
    fn field(&self, entity: u64, name: &str) -> Option<Value> {
        self.fields.get(&(entity, name.to_string())).cloned()
    }
    fn all(&self, kind: &str) -> Vec<u64> {
        self.kinds.get(kind).cloned().unwrap_or_default()
    }
}

const PLACE_MARK: &str = "rule place_mark(cell):\n\
     require cell.mark == empty\n\
     let placed = count(c in all Cell where c.mark != empty)\n\
     let turn = if placed % 2 == 0 then \"X\" else \"O\"\n\
     require by.plays == turn\n\
     set cell.mark = turn\n";

const PLAYER_X: u64 = 11;
const PLAYER_O: u64 = 12;

/// Nine cells (1..=9) of kind `Cell`, plus two players whose `plays` field fixes
/// their mark. Cells start blank — `mark` is absent, which the rule reads as
/// `empty`.
fn board() -> World {
    let mut fields = HashMap::new();
    fields.insert((PLAYER_X, "plays".into()), Value::Text("X".into()));
    fields.insert((PLAYER_O, "plays".into()), Value::Text("O".into()));
    let mut kinds = HashMap::new();
    kinds.insert("Cell".into(), (1..=9).collect());
    World { fields, kinds }
}

/// Stamp a mark onto a cell, the way a host would after folding a `Set` effect.
fn mark(world: &mut World, cell: u64, who: &str) {
    world
        .fields
        .insert((cell, "mark".into()), Value::Text(who.into()));
}

/// The one effect a legal move proposes.
fn set(entity: u64, who: &str) -> Effect {
    Effect::Set {
        entity,
        field: "mark".into(),
        value: Value::Text(who.into()),
    }
}

#[test]
fn x_opens_on_an_empty_board() {
    let world = board();
    let effects = run(PLACE_MARK, "place_mark", PLAYER_X, &[Value::Ref(1)], &world)
        .unwrap()
        .effects;
    assert_eq!(effects, vec![set(1, "X")]);
}

#[test]
fn o_cannot_move_on_x_turn() {
    let world = board();
    // The cell is free, but it is X's turn — the second `require` refuses O.
    let effects = run(PLACE_MARK, "place_mark", PLAYER_O, &[Value::Ref(1)], &world)
        .unwrap()
        .effects;
    assert!(
        effects.is_empty(),
        "O out of turn must commit nothing, got {effects:?}"
    );
}

#[test]
fn an_occupied_cell_is_refused() {
    let mut world = board();
    mark(&mut world, 1, "X");
    // It is O's turn now, but cell 1 is taken — the first `require` refuses it.
    let effects = run(PLACE_MARK, "place_mark", PLAYER_O, &[Value::Ref(1)], &world)
        .unwrap()
        .effects;
    assert!(
        effects.is_empty(),
        "an occupied cell must commit nothing, got {effects:?}"
    );
}

#[test]
fn o_answers_after_one_mark() {
    let mut world = board();
    mark(&mut world, 1, "X");
    let effects = run(PLACE_MARK, "place_mark", PLAYER_O, &[Value::Ref(5)], &world)
        .unwrap()
        .effects;
    assert_eq!(effects, vec![set(5, "O")]);
}

#[test]
fn spawn_proposes_a_fresh_entity() {
    let world = board();
    let effects = run(
        "rule drop():\n    spawn LootBag { gold: 50 }\n",
        "drop",
        PLAYER_X,
        &[],
        &world,
    )
    .unwrap()
    .effects;
    assert_eq!(
        effects,
        vec![Effect::Spawn {
            kind: "LootBag".into(),
            fields: vec![("gold".into(), Value::Int(50))],
        }],
    );
}

#[test]
fn destroy_proposes_retiring_an_entity() {
    let world = board();
    let effects = run(
        "rule kill(goblin):\n    destroy goblin\n",
        "kill",
        PLAYER_X,
        &[Value::Ref(3)],
        &world,
    )
    .unwrap()
    .effects;
    assert_eq!(effects, vec![Effect::Destroy { entity: 3 }]);
}

#[test]
fn emit_proposes_an_event() {
    let world = board();
    let effects = run(
        "rule finish(winner):\n    emit GameOver { winner: winner }\n",
        "finish",
        PLAYER_X,
        &[Value::Ref(PLAYER_X)],
        &world,
    )
    .unwrap()
    .effects;
    assert_eq!(
        effects,
        vec![Effect::Emit {
            event: "GameOver".into(),
            fields: vec![("winner".into(), Value::Ref(PLAYER_X))],
        }],
    );
}

#[test]
fn a_run_reports_the_fields_and_kinds_it_read() {
    let world = board();
    let outcome = run(PLACE_MARK, "place_mark", PLAYER_X, &[Value::Ref(1)], &world).unwrap();
    // `count(c in all Cell ...)` enumerated the Cell kind — once.
    assert_eq!(outcome.reads.kinds, vec!["Cell".to_string()]);
    // It read cell 1's mark (the guard), every cell's mark (the count), and the
    // actor's `plays` (the turn guard): the rule's exact dependency footprint.
    assert!(outcome.reads.fields.contains(&(1, "mark".into())));
    assert!(outcome.reads.fields.contains(&(9, "mark".into())));
    assert!(outcome.reads.fields.contains(&(PLAYER_X, "plays".into())));
}

#[test]
fn a_read_touched_twice_is_recorded_once() {
    let world = board();
    // Cell 1's mark is read by the first `require`, then again inside the count.
    let outcome = run(PLACE_MARK, "place_mark", PLAYER_X, &[Value::Ref(1)], &world).unwrap();
    let touches = outcome
        .reads
        .fields
        .iter()
        .filter(|f| f.0 == 1 && f.1 == "mark")
        .count();
    assert_eq!(touches, 1, "a repeated read is deduped, got {:?}", outcome.reads.fields);
}

#[test]
fn trace_records_the_decision_path() {
    let world = board();
    // X opens: both guards hold and both lets bind, so the trace is the rule read
    // top to bottom — the two `require`s and the two `let`s, in source order.
    let outcome = run(PLACE_MARK, "place_mark", PLAYER_X, &[Value::Ref(1)], &world).unwrap();
    assert_eq!(
        outcome.trace,
        vec![
            TraceEntry::Require { passed: true },
            TraceEntry::Let {
                name: "placed".into(),
                value: "0".into(),
            },
            TraceEntry::Let {
                name: "turn".into(),
                value: "\"X\"".into(),
            },
            TraceEntry::Require { passed: true },
        ],
    );
}

#[test]
fn trace_explains_a_silent_no_op() {
    let world = board();
    // O out of turn: the move commits nothing, but the trace shows *why* — the
    // cell guard passed, `turn` bound to "X", then the turn guard failed.
    let outcome = run(PLACE_MARK, "place_mark", PLAYER_O, &[Value::Ref(1)], &world).unwrap();
    assert!(outcome.effects.is_empty(), "O out of turn commits nothing");
    assert_eq!(
        outcome.trace.last(),
        Some(&TraceEntry::Require { passed: false }),
        "the failed guard is the last step on the path: {:?}",
        outcome.trace
    );
    assert!(
        outcome.trace.contains(&TraceEntry::Let {
            name: "turn".into(),
            value: "\"X\"".into(),
        }),
        "the path records the binding that made the guard fail: {:?}",
        outcome.trace
    );
}

/// A handler the host fires by event name; `player` binds from the event's fields.
const ON_GOAL: &str = "on GoalScored(player):\n    set player.celebrating = true\n";

#[test]
fn dispatch_binds_event_fields_to_params_by_name() {
    let world = board();
    let effects = dispatch(
        ON_GOAL,
        "GoalScored",
        PLAYER_X,
        &[("player".into(), Value::Ref(PLAYER_O))],
        &world,
    )
    .unwrap()
    .effects;
    assert_eq!(
        effects,
        vec![Effect::Set {
            entity: PLAYER_O,
            field: "celebrating".into(),
            value: Value::Bool(true),
        }],
    );
}

#[test]
fn dispatch_ignores_an_event_with_no_handler() {
    let world = board();
    let effects = dispatch(ON_GOAL, "MatchEnded", PLAYER_X, &[], &world)
        .unwrap()
        .effects;
    assert!(
        effects.is_empty(),
        "an unhandled event proposes nothing, got {effects:?}"
    );
}

#[test]
fn dispatch_fans_out_to_handlers_in_source_order() {
    let world = board();
    // Two handlers for the same event run top-to-bottom, effects concatenated.
    let src = "on Tick(p):\n    set p.a = 1\non Tick(p):\n    set p.b = 2\n";
    let effects = dispatch(
        src,
        "Tick",
        PLAYER_X,
        &[("p".into(), Value::Ref(PLAYER_X))],
        &world,
    )
    .unwrap()
    .effects;
    assert_eq!(
        effects,
        vec![
            Effect::Set {
                entity: PLAYER_X,
                field: "a".into(),
                value: Value::Int(1),
            },
            Effect::Set {
                entity: PLAYER_X,
                field: "b".into(),
                value: Value::Int(2),
            },
        ],
    );
}

#[test]
fn dispatch_errors_when_the_event_lacks_a_param() {
    let world = board();
    // The handler needs `player`, but the event carried no such field.
    let err = dispatch(ON_GOAL, "GoalScored", PLAYER_X, &[], &world).unwrap_err();
    assert!(
        err.to_string().contains("field"),
        "names the missing field: {err}"
    );
}

#[test]
fn run_cannot_call_an_on_handler_by_name() {
    let world = board();
    // `run` only reaches plain rules; the handler's event name is not callable.
    let err = run(ON_GOAL, "GoalScored", PLAYER_X, &[], &world).unwrap_err();
    assert!(
        matches!(err, astra::Error::NoSuchRule(_)),
        "expected NoSuchRule, got {err:?}"
    );
}

/// A host that pretends to be a tiny `atlas-i18n`: one builtin `t(key)` that
/// looks the key up in an inline table. The very seam plugins use to register
/// their own functions.
struct WithBuiltin;
impl Host for WithBuiltin {
    fn field(&self, _entity: u64, _name: &str) -> Option<Value> { None }
    fn all(&self, _kind: &str) -> Vec<u64> { Vec::new() }
    fn call(&self, name: &str, args: &[Value]) -> Option<Value> {
        if name != "t" { return None; }
        let key = match args.first()? { Value::Text(s) => s.as_str(), _ => return None };
        Some(Value::Text(match key {
            "camp.heading" => "By the Fire".into(),
            _ => format!("?{key}"),
        }))
    }
}

#[test]
fn a_host_registered_builtin_lands_its_value_in_an_effect() {
    let src = "rule label(target):\n    set target.heading = t(\"camp.heading\")\n";
    let world = WithBuiltin;
    let effects = run(src, "label", 0, &[Value::Ref(5)], &world).unwrap().effects;
    assert_eq!(
        effects,
        vec![Effect::Set {
            entity: 5,
            field: "heading".into(),
            value: Value::Text("By the Fire".into()),
        }],
        "the host's `t` lookup folded straight into the proposed Set"
    );
}

#[test]
fn an_unknown_builtin_is_a_run_error_not_a_silent_zero() {
    // Unregistered names must surface, not silently return Empty — a typo in a
    // view would otherwise render as an empty string and rot the project.
    let src = "rule r():\n    let _ = wat()\n";
    let err = run(src, "r", 0, &[], &WithBuiltin).unwrap_err();
    assert!(
        matches!(&err, astra::Error::Run(e) if e.message.contains("unknown builtin")),
        "expected RunError, got {err:?}"
    );
}
