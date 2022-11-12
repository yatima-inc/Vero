import Vero.Reduce.Hashing.Datatypes
import YatimaStdLib.Fin
import Poseidon.ForLurk

namespace Vero.Hashing

open Reduce (Expr)

open Std (RBMap) in
structure EncodeState where
  exprs : RBMap Ptr  ExprF compare
  cache : RBMap Expr Ptr   compare
  deriving Inhabited

def EncodeState.store (stt : EncodeState) : StoreF :=
  ⟨stt.exprs⟩

abbrev EncodeM := StateM EncodeState

def hashPtrPair (x y : Ptr) : F :=
  .ofInt $ Poseidon.Lurk.hash x.tag.toF x.val y.tag.toF y.val

def hashPtr (x : Ptr) : F :=
  hashPtrPair x default -- use a simpler hashing function instead

def addExprHash (ptr : Ptr) (expr : ExprF) : EncodeM Ptr :=
  modifyGet fun stt => (ptr, { stt with exprs := stt.exprs.insert ptr expr })

def encodeExpr (e : Expr) : EncodeM Ptr := do
  match (← get).cache.find? e with
  | some ptr => pure ptr
  | none =>
    let ptr ← match e with
      | .var n => let n := .ofNat n; addExprHash ⟨.var, n⟩ (.var n)
      | .lam b => do
        let bPtr ← encodeExpr b
        addExprHash ⟨.lam, hashPtr bPtr⟩ (.lam bPtr)
      | .app f a => do
        let fPtr ← encodeExpr f
        let aPtr ← encodeExpr a
        addExprHash ⟨.app, hashPtrPair fPtr aPtr⟩ (.app fPtr aPtr)
    modifyGet fun stt =>
      (ptr, { stt with cache := stt.cache.insert e ptr })

end Hashing

namespace Reduce.Expr

open Hashing

def encode (e : Expr) : Ptr × StoreF :=
  match StateT.run (encodeExpr e) default with
  | (ptr, stt) => (ptr, stt.store)

def encode' (e : Expr) (stt : EncodeState := default) : Ptr × EncodeState :=
  StateT.run (encodeExpr e) stt

end Vero.Reduce.Expr
