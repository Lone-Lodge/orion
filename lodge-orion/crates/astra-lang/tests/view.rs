//! The `view` form, falsified through the public face: source + a mock world in,
//! a `Rendered` node tree out. Proves the read-side decl — a `for` over `all npc`
//! expands to one node per entity, and field reads bind into the args — all
//! host-agnostic: the core names no UI, just `(kind, args, children)`.

use astra::{render, Host, Value};

/// Two npcs with names — the smallest world a roster view can read.
struct World;

impl Host for World {
    fn field(&self, entity: u64, name: &str) -> Option<Value> {
        match (entity, name) {
            (1, "name") => Some(Value::Text("Bjorn".into())),
            (2, "name") => Some(Value::Text("Mae".into())),
            _ => None,
        }
    }
    fn all(&self, kind: &str) -> Vec<u64> {
        if kind == "npc" { vec![1, 2] } else { vec![] }
    }
}

const SRC: &str = "\
view roster():
    surface \"panel\" {
        text \"heading\" \"Roster\"
        for n in all npc {
            text \"row\" n.name
        }
    }
";

fn text(role: &str, content: &str) -> Vec<Value> {
    vec![Value::Text(role.into()), Value::Text(content.into())]
}

#[test]
fn a_view_renders_a_node_tree_with_a_for_expansion() {
    let r = render(SRC, "roster", 0, &[], &World).expect("the view renders");

    assert_eq!(r.kind, "surface");
    assert_eq!(r.args, vec![Value::Text("panel".into())]);

    // heading + one row per npc (the `for` expanded over `all npc`)
    assert_eq!(r.children.len(), 3, "heading + two npc rows");
    assert_eq!(r.children[0].args, text("heading", "Roster"));
    assert_eq!(r.children[1].args, text("row", "Bjorn"));
    assert_eq!(r.children[2].args, text("row", "Mae"));
    assert!(r.children.iter().all(|c| c.kind == "text"));
}

#[test]
fn render_rejects_an_unknown_view() {
    assert!(render(SRC, "nope", 0, &[], &World).is_err());
}

#[test]
fn typecheck_rejects_a_for_over_a_non_list() {
    // `for n in 1` — the source is an Int, not a list: a type error, caught at
    // compile (views typecheck like rules), never a confused render.
    let bad = "view bad():\n    surface \"s\" {\n        for n in 1 { text \"row\" \"x\" }\n    }\n";
    assert!(render(bad, "bad", 0, &[], &World).is_err());
}
