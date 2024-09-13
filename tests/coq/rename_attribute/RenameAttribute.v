(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [rename_attribute] *)
Require Import Primitives.
Import Primitives.
Require Import Coq.ZArith.ZArith.
Require Import List.
Import ListNotations.
Local Open Scope Primitives_scope.
Module RenameAttribute.

(** Trait declaration: [rename_attribute::BoolTrait]
    Source: 'tests/src/rename_attribute.rs', lines 8:0-18:1 *)
Record BoolTest_t (Self : Type) := mkBoolTest_t {
  BoolTest_t_getTest : Self -> result bool;
}.

Arguments mkBoolTest_t { _ }.
Arguments BoolTest_t_getTest { _ } _.

(** [rename_attribute::{rename_attribute::BoolTrait for bool}::get_bool]:
    Source: 'tests/src/rename_attribute.rs', lines 22:4-24:5 *)
Definition boolTraitBool_getTest (self : bool) : result bool :=
  Ok self.

(** Trait implementation: [rename_attribute::{rename_attribute::BoolTrait for bool}]
    Source: 'tests/src/rename_attribute.rs', lines 21:0-25:1 *)
Definition BoolImpl : BoolTest_t bool := {|
  BoolTest_t_getTest := boolTraitBool_getTest;
|}.

(** [rename_attribute::BoolTrait::ret_true]:
    Source: 'tests/src/rename_attribute.rs', lines 15:4-17:5 *)
Definition boolTrait_retTest
  {Self : Type} (self_clause : BoolTest_t Self) (self : Self) : result bool :=
  Ok true
.

(** [rename_attribute::test_bool_trait]:
    Source: 'tests/src/rename_attribute.rs', lines 28:0-30:1 *)
Definition boolFn (T : Type) (x : bool) : result bool :=
  b <- boolTraitBool_getTest x;
  if b then boolTrait_retTest BoolImpl x else Ok false
.

(** [rename_attribute::SimpleEnum]
    Source: 'tests/src/rename_attribute.rs', lines 36:0-41:1 *)
Inductive VariantsTest_t :=
| VariantsTest_Variant1 : VariantsTest_t
| VariantsTest_SecondVariant : VariantsTest_t
| VariantsTest_ThirdVariant : VariantsTest_t
.

(** [rename_attribute::Foo]
    Source: 'tests/src/rename_attribute.rs', lines 44:0-47:1 *)
Record StructTest_t := mkStructTest_t { structTest_FieldTest : u32; }.

(** [rename_attribute::C]
    Source: 'tests/src/rename_attribute.rs', lines 50:0-50:28 *)
Definition const_test_body : result u32 :=
  i <- u32_add 100%u32 10%u32; u32_add i 1%u32
.
Definition const_test : u32 := const_test_body%global.

(** [rename_attribute::CA]
    Source: 'tests/src/rename_attribute.rs', lines 53:0-53:23 *)
Definition const_aeneas11_body : result u32 := u32_add 10%u32 1%u32.
Definition const_aeneas11 : u32 := const_aeneas11_body%global.

(** [rename_attribute::factorial]:
    Source: 'tests/src/rename_attribute.rs', lines 56:0-62:1 *)
Fixpoint factfn (n : nat) (n1 : u64) : result u64 :=
  match n with
  | O => Fail_ OutOfFuel
  | S n2 =>
    if n1 s<= 1%u64
    then Ok 1%u64
    else (i <- u64_sub n1 1%u64; i1 <- factfn n2 i; u64_mul n1 i1)
  end
.

(** [rename_attribute::sum]: loop 0:
    Source: 'tests/src/rename_attribute.rs', lines 68:4-71:5 *)
Fixpoint no_borrows_sum_loop
  (n : nat) (max : u32) (i : u32) (s : u32) : result u32 :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    if i s< max
    then (
      s1 <- u32_add s i;
      i1 <- u32_add i 1%u32;
      no_borrows_sum_loop n1 max i1 s1)
    else u32_mul s 2%u32
  end
.

(** [rename_attribute::sum]:
    Source: 'tests/src/rename_attribute.rs', lines 65:0-75:1 *)
Definition no_borrows_sum (n : nat) (max : u32) : result u32 :=
  no_borrows_sum_loop n max 0%u32 0%u32
.

End RenameAttribute.
