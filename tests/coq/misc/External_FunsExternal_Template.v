(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [external]: external functions.
-- This is a template file: rename it to "FunsExternal.lean" and fill the holes. *)
Require Import Primitives.
Import Primitives.
Require Import Coq.ZArith.ZArith.
Require Import List.
Import ListNotations.
Local Open Scope Primitives_scope.
Require Import External_Types.
Include External_Types.
Module External_FunsExternal_Template.

(** [core::cell::{core::cell::Cell<T>#10}::get]:
    Source: '/rustc/65ea825f4021eaf77f1b25139969712d65b435a4/library/core/src/cell.rs', lines 510:4-510:26
    Name pattern: core::cell::{core::cell::Cell<@T>}::get *)
Axiom core_cell_Cell_get :
  forall(T : Type) (markerCopyInst : core_marker_Copy_t T),
        core_cell_Cell_t T -> state -> result (state * T)
.

(** [core::cell::{core::cell::Cell<T>#11}::get_mut]:
    Source: '/rustc/65ea825f4021eaf77f1b25139969712d65b435a4/library/core/src/cell.rs', lines 588:4-588:39
    Name pattern: core::cell::{core::cell::Cell<@T>}::get_mut *)
Axiom core_cell_Cell_get_mut :
  forall(T : Type),
        core_cell_Cell_t T -> state -> result (state * (T * (T -> state ->
          result (state * (core_cell_Cell_t T)))))
.

End External_FunsExternal_Template.
