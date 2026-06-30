//! The typechecker falsified through its public face: source in, the first type
//! error out (or nothing). The shipped `place_mark` is the headline — it must
//! check clean, gradual field reads and all — and every rejection names a real
//! bug the grammar alone would have let through: text arithmetic, a non-boolean
//! guard, branches that disagree, a comparison across types, a field read off a
//! number, an unbound name, and `empty` reaching for a field. The closing section
//! falsifies the `record` schema: a declared kind narrows its fields to their
//! types, closes itself to undeclared fields, and flows that kind through `all`
//! into a `count` row — while a kind with no record stays gradual.

use astra::{CheckError, check, lex, parse};

/// Lex, parse, and typecheck a whole source unit — the pipeline `run` walks
/// before it ever evaluates, minus the host.
fn check_src(src: &str) -> Result<(), CheckError> {
    let tokens = lex(src).expect("lexes");
    let program = parse(&tokens).expect("parses");
    check(&program)
}

const PLACE_MARK: &str = "rule place_mark(cell):\n\
     require cell.mark == empty\n\
     let placed = count(c in all Cell where c.mark != empty)\n\
     let turn = if placed % 2 == 0 then \"X\" else \"O\"\n\
     require by.plays == turn\n\
     set cell.mark = turn\n";

#[test]
fn place_mark_typechecks() {
    assert!(check_src(PLACE_MARK).is_ok(), "the shipped rule must check");
}

#[test]
fn annotated_param_types_its_arithmetic() {
    assert!(check_src("rule r(n: Int):\n    require n > 0\n").is_ok());
}

#[test]
fn text_plus_anything_concatenates() {
    // `+` is overloaded: a Text on either side renders the other into the string,
    // so a view label can stitch an int counter naturally.
    assert!(check_src("rule r():\n    let x = \"a\" + 1\n").is_ok());
    assert!(check_src("rule r():\n    let x = 1 + \"a\"\n").is_ok());
}

#[test]
fn text_multiplication_is_still_rejected() {
    // Only `+` overloads. `-`, `*`, `/`, `%` stay Int-only — there is no sane
    // arithmetic interpretation of Text for them, and the static error names it.
    let e = check_src("rule r():\n    let x = \"a\" * 1\n").unwrap_err();
    assert!(
        e.message.contains("arithmetic") && e.message.contains("Int"),
        "names the offence: {}",
        e.message
    );
}

#[test]
fn a_non_boolean_guard_is_rejected() {
    let e = check_src("rule r():\n    require 1\n").unwrap_err();
    assert!(e.message.contains("require"), "{}", e.message);
}

#[test]
fn if_branches_must_agree() {
    let e = check_src("rule r():\n    let x = if true then 1 else \"a\"\n").unwrap_err();
    assert!(e.message.contains("branches"), "{}", e.message);
}

#[test]
fn a_comparison_across_types_is_rejected() {
    let e = check_src("rule r():\n    require 1 == \"a\"\n").unwrap_err();
    assert!(e.message.contains("compare"), "{}", e.message);
}

#[test]
fn a_field_read_off_a_number_is_rejected() {
    let e = check_src("rule r(n: Int):\n    require n.mark == empty\n").unwrap_err();
    assert!(e.message.contains("entity"), "{}", e.message);
}

#[test]
fn an_unbound_name_is_rejected() {
    let e = check_src("rule r():\n    require missing == empty\n").unwrap_err();
    assert!(e.message.contains("missing"), "{}", e.message);
}

#[test]
fn empty_cannot_be_stored_in_a_field() {
    let e = check_src("rule r(cell):\n    set cell.mark = empty\n").unwrap_err();
    assert!(e.message.contains("empty"), "{}", e.message);
}

#[test]
fn spawn_typechecks_its_fields() {
    assert!(check_src("rule drop():\n    spawn LootBag { gold: 50 }\n").is_ok());
}

#[test]
fn spawn_rejects_storing_empty() {
    let e = check_src("rule drop():\n    spawn LootBag { gold: empty }\n").unwrap_err();
    assert!(e.message.contains("empty"), "{}", e.message);
}

#[test]
fn destroy_typechecks_an_entity() {
    assert!(check_src("rule kill(goblin: Goblin):\n    destroy goblin\n").is_ok());
}

#[test]
fn destroy_rejects_a_non_entity() {
    let e = check_src("rule kill(n: Int):\n    destroy n\n").unwrap_err();
    assert!(e.message.contains("entity"), "{}", e.message);
}

#[test]
fn emit_typechecks_its_fields() {
    assert!(check_src("rule finish(p):\n    emit GameOver { winner: p }\n").is_ok());
}

#[test]
fn emit_rejects_storing_a_list() {
    let e = check_src("rule finish():\n    emit Roster { cells: all Cell }\n").unwrap_err();
    assert!(e.message.contains("List"), "{}", e.message);
}

#[test]
fn an_on_handler_is_typechecked_like_a_rule() {
    // A handler goes through the same checker — a non-boolean `require` is caught.
    let e = check_src("on Tick(n: Int):\n    require n\n").unwrap_err();
    assert!(e.message.contains("require"), "{}", e.message);
}

const RECORDED_PLACE: &str = "record Cell:\n    mark: Text\nrule place(cell: Cell):\n\
     require cell.mark == empty\n\
     set cell.mark = \"X\"\n";

#[test]
fn a_record_lets_a_field_rule_check_clean() {
    // With `mark` declared `Text`, the read compares to `empty` and the write stores
    // a `Text` — both legal, so the rule checks with no `unknown` left in it.
    assert!(check_src(RECORDED_PLACE).is_ok(), "the recorded rule must check");
}

#[test]
fn a_record_narrows_a_field_so_misuse_is_caught() {
    // `mark` is `Text`; ordering it as a number is the bug a record exists to catch
    // — the very read that was gradual `unknown` without one.
    let src = "record Cell:\n    mark: Text\nrule r(cell: Cell):\n    require cell.mark > 0\n";
    let e = check_src(src).unwrap_err();
    assert!(e.message.contains("Int"), "{}", e.message);
}

#[test]
fn a_record_closes_the_kind_to_undeclared_reads() {
    let src = "record Cell:\n    mark: Text\nrule r(cell: Cell):\n    require cell.spin == empty\n";
    let e = check_src(src).unwrap_err();
    assert!(e.message.contains("spin"), "{}", e.message);
}

#[test]
fn a_record_kind_flows_through_all_into_a_count_row() {
    // `c` binds to a `Cell` because `all Cell` is a list of them, so `c.mark` narrows
    // to `Text` and ordering it is caught inside the `where`.
    let src = "record Cell:\n    mark: Text\nrule r():\n    let n = count(c in all Cell where c.mark > 0)\n";
    let e = check_src(src).unwrap_err();
    assert!(e.message.contains("Int"), "{}", e.message);
}

#[test]
fn a_record_typechecks_a_field_write() {
    let src = "record Cell:\n    mark: Text\nrule r(cell: Cell):\n    set cell.mark = 1\n";
    let e = check_src(src).unwrap_err();
    assert!(e.message.contains("Text"), "{}", e.message);
}

#[test]
fn a_record_closes_the_kind_to_undeclared_writes() {
    let src = "record Cell:\n    mark: Text\nrule r(cell: Cell):\n    set cell.spin = 1\n";
    let e = check_src(src).unwrap_err();
    assert!(e.message.contains("spin"), "{}", e.message);
}

#[test]
fn a_kind_with_no_record_stays_gradual() {
    // Records are per-kind: `Door` has none, so its fields read and write as before.
    let src = "record Cell:\n    mark: Text\nrule r(d: Door):\n    set d.locked = true\n";
    assert!(check_src(src).is_ok(), "an unmodelled kind keeps the gradual seam");
}

#[test]
fn a_kind_declared_twice_is_rejected() {
    let src = "record Cell:\n    mark: Text\nrecord Cell:\n    spin: Int\nrule r():\n    require true\n";
    let e = check_src(src).unwrap_err();
    assert!(e.message.contains("twice"), "{}", e.message);
}

#[test]
fn a_field_declared_twice_is_rejected() {
    let src = "record Cell:\n    mark: Text\n    mark: Int\nrule r():\n    require true\n";
    let e = check_src(src).unwrap_err();
    assert!(e.message.contains("field") && e.message.contains("twice"), "{}", e.message);
}
