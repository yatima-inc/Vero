import Vero.Common.Typ
import YatimaStdLib.Ord
import Std.Data.RBMap

namespace Vero.Frontend

/-- Inductive enumerating unary operators -/
inductive UnOp
  | neg | not
  deriving Ord, Repr

/-- Inductive enumerating binary operators -/
inductive BinOp
  | add | mul | sub | div | eq | neq | lt | le | gt | ge | and | or
  deriving Ord, Repr

/-- Inductive enumerating the primitive types -/
inductive Lit
  | nat  : Nat  → Lit
  | int  : Int  → Lit
  | bool : Bool → Lit
  deriving Ord, Inhabited, Repr

def Lit.typ : Lit → Typ
  | .nat  _ => .nat
  | .int  _ => .int
  | .bool _ => .bool

structure Var where
  name : String
  type : Typ
  deriving Ord, Inhabited, Repr

inductive AST
  | lit : Lit → AST
  | var : Var → AST
  | unOp : UnOp → AST → AST
  | binOp : BinOp → AST → AST → AST
  | letIn : Var → AST → AST → AST
  | lam : Var → AST → AST
  | app : AST → AST → AST
  | fork : AST → AST → AST → AST
  deriving Ord, Inhabited, Repr

def unify : Typ → Typ → Except String Typ
  | .hole, typ
  | typ, .hole => pure typ
  | .pi i₁ o₁, .pi i₂ o₂ => return .pi (← unify i₁ i₂) (← unify o₁ o₂)
  | .pair x₁ y₁, .pair x₂ y₂ => return .pair (← unify x₁ x₂) (← unify y₁ y₂)
  | x, y => if x == y then pure x else throw s!"Can't unify {x} and {y}"

def unify' (t : Typ) : List Typ → Except String Typ
  | [] => pure t
  | a :: as => do unify' (← unify t a) as

def AST.getVarTyp (s : String) : AST → Except String Typ
  | .var ⟨s', typ⟩ => if s == s' then pure typ else pure .hole
  | .lit .. => pure .hole
  | .unOp _ x => x.getVarTyp s
  | .binOp _ x y => do unify (← x.getVarTyp s) (← y.getVarTyp s)
  | .letIn ⟨s', _⟩ v b =>
    if s == s' then pure .hole
    else do unify (← v.getVarTyp s) (← b.getVarTyp s)
  | .lam ⟨s', _⟩ b => if s == s' then pure .hole else b.getVarTyp s
  | .app f a => do unify (← f.getVarTyp s) (← a.getVarTyp s)
  | .fork a b c => do unify' (← a.getVarTyp s) [(← b.getVarTyp s), (← c.getVarTyp s)]

abbrev Ctx := Std.RBMap String Typ compare

def AST.fillHoles (ctx : Ctx) : AST → Typ → Except String AST
  | x, .hole => pure x
  | x, typ => match x with
    | .var ⟨s, typ'⟩ => return .var ⟨s, ← unify typ typ'⟩
    | x@(.lit l) => do discard $ unify typ l.typ; return x
    | .unOp op x => match (op, typ) with
      | (.neg, .int)  => return .unOp .neg (← x.fillHoles ctx .int)
      | (.not, .bool) => return .unOp .not (← x.fillHoles ctx .bool)
      | _ => throw ""
    | b@(.binOp op x y) => match op with
      | .add | .mul | .sub | .div => match typ with
        | .nat | .int => return .binOp op (← x.fillHoles ctx typ) (← y.fillHoles ctx typ)
        | _ => throw ""
      | .and | .or => match typ with
        | .bool => return .binOp op (← x.fillHoles ctx typ) (← y.fillHoles ctx typ)
        | _ => throw ""
      | _ => return b
    | .fork a b c =>
      return .fork (← a.fillHoles ctx .bool) (← b.fillHoles ctx typ) (← c.fillHoles ctx typ)
    | .letIn ⟨s, sTyp⟩ v b => do
      let sTyp ← unify' sTyp [← v.getVarTyp s, ← b.getVarTyp s, typ]
      let ctx := ctx.insert s sTyp
      let v ← v.fillHoles ctx sTyp
      let b ← b.fillHoles ctx typ
      return .letIn ⟨s, sTyp⟩ v b
    | .lam ⟨s, sTyp⟩ b => match typ with
      | .pi iTyp oTyp => do
        let sTyp ← unify' sTyp [iTyp, ← b.getVarTyp s]
        let ctx := ctx.insert s sTyp
        let b ← b.fillHoles ctx oTyp
        return .lam ⟨s, sTyp⟩ b
      | _ => throw ""
    | x@(.app ..) => return x
    -- | x@(.app f a) => do match (← f.inferTyp ctx, ← a.inferTyp ctx) with
    --   | (.hole, _) => return x
    --   | (.pi iTyp oTyp, aTyp) =>
    --     let oTyp ← unify oTyp typ
    --     let iTyp ← unify iTyp aTyp
    --     let a ← a.fillHoles ctx iTyp
    --     let f ← f.fillHoles ctx (.pi iTyp oTyp)
    --     return .app f a
    --   | _ => throw ""

partial def AST.inferTyp (ctx : Ctx := default) : AST → Except String Typ
  | .lit l => return l.typ
  | .var ⟨s, sTyp⟩ => unify sTyp (ctx.find? s)
  | .unOp op x => match op with
    | .neg => do unify .int  (← x.inferTyp ctx)
    | .not => do unify .bool (← x.inferTyp ctx)
  | .binOp op x y => do
    let xyTyp ← unify (← x.inferTyp ctx) (← y.inferTyp ctx)
    match op with
    | .add | .mul | .sub | .div => match xyTyp with
      | .nat => return .nat
      | .int => return .int
      | x => throw s!"Expected nat or int but got {x}"
    | .lt | .le | .gt | .ge => match xyTyp with
      | .nat | .int => return .bool
      | x => throw s!"Expected nat or int but got {x}"
    | .eq | .neq => return .bool
    | .and | .or => unify .bool xyTyp
  | .letIn ⟨s, sTyp⟩ v b => do
    let sTyp ← unify' sTyp [← v.inferTyp ctx, ← v.getVarTyp s, ← b.getVarTyp s]
    let ctx := ctx.insert s sTyp
    let bTyp ← b.inferTyp ctx
    let v ← v.fillHoles ctx sTyp
    let b ← b.fillHoles ctx bTyp
    let sTyp ← unify' sTyp [← v.inferTyp ctx, ← v.getVarTyp s, ← b.getVarTyp s]
    b.inferTyp $ ctx.insert s sTyp
  | .lam ⟨s, sTyp⟩ b => do
    let sTyp ← unify sTyp (← b.getVarTyp s)
    let ctx := ctx.insert s sTyp
    let bTyp ← b.inferTyp ctx
    let b ← b.fillHoles ctx bTyp
    let sTyp ← unify sTyp (← b.getVarTyp s)
    return .pi sTyp bTyp
  | .app f a => do
    let aTyp ← match ← f.inferTyp ctx with
      | .hole => a.inferTyp ctx
      | .pi iTyp _ => unify iTyp (← a.inferTyp ctx)
      | _ => throw ""
    let f ← f.fillHoles ctx (.pi aTyp .hole)
    match ← f.inferTyp ctx with
    | .pi iTyp oTyp => discard $ unify iTyp aTyp; return oTyp
    | _ => throw ""
  | .fork x a b => do
    discard $ unify .bool (← x.inferTyp ctx)
    unify (← a.inferTyp ctx) (← b.inferTyp ctx)

end Vero.Frontend
