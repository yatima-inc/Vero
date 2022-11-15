namespace Vero.Core

inductive AST
  | var : String → AST
  | lam : String → AST → AST
  | app : AST → AST → AST
  deriving Ord, Inhabited, Repr

def nApp (f a : AST) : Nat → AST
  | 0 => a
  | n + 1 => .app f (nApp f a n)

class ToAST (α : Type _) where
  toAST : α → AST

export ToAST (toAST)

instance : ToAST AST := ⟨id⟩

mutual 
  def AST.toString : AST → String
    | .var n => n
    | .lam n b => s!"(λ {n} {b.lamsToString})"
    | .app (.lam n b) y => s!"(λ {n} {b.lamsToString}) {y.toString}"
    | .app x y@(.app ..) => s!"{x.toString} ({y.toString})"
    | .app x@(.app ..) y => s!"{x.toString} {y.toString}"
    | .app x y => s!"{x.toString} {y.toString}"

  def AST.lamsToString : AST → String
    | .lam n b@(.lam ..) => s!"{n} {b.lamsToString}"
    | .lam n b => s!"{n}. {b.toString}"
    | x => s!"{x.toString}"
end

instance : ToString AST where 
  toString := AST.toString

def AST.freeVars :=
  let rec aux (ctx fs : List String) : AST → List String
  | var n => if !ctx.contains n && !fs.contains n then n::fs else fs
  | lam n b => aux (n::ctx) fs b
  | app x y => aux ctx (aux ctx fs x) y
  aux [] []

end Vero.Core