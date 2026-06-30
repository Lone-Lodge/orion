//! A read-recording decorator over a host. The evaluator asks for a field or a
//! kind exactly as before; the recorder notes each request, then delegates. So a
//! rule's dependency footprint (`Reads`) is captured by the same `field`/`all`
//! calls the walk already makes — no second pass, and the evaluator never knows.

use std::cell::RefCell;

use crate::outcome::Reads;
use crate::{Host, Value};

/// Wraps the real host, accumulating every read into `reads` before forwarding.
/// Interior mutability is required because [`Host`] reads through `&self`; a run
/// is single-threaded, so a `RefCell` borrow never overlaps.
pub(super) struct Recorder<'h> {
    inner: &'h dyn Host,
    reads: RefCell<Reads>,
}

impl<'h> Recorder<'h> {
    pub(super) fn new(inner: &'h dyn Host) -> Self {
        Recorder {
            inner,
            reads: RefCell::new(Reads::default()),
        }
    }

    pub(super) fn into_reads(self) -> Reads {
        self.reads.into_inner()
    }
}

impl Host for Recorder<'_> {
    fn field(&self, entity: u64, name: &str) -> Option<Value> {
        self.reads.borrow_mut().record_field(entity, name);
        self.inner.field(entity, name)
    }

    fn all(&self, kind: &str) -> Vec<u64> {
        self.reads.borrow_mut().record_kind(kind);
        self.inner.all(kind)
    }

    fn call(&self, name: &str, args: &[Value]) -> Option<Value> {
        self.inner.call(name, args)
    }
}
