//! Top-level declarations: `use`, `data`, `enum`, `fn`, `system`, `query`.

use super::{ParseError, Parser};
use crate::ast::{
    DataDecl, Decl, EnumDecl, Field, FnBody, FnDecl, ImplDecl, Param, Program, Qualifier, QueryDecl,
    SystemDecl, TraitDecl, Type, Variant,
};
use crate::token::Tok;

impl Parser<'_> {
    pub(super) fn program(&mut self) -> Result<Program, ParseError> {
        let mut uses = Vec::new();
        let mut decls = Vec::new();
        self.skip_newlines();
        while self.peek().is_some() {
            if self.check(&Tok::Use) {
                self.bump();
                uses.push(self.use_path()?);
            } else {
                decls.push(self.decl()?);
            }
            self.skip_newlines();
        }
        Ok(Program { uses, decls })
    }

    /// `use foo` -> module file `foo.or`; `use foo.bar` -> `foo/bar.or`.
    fn use_path(&mut self) -> Result<String, ParseError> {
        let mut path = self.ident()?;
        while self.check(&Tok::Dot) {
            self.bump();
            path.push('.');
            path.push_str(&self.ident()?);
        }
        Ok(path)
    }

    fn decl(&mut self) -> Result<Decl, ParseError> {
        // The decl's first token sets the offside baseline for any block body.
        let base = self.cur_col();
        let public = self.check(&Tok::Pub) && { self.bump(); true };
        // §9 contextual keyword: `deterministic fn …` / `deterministic system …`
        // marks a body that the compiler restricts to reproducible ops.
        // Today: the flag is set on the decl and stored; future passes
        // (FMA contraction, transcendental selection, RNG forbidance)
        // read it. We accept it now so spec-compliant code parses.
        let deterministic = matches!(self.peek(), Some(Tok::Ident(n)) if n == "deterministic")
            && { self.bump(); true };
        match self.peek() {
            Some(Tok::Data) => Ok(Decl::Data(self.data_decl(public)?)),
            Some(Tok::Enum) => Ok(Decl::Enum(self.enum_decl(public, base)?)),
            Some(Tok::Fn) => {
                let mut f = self.fn_decl(public, base)?;
                f.deterministic = deterministic;
                Ok(Decl::Fn(f))
            }
            Some(Tok::System) => {
                let mut s = self.system_decl(public, base)?;
                s.deterministic = deterministic;
                Ok(Decl::System(s))
            }
            Some(Tok::Query) => Ok(Decl::Query(self.query_decl(public)?)),
            Some(Tok::Extern) => Ok(Decl::Fn(self.extern_fn(public)?)),
            Some(Tok::Trait) => Ok(Decl::Trait(self.trait_decl(public, base)?)),
            Some(Tok::Impl) => Ok(Decl::Impl(self.impl_decl(base)?)),
            other => Err(self.err(&format!(
                "expected a declaration (`data`, `fn`, `system`, `query`, `trait`, `impl`, or `extern`), found {other:?}"
            ))),
        }
    }

    fn data_decl(&mut self, public: bool) -> Result<DataDecl, ParseError> {
        self.eat(&Tok::Data)?;
        let name = self.ident()?;
        // §16 — optional `repr(c)` attribute. Locks layout for FFI.
        let mut repr_c = false;
        if matches!(self.peek(), Some(Tok::Ident(n)) if n == "repr") {
            self.bump(); // `repr`
            self.eat(&Tok::LParen)?;
            let inner = self.ident()?;
            self.eat(&Tok::RParen)?;
            if inner != "c" {
                return Err(self.err(&format!("unknown repr: `{inner}` (expected `c`)")));
            }
            repr_c = true;
        }
        // §5 — optional `layout(soa)` / `layout(aos)` / `layout(packed)`
        // hint. The planner respects it; `auto` (no hint) leaves the
        // choice to footprint analysis.
        let mut layout = crate::ast::LayoutHint::Auto;
        if matches!(self.peek(), Some(Tok::Ident(n)) if n == "layout") {
            self.bump();
            self.eat(&Tok::LParen)?;
            let kind = self.ident()?;
            self.eat(&Tok::RParen)?;
            layout = match kind.as_str() {
                "soa" => crate::ast::LayoutHint::Soa,
                "aos" => crate::ast::LayoutHint::Aos,
                "packed" => crate::ast::LayoutHint::Packed,
                "auto" => crate::ast::LayoutHint::Auto,
                other => return Err(self.err(&format!(
                    "unknown layout: `{other}` (expected `soa`, `aos`, `packed`, `auto`)"
                ))),
            };
        }
        self.eat(&Tok::Colon)?;
        let mut fields = vec![self.field()?];
        while self.check(&Tok::Comma) {
            self.bump();
            fields.push(self.field()?);
        }
        Ok(DataDecl { public, repr_c, layout, name, fields, file: self.file })
    }

    fn field(&mut self) -> Result<Field, ParseError> {
        let name = self.ident()?;
        self.eat(&Tok::Colon)?;
        let ty = self.ty()?;
        Ok(Field { name, ty })
    }

    fn enum_decl(&mut self, public: bool, base: u32) -> Result<EnumDecl, ParseError> {
        self.eat(&Tok::Enum)?;
        let name = self.ident()?;
        self.eat(&Tok::Colon)?;
        let mut variants = Vec::new();
        loop {
            self.skip_newlines();
            if self.peek().is_none() || self.cur_col() <= base {
                break;
            }
            variants.push(self.variant()?);
        }
        Ok(EnumDecl { public, name, variants, file: self.file })
    }

    fn variant(&mut self) -> Result<Variant, ParseError> {
        let name = self.ident()?;
        let payload = if self.check(&Tok::LParen) {
            self.bump();
            let types = self.comma_sep_types_until(&Tok::RParen)?;
            self.eat(&Tok::RParen)?;
            types
        } else {
            Vec::new()
        };
        Ok(Variant { name, payload })
    }

    fn comma_sep_types_until(&mut self, end: &Tok) -> Result<Vec<Type>, ParseError> {
        let mut out = Vec::new();
        if self.check(end) {
            return Ok(out);
        }
        loop {
            out.push(self.ty()?);
            if !self.check(&Tok::Comma) {
                return Ok(out);
            }
            self.bump();
        }
    }

    /// `extern fn name(args) -> ret` — no body. Host registers the impl.
    /// Also accepts §16's `extern "c" fn ...` form (calling-convention
    /// string). The ABI is recorded only by acceptance today; the JIT
    /// already uses the platform C ABI for extern calls.
    fn extern_fn(&mut self, public: bool) -> Result<FnDecl, ParseError> {
        self.eat(&Tok::Extern)?;
        // Optional ABI string.
        if let Some(Tok::Str(_)) = self.peek() {
            let _abi = match self.bump() {
                Some(Tok::Str(s)) => s,
                _ => unreachable!(),
            };
            // Currently we only know "c" — anything else parses but
            // gets the default C ABI at the FFI boundary.
        }
        self.eat(&Tok::Fn)?;
        let name = self.ident()?;
        let params = self.params()?;
        let ret = self.return_type()?;
        Ok(FnDecl {
            public, deterministic: false, name, generics: Vec::new(), params, ret,
            body: FnBody::Extern,
            file: self.file,
        })
    }

    fn fn_decl(&mut self, public: bool, base: u32) -> Result<FnDecl, ParseError> {
        self.eat(&Tok::Fn)?;
        let name = self.ident()?;
        // Optional generic type-param list `<T, U>`. Names are captured so
        // the typechecker can substitute them at call sites (HM-flavoured).
        let mut generics = Vec::new();
        if self.check(&Tok::Lt) {
            self.bump();
            loop {
                if self.check(&Tok::Gt) {
                    self.bump();
                    break;
                }
                // Capture an ident as a generic type-var name; skip commas.
                if let Ok(n) = self.ident() {
                    generics.push(n);
                } else {
                    self.bump();
                }
            }
        }
        let params = self.params()?;
        let ret = self.return_type()?;
        let body = self.fn_body(base)?;
        Ok(FnDecl { public, deterministic: false, name, generics, params, ret, body, file: self.file })
    }

    fn fn_body(&mut self, base: u32) -> Result<FnBody, ParseError> {
        if self.check(&Tok::Assign) {
            // `= expr` form (the expr may sit on the next line).
            self.bump();
            self.skip_newlines();
            Ok(FnBody::Expr(self.expr()?))
        } else {
            // `:` then statements indented past `base`.
            self.eat(&Tok::Colon)?;
            Ok(FnBody::Block(self.block(base)?))
        }
    }

    fn system_decl(&mut self, public: bool, base: u32) -> Result<SystemDecl, ParseError> {
        self.eat(&Tok::System)?;
        let name = self.ident()?;
        let params = self.params()?;
        // §15 — optional `before <sys>, <sys>` / `after <sys>` clauses
        // before the colon. Contextual: we look for an Ident matching
        // "before" or "after". Order doesn't matter; you can write both.
        let mut before = Vec::new();
        let mut after = Vec::new();
        loop {
            let is_before = matches!(self.peek(), Some(Tok::Ident(n)) if n == "before");
            let is_after = matches!(self.peek(), Some(Tok::Ident(n)) if n == "after");
            if !is_before && !is_after { break; }
            self.bump(); // before / after
            let target = self.ident()?;
            let bucket = if is_before { &mut before } else { &mut after };
            bucket.push(target);
            while self.check(&Tok::Comma) {
                self.bump();
                bucket.push(self.ident()?);
            }
        }
        self.eat(&Tok::Colon)?;
        let body = self.block(base)?;
        Ok(SystemDecl {
            public, deterministic: false, before, after,
            name, params, body, file: self.file,
        })
    }

    fn query_decl(&mut self, public: bool) -> Result<QueryDecl, ParseError> {
        self.eat(&Tok::Query)?;
        let name = self.ident()?;
        let params = self.params()?;
        let ret = self.return_type()?;
        self.eat(&Tok::Assign)?;
        self.skip_newlines();
        let body = self.expr()?;
        Ok(QueryDecl { public, name, params, ret, body, file: self.file })
    }

    /// `trait Name:` + one method signature per line, all indented past `base`.
    /// Each signature is `fn name(self, …) -> ret` — no body. We represent
    /// the missing body with `FnBody::Extern`, matching how a host-supplied
    /// FFI fn looks at parse time.
    fn trait_decl(&mut self, public: bool, base: u32) -> Result<TraitDecl, ParseError> {
        self.eat(&Tok::Trait)?;
        let name = self.ident()?;
        self.eat(&Tok::Colon)?;
        let mut methods = Vec::new();
        loop {
            self.skip_newlines();
            if self.peek().is_none() || self.cur_col() <= base {
                break;
            }
            methods.push(self.trait_method_sig()?);
        }
        Ok(TraitDecl { public, name, methods, file: self.file })
    }

    fn trait_method_sig(&mut self) -> Result<FnDecl, ParseError> {
        self.eat(&Tok::Fn)?;
        let name = self.ident()?;
        let params = self.params()?;
        let ret = self.return_type()?;
        Ok(FnDecl {
            public: true,
            deterministic: false,
            name,
            generics: Vec::new(),
            params,
            ret,
            body: FnBody::Extern,
            file: self.file,
        })
    }

    /// `impl Trait for Data:` + indented method bodies. Each method is a
    /// normal `fn` decl whose first param is `self` (its type is the impl's
    /// `for_type`, which the checker fills in).
    fn impl_decl(&mut self, base: u32) -> Result<ImplDecl, ParseError> {
        self.eat(&Tok::Impl)?;
        let trait_name = self.ident()?;
        self.eat(&Tok::For)?;
        let for_type = self.ident()?;
        self.eat(&Tok::Colon)?;
        let mut methods = Vec::new();
        loop {
            self.skip_newlines();
            if self.peek().is_none() || self.cur_col() <= base {
                break;
            }
            let method_base = self.cur_col();
            methods.push(self.fn_decl(true, method_base)?);
        }
        Ok(ImplDecl { trait_name, for_type, methods, file: self.file })
    }

    fn return_type(&mut self) -> Result<Option<Type>, ParseError> {
        if self.check(&Tok::Arrow) {
            self.bump();
            Ok(Some(self.ty()?))
        } else {
            Ok(None)
        }
    }

    fn params(&mut self) -> Result<Vec<Param>, ParseError> {
        self.eat(&Tok::LParen)?;
        let mut out = Vec::new();
        if !self.check(&Tok::RParen) {
            loop {
                out.push(self.param()?);
                if !self.check(&Tok::Comma) {
                    break;
                }
                self.bump();
            }
        }
        self.eat(&Tok::RParen)?;
        Ok(out)
    }

    /// `name`  |  `name: Type`  |  `name: mut Type`  |  `name: Type = default`
    fn param(&mut self) -> Result<Param, ParseError> {
        let name = self.ident()?;
        let (qualifier, ty) = if self.check(&Tok::Colon) {
            self.bump();
            let qual = self.param_qualifier();
            (qual, Some(self.ty()?))
        } else {
            (None, None)
        };
        let default = if self.check(&Tok::Assign) {
            self.bump();
            Some(self.expr()?)
        } else {
            None
        };
        Ok(Param { name, qualifier, ty, default })
    }

    fn param_qualifier(&mut self) -> Option<Qualifier> {
        match self.peek() {
            Some(Tok::Mut) => { self.bump(); Some(Qualifier::Mut) }
            Some(Tok::Take) => { self.bump(); Some(Qualifier::Take) }
            _ => None,
        }
    }

    /// A written type, including range types and `[T]` / `T?`.
    pub(super) fn ty(&mut self) -> Result<Type, ParseError> {
        let base = match self.peek() {
            Some(Tok::LBracket) => self.list_type()?,
            Some(Tok::Int(_)) => self.range_type()?,
            Some(Tok::Ident(_)) => Type::Named(self.ident()?),
            other => return Err(self.err(&format!("expected a type, found {other:?}"))),
        };
        if self.check(&Tok::Question) {
            self.bump();
            Ok(Type::Optional(Box::new(base)))
        } else {
            Ok(base)
        }
    }

    fn list_type(&mut self) -> Result<Type, ParseError> {
        self.eat(&Tok::LBracket)?;
        let inner = self.ty()?;
        self.eat(&Tok::RBracket)?;
        Ok(Type::List(Box::new(inner)))
    }

    fn range_type(&mut self) -> Result<Type, ParseError> {
        let lo = match self.bump() {
            Some(Tok::Int(n)) => n,
            _ => unreachable!("peeked Int"),
        };
        let inclusive = match self.bump() {
            Some(Tok::RangeIncl) => true,
            Some(Tok::RangeExcl) => false,
            other => return Err(self.err(&format!(
                "expected a range (`...` or `..<`) in type, found {other:?}"
            ))),
        };
        let hi = match self.bump() {
            Some(Tok::Int(n)) => n,
            other => return Err(self.err(&format!("expected an upper bound, found {other:?}"))),
        };
        Ok(Type::Range { lo, hi, inclusive })
    }
}
