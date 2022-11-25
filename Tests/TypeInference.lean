import LSpec
import Vero.Frontend.DSL

open Vero Frontend.DSL

def pairs : List $ Frontend.AST × (Option Typ) := [
  (⟦3⟧, some .nat),
  (⟦3 + +3⟧, none),
  (⟦3 + x⟧, some .nat),
  (⟦x + +3⟧, some .int),
  (⟦x + tt⟧, none),
  (⟦ff & tt⟧, some .bool),
  (⟦f : nat -> int -> nat := n y => n; f⟧,  some ⟪nat -> int -> nat⟫),
  -- (⟦f : nat -> int -> _ := n y => y; f⟧,  some ⟪nat -> int -> int⟫),
  (⟦(x : nat) y => x + y⟧, some ⟪nat -> nat -> nat⟫),
  (⟦f : _ -> _ -> _ := x (y : nat) => x + y; f⟧, some ⟪nat -> nat -> nat⟫),
  (⟦f x (y : nat) := x + y; f⟧, some ⟪nat -> nat -> nat⟫),
  (⟦f (x : nat) y := x + y; f⟧, some ⟪nat -> nat -> nat⟫),
  -- (⟦f := x => x; f @ 3⟧, some ⟪nat⟫),
  (⟦f : _ -> nat := x => x; f @ 3⟧, some ⟪nat⟫),
  -- (⟦f : nat -> _ := x => x; f @ 3⟧, some ⟪nat⟫),
  -- (⟦f : _ -> _ := x => x; f @ 3⟧, some ⟪nat⟫),
  -- (⟦f : _ := x => x; f @ 3⟧, some ⟪nat⟫),
  -- (⟦(x => x) @ 1⟧, some ⟪nat⟫),
  -- (⟦(x (y : int) => x) @ 1⟧, some ⟪int -> nat⟫),
  (⟦x (f : nat -> int) => f @ x⟧, some ⟪nat -> (nat -> int) -> int⟫)
  -- (⟦x (f : _ -> int) => f @ (x : bool)⟧, some ⟪bool -> (bool -> int) -> int⟫),
  -- TODO : add more tests
]

open LSpec in
def main := lspecIO $
  pairs.foldl (init := .done) fun tSeq (ast, expecTyp) =>
    tSeq ++ match expecTyp with
      | some expecTyp =>
        withExceptOk "Type inference succeeds" ast.inferTyp fun gotTyp =>
          test s!"Expected {expecTyp} equals {gotTyp}" (expecTyp == gotTyp)
      | none => withExceptError "Type inference fails" ast.inferTyp fun _ => .done
#eval main