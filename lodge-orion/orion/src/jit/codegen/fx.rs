//! `Fx` walks one function body and emits Cranelift IR for each expression.

use std::collections::HashMap;

use cranelift::codegen::ir::FuncRef;
use cranelift::prelude::*;

use super::super::{JTy, unify};
use super::{float_cc, int_cc, is_compare};
use crate::ast::{AssignOp, BinOp, Expr, Stmt, UnOp};

pub(super) struct Fx<'a, 'b> {
    b: &'a mut FunctionBuilder<'b>,
    frefs: &'a HashMap<String, FuncRef>,
    vars: HashMap<String, (Variable, JTy)>,
    ret_tys: &'a HashMap<String, JTy>,
    param_tys: &'a HashMap<String, Vec<JTy>>,
    /// `(continue_target, break_target)` per active loop. Break jumps to the
    /// break target; continue jumps to the continue target.
    loop_stack: Vec<(Block, Block)>,
}

impl<'a, 'b> Fx<'a, 'b> {
    pub(super) fn new(
        b: &'a mut FunctionBuilder<'b>,
        frefs: &'a HashMap<String, FuncRef>,
        vars: HashMap<String, (Variable, JTy)>,
        ret_tys: &'a HashMap<String, JTy>,
        param_tys: &'a HashMap<String, Vec<JTy>>,
    ) -> Self {
        Fx { b, frefs, vars, ret_tys, param_tys, loop_stack: Vec::new() }
    }

    /// Run a block of statements. Returns the value of its tail expression (or
    /// `(JTy::Int, 0)` if the block ends on a non-expression statement).
    pub(super) fn block(&mut self, stmts: &[Stmt]) -> Result<(JTy, Value), String> {
        let mut last: Option<(JTy, Value)> = None;
        for s in stmts {
            last = self.stmt(s)?;
        }
        Ok(last.unwrap_or_else(|| (JTy::Int, self.b.ins().iconst(types::I64, 0))))
    }

    /// Emit one statement. Returns `Some((ty, value))` if the statement is an
    /// expression (its value becomes the block's tail), `None` otherwise.
    fn stmt(&mut self, s: &Stmt) -> Result<Option<(JTy, Value)>, String> {
        match s {
            // A `fact` is a lazy interpreter binding; bail out of JIT so the
            // function falls back to the tree-walker (which handles facts).
            Stmt::Fact { .. } => Err("`fact` is interpreter-only, not JIT-compiled".to_string()),
            Stmt::Expr(e) => {
                let ty = self.infer(e);
                let v = self.expr(e)?;
                Ok(Some((ty, v)))
            }
            Stmt::Bind { name, value } => {
                let ty = self.infer(value);
                let v = self.expr(value)?;
                let var = self.b.declare_var(ty.clif());
                self.b.def_var(var, v);
                self.vars.insert(name.clone(), (var, ty));
                Ok(None)
            }
            Stmt::Assign { target, op, value } => {
                self.stmt_assign(target, *op, value)?;
                Ok(None)
            }
            Stmt::If { cond, then, otherwise } => {
                self.stmt_if(cond, then, otherwise)?;
                Ok(None)
            }
            Stmt::Loop(body) => {
                self.stmt_loop(body)?;
                Ok(None)
            }
            Stmt::ForIn { var, iter, body, .. } => {
                self.stmt_for_in(var, iter, body)?;
                Ok(None)
            }
            Stmt::Break => {
                let (_, brk) = self.loop_stack.last().copied()
                    .ok_or_else(|| "codegen: `break` outside a loop".to_string())?;
                self.b.ins().jump(brk, &[]);
                // The break is the last instruction in this block; create a
                // dead block so subsequent statements (if any) have a target.
                let dead = self.b.create_block();
                self.b.switch_to_block(dead);
                self.b.seal_block(dead);
                Ok(None)
            }
            Stmt::Continue => {
                let (cont, _) = self.loop_stack.last().copied()
                    .ok_or_else(|| "codegen: `continue` outside a loop".to_string())?;
                self.b.ins().jump(cont, &[]);
                let dead = self.b.create_block();
                self.b.switch_to_block(dead);
                self.b.seal_block(dead);
                Ok(None)
            }
            Stmt::Return(_) => {
                Err("codegen: `return` not yet supported in JIT path — use last-expression value".to_string())
            }
            // `raw` is transparent for codegen — same instructions, no checks.
            Stmt::Raw(body) => {
                let last = self.block(body)?;
                Ok(Some(last))
            }
            // `parallel for ...:` reuses the inner For/ForIn codegen.
            Stmt::Parallel(inner) => self.stmt(inner),
            // These need richer runtime support (store, contracts); not in
            // the JIT subset yet.
            Stmt::For { .. } | Stmt::Require(_) | Stmt::Ensure(_) | Stmt::Destroy(_) => {
                Err(format!("codegen: statement {s:?} is not JIT-supported yet"))
            }
        }
    }

    /// `x = e`, `x += e`, `x -= e` on a local variable.
    fn stmt_assign(&mut self, target: &Expr, op: AssignOp, value: &Expr) -> Result<(), String> {
        let Expr::Var(name, _) = target else {
            return Err("codegen: only assignment to a local variable is JIT-supported".into());
        };
        let rhs_ty = self.infer(value);
        let rhs = self.expr(value)?;

        match op {
            AssignOp::Set => {
                // Fresh assignment (immutable binding) or reassign to existing var.
                if let Some((var, ty)) = self.vars.get(name).copied() {
                    let converted = self.convert(rhs, rhs_ty, ty);
                    self.b.def_var(var, converted);
                } else {
                    let var = self.b.declare_var(rhs_ty.clif());
                    self.b.def_var(var, rhs);
                    self.vars.insert(name.clone(), (var, rhs_ty));
                }
            }
            AssignOp::Add | AssignOp::Sub => {
                let (var, ty) = self.vars.get(name).copied()
                    .ok_or_else(|| format!("codegen: `{name}` is not defined"))?;
                let cur = self.b.use_var(var);
                let rhs = self.convert(rhs, rhs_ty, ty);
                let new = match (op, ty) {
                    (AssignOp::Add, JTy::Int) => self.b.ins().iadd(cur, rhs),
                    (AssignOp::Sub, JTy::Int) => self.b.ins().isub(cur, rhs),
                    (AssignOp::Add, JTy::Float) => self.b.ins().fadd(cur, rhs),
                    (AssignOp::Sub, JTy::Float) => self.b.ins().fsub(cur, rhs),
                    _ => unreachable!(),
                };
                self.b.def_var(var, new);
            }
        }
        Ok(())
    }

    fn stmt_if(&mut self, cond: &Expr, then: &[Stmt], otherwise: &[Stmt]) -> Result<(), String> {
        let then_b = self.b.create_block();
        let else_b = self.b.create_block();
        let merge_b = self.b.create_block();

        let c = self.cond(cond)?;
        self.b.ins().brif(c, then_b, &[], else_b, &[]);

        self.b.switch_to_block(then_b);
        self.b.seal_block(then_b);
        self.block(then)?;
        self.b.ins().jump(merge_b, &[]);

        self.b.switch_to_block(else_b);
        self.b.seal_block(else_b);
        self.block(otherwise)?;
        self.b.ins().jump(merge_b, &[]);

        self.b.switch_to_block(merge_b);
        self.b.seal_block(merge_b);
        Ok(())
    }

    fn stmt_loop(&mut self, body: &[Stmt]) -> Result<(), String> {
        let header = self.b.create_block();
        let exit = self.b.create_block();
        self.b.ins().jump(header, &[]);
        self.b.switch_to_block(header);

        self.loop_stack.push((header, exit));
        self.block(body)?;
        self.loop_stack.pop();

        self.b.ins().jump(header, &[]);
        self.b.seal_block(header);
        self.b.switch_to_block(exit);
        self.b.seal_block(exit);
        Ok(())
    }

    /// `for v in lo..<hi:` or `lo...hi`. Other iter shapes fall back to the
    /// tree-walking interpreter (caller decides via reachability).
    fn stmt_for_in(&mut self, var: &str, iter: &Expr, body: &[Stmt]) -> Result<(), String> {
        let Expr::Range { lo, hi, inclusive } = iter else {
            return Err("codegen: `for v in <iter>` only supports range iterators".into());
        };
        let lo_ty = self.infer(lo);
        let lo_v = self.expr(lo)?;
        let lo_v = self.convert(lo_v, lo_ty, JTy::Int);
        let hi_ty = self.infer(hi);
        let hi_v = self.expr(hi)?;
        let hi_v = self.convert(hi_v, hi_ty, JTy::Int);
        // Inclusive: iterate while i <= hi. Exclusive: while i < hi.
        let end = if *inclusive {
            self.b.ins().iadd_imm(hi_v, 1)
        } else {
            hi_v
        };

        let i_var = self.b.declare_var(types::I64);
        self.b.def_var(i_var, lo_v);
        self.vars.insert(var.to_string(), (i_var, JTy::Int));

        let header = self.b.create_block();
        let body_b = self.b.create_block();
        let cont_b = self.b.create_block();
        let exit_b = self.b.create_block();

        self.b.ins().jump(header, &[]);
        self.b.switch_to_block(header);
        let cur = self.b.use_var(i_var);
        let keep = self.b.ins().icmp(IntCC::SignedLessThan, cur, end);
        self.b.ins().brif(keep, body_b, &[], exit_b, &[]);

        self.b.switch_to_block(body_b);
        self.b.seal_block(body_b);
        self.loop_stack.push((cont_b, exit_b));
        self.block(body)?;
        self.loop_stack.pop();
        self.b.ins().jump(cont_b, &[]);

        self.b.switch_to_block(cont_b);
        self.b.seal_block(cont_b);
        let cur = self.b.use_var(i_var);
        let next = self.b.ins().iadd_imm(cur, 1);
        self.b.def_var(i_var, next);
        self.b.ins().jump(header, &[]);

        self.b.seal_block(header);
        self.b.switch_to_block(exit_b);
        self.b.seal_block(exit_b);
        Ok(())
    }

    pub(super) fn infer(&self, e: &Expr) -> JTy {
        match e {
            Expr::Int(_) => JTy::Int,
            Expr::Float(_) => JTy::Float,
            Expr::Var(n, _) => self.vars.get(n).map(|(_, t)| *t).unwrap_or(JTy::Int),
            Expr::Unary { rhs, .. } => self.infer(rhs),
            Expr::Binary { lhs, rhs, .. } => unify(self.infer(lhs), self.infer(rhs)),
            Expr::If { then, otherwise, .. } => unify(self.infer(then), self.infer(otherwise)),
            Expr::Call { callee, .. } => match callee.as_ref() {
                Expr::Var(n, _) if n == "sqrt" => JTy::Float,
                Expr::Var(n, _) => self.ret_tys.get(n).copied().unwrap_or(JTy::Int),
                _ => JTy::Int,
            },
            _ => JTy::Int,
        }
    }

    pub(super) fn convert(&mut self, v: Value, from: JTy, to: JTy) -> Value {
        match (from, to) {
            (JTy::Int, JTy::Float) => self.b.ins().fcvt_from_sint(types::F64, v),
            (JTy::Float, JTy::Int) => self.b.ins().fcvt_to_sint(types::I64, v),
            _ => v,
        }
    }

    pub(super) fn expr(&mut self, e: &Expr) -> Result<Value, String> {
        match e {
            Expr::Int(n) => Ok(self.b.ins().iconst(types::I64, *n)),
            Expr::Float(x) => Ok(self.b.ins().f64const(*x)),
            Expr::Var(name, _) => self.vars.get(name)
                .map(|(v, _)| self.b.use_var(*v))
                .ok_or_else(|| format!("codegen: unknown name `{name}`")),
            Expr::Unary { op, rhs } => self.unary(*op, rhs),
            Expr::Binary { op, lhs, rhs } => self.binary(*op, lhs, rhs),
            Expr::If { cond, then, otherwise } => self.if_expr(cond, then, otherwise),
            Expr::Call { callee, args } => self.call(callee, args),
            other => Err(format!("codegen: {other:?} is not supported")),
        }
    }

    fn unary(&mut self, op: UnOp, rhs: &Expr) -> Result<Value, String> {
        let ty = self.infer(rhs);
        let v = self.expr(rhs)?;
        match op {
            UnOp::Neg if ty == JTy::Float => Ok(self.b.ins().fneg(v)),
            UnOp::Neg => Ok(self.b.ins().ineg(v)),
            UnOp::Not => Err("codegen: `not` is not supported yet".into()),
            UnOp::BitNot => Ok(self.b.ins().bnot(v)),
        }
    }

    fn binary(&mut self, op: BinOp, lhs: &Expr, rhs: &Expr) -> Result<Value, String> {
        let lt = self.infer(lhs);
        let rt = self.infer(rhs);
        let rty = unify(lt, rt);
        let a = self.expr(lhs)?;
        let a = self.convert(a, lt, rty);
        let b = self.expr(rhs)?;
        let b = self.convert(b, rt, rty);
        let ins = self.b.ins();
        Ok(match (op, rty) {
            (BinOp::Add, JTy::Int) => ins.iadd(a, b),
            (BinOp::Sub, JTy::Int) => ins.isub(a, b),
            (BinOp::Mul, JTy::Int) => ins.imul(a, b),
            (BinOp::Div, JTy::Int) => ins.sdiv(a, b),
            (BinOp::Rem, JTy::Int) => ins.srem(a, b),
            (BinOp::Add, JTy::Float) => ins.fadd(a, b),
            (BinOp::Sub, JTy::Float) => ins.fsub(a, b),
            (BinOp::Mul, JTy::Float) => ins.fmul(a, b),
            (BinOp::Div, JTy::Float) => ins.fdiv(a, b),
            (BinOp::Rem, JTy::Float) => return Err("codegen: float remainder not supported".into()),
            (BinOp::BitAnd, JTy::Int) => ins.band(a, b),
            (BinOp::BitOr, JTy::Int) => ins.bor(a, b),
            (BinOp::BitXor, JTy::Int) => ins.bxor(a, b),
            (BinOp::Shl, JTy::Int) => ins.ishl(a, b),
            // Use ushr for logical right shift; programs that want arithmetic
            // (sign-preserving) shift should branch on sign explicitly.
            (BinOp::Shr, JTy::Int) => ins.ushr(a, b),
            (BinOp::BitAnd | BinOp::BitOr | BinOp::BitXor | BinOp::Shl | BinOp::Shr, JTy::Float) => {
                return Err("codegen: bitwise operators require int".into());
            }
            (other, _) => return Err(format!(
                "codegen: {other:?} produces a boolean; only valid in an `if` condition"
            )),
        })
    }

    fn call(&mut self, callee: &Expr, args: &[Expr]) -> Result<Value, String> {
        let name = match callee {
            Expr::Var(n, _) => n,
            _ => return Err("codegen: only named calls are supported".into()),
        };
        if name == "sqrt" {
            return self.sqrt_builtin(args);
        }
        self.user_call(name, args)
    }

    fn sqrt_builtin(&mut self, args: &[Expr]) -> Result<Value, String> {
        if args.len() != 1 {
            return Err("codegen: sqrt takes 1 argument".into());
        }
        let at = self.infer(&args[0]);
        let a = self.expr(&args[0])?;
        let a = self.convert(a, at, JTy::Float);
        Ok(self.b.ins().sqrt(a))
    }

    fn user_call(&mut self, name: &str, args: &[Expr]) -> Result<Value, String> {
        let fref = *self.frefs.get(name)
            .ok_or_else(|| format!("codegen: cannot call `{name}`"))?;
        let ptys = self.param_tys.get(name)
            .ok_or_else(|| format!("codegen: unknown signature for `{name}`"))?
            .clone();
        let mut argv = Vec::with_capacity(args.len());
        for (i, a) in args.iter().enumerate() {
            let at = self.infer(a);
            let val = self.expr(a)?;
            let want = ptys.get(i).copied().unwrap_or(JTy::Int);
            argv.push(self.convert(val, at, want));
        }
        let inst = self.b.ins().call(fref, &argv);
        Ok(self.b.inst_results(inst)[0])
    }

    fn if_expr(&mut self, cond: &Expr, then: &Expr, otherwise: &Expr) -> Result<Value, String> {
        let tt = self.infer(then);
        let et = self.infer(otherwise);
        let rty = unify(tt, et);
        let result = self.b.declare_var(rty.clif());

        let then_b = self.b.create_block();
        let else_b = self.b.create_block();
        let merge_b = self.b.create_block();

        let c = self.cond(cond)?;
        self.b.ins().brif(c, then_b, &[], else_b, &[]);

        self.b.switch_to_block(then_b);
        self.b.seal_block(then_b);
        let tv = self.expr(then)?;
        let tv = self.convert(tv, tt, rty);
        self.b.def_var(result, tv);
        self.b.ins().jump(merge_b, &[]);

        self.b.switch_to_block(else_b);
        self.b.seal_block(else_b);
        let ev = self.expr(otherwise)?;
        let ev = self.convert(ev, et, rty);
        self.b.def_var(result, ev);
        self.b.ins().jump(merge_b, &[]);

        self.b.switch_to_block(merge_b);
        self.b.seal_block(merge_b);
        Ok(self.b.use_var(result))
    }

    fn cond(&mut self, e: &Expr) -> Result<Value, String> {
        if let Expr::Binary { op, lhs, rhs } = e {
            if is_compare(*op) {
                return self.compare(*op, lhs, rhs);
            }
        }
        self.bool_from_value(e)
    }

    fn compare(&mut self, op: BinOp, lhs: &Expr, rhs: &Expr) -> Result<Value, String> {
        let lt = self.infer(lhs);
        let rt = self.infer(rhs);
        let rty = unify(lt, rt);
        let a = self.expr(lhs)?;
        let a = self.convert(a, lt, rty);
        let b = self.expr(rhs)?;
        let b = self.convert(b, rt, rty);
        Ok(if rty == JTy::Float {
            self.b.ins().fcmp(float_cc(op), a, b)
        } else {
            self.b.ins().icmp(int_cc(op), a, b)
        })
    }

    fn bool_from_value(&mut self, e: &Expr) -> Result<Value, String> {
        let ty = self.infer(e);
        let v = self.expr(e)?;
        Ok(if ty == JTy::Float {
            let zero = self.b.ins().f64const(0.0);
            self.b.ins().fcmp(FloatCC::NotEqual, v, zero)
        } else {
            let zero = self.b.ins().iconst(types::I64, 0);
            self.b.ins().icmp(IntCC::NotEqual, v, zero)
        })
    }
}
