(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [adt_borrows] *)
Require Import Primitives.
Import Primitives.
Require Import Coq.ZArith.ZArith.
Require Import List.
Import ListNotations.
Local Open Scope Primitives_scope.
Module AdtBorrows.

(** [adt_borrows::SharedWrapper]
    Source: 'tests/src/adt-borrows.rs', lines 4:0-4:35 *)
Definition SharedWrapper_t (T : Type) : Type := T.

(** [adt_borrows::{adt_borrows::SharedWrapper<'a, T>}::create]:
    Source: 'tests/src/adt-borrows.rs', lines 7:4-9:5 *)
Definition sharedWrapper_create
  {T : Type} (x : T) : result (SharedWrapper_t T) :=
  Ok x
.

(** [adt_borrows::{adt_borrows::SharedWrapper<'a, T>}::unwrap]:
    Source: 'tests/src/adt-borrows.rs', lines 11:4-13:5 *)
Definition sharedWrapper_unwrap
  {T : Type} (self : SharedWrapper_t T) : result T :=
  Ok self
.

End AdtBorrows.
