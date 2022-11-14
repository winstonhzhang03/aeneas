(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [no_nested_borrows] *)
Require Import Primitives.
Import Primitives.
Require Import Coq.ZArith.ZArith.
Local Open Scope Primitives_scope.
Module NoNestedBorrows .

(** [no_nested_borrows::Pair] *)
Record Pair_t (T1 T2 : Type) := mkPair_t { Pair_x : T1; Pair_y : T2; } .

Arguments mkPair_t {T1} {T2} _ _  .
Arguments Pair_x {T1} {T2}  .
Arguments Pair_y {T1} {T2}  .

(** [no_nested_borrows::List] *)
Inductive List_t (T : Type) :=
| ListCons : T -> List_t T -> List_t T
| ListNil : List_t T
.

Arguments ListCons {T} _ _  .
Arguments ListNil {T}  .

(** [no_nested_borrows::One] *)
Inductive One_t (T1 : Type) := | OneOne : T1 -> One_t T1 .

Arguments OneOne {T1} _  .

(** [no_nested_borrows::EmptyEnum] *)
Inductive Empty_enum_t := | EmptyEnumEmpty : Empty_enum_t .

Arguments EmptyEnumEmpty  .

(** [no_nested_borrows::Enum] *)
Inductive Enum_t := | EnumVariant1 : Enum_t | EnumVariant2 : Enum_t .

Arguments EnumVariant1  .
Arguments EnumVariant2  .

(** [no_nested_borrows::EmptyStruct] *)
Record Empty_struct_t := mkEmpty_struct_t {  } .

Arguments mkEmpty_struct_t  .

(** [no_nested_borrows::Sum] *)
Inductive Sum_t (T1 T2 : Type) :=
| SumLeft : T1 -> Sum_t T1 T2
| SumRight : T2 -> Sum_t T1 T2
.

Arguments SumLeft {T1} {T2} _  .
Arguments SumRight {T1} {T2} _  .

(** [no_nested_borrows::neg_test] *)
Definition neg_test_fwd (x : i32) : result i32 := i <- i32_neg x; Return i .

(** [no_nested_borrows::add_test] *)
Definition add_test_fwd (x : u32) (y : u32) : result u32 :=
  i <- u32_add x y; Return i .

(** [no_nested_borrows::subs_test] *)
Definition subs_test_fwd (x : u32) (y : u32) : result u32 :=
  i <- u32_sub x y; Return i .

(** [no_nested_borrows::div_test] *)
Definition div_test_fwd (x : u32) (y : u32) : result u32 :=
  i <- u32_div x y; Return i .

(** [no_nested_borrows::div_test1] *)
Definition div_test1_fwd (x : u32) : result u32 :=
  i <- u32_div x 2 %u32; Return i .

(** [no_nested_borrows::rem_test] *)
Definition rem_test_fwd (x : u32) (y : u32) : result u32 :=
  i <- u32_rem x y; Return i .

(** [no_nested_borrows::cast_test] *)
Definition cast_test_fwd (x : u32) : result i32 :=
  i <- scalar_cast U32 I32 x; Return i .

(** [no_nested_borrows::test2] *)
Definition test2_fwd : result unit :=
  i <- u32_add 23 %u32 44 %u32; let _ := i in Return tt .

(** Unit test for [no_nested_borrows::test2] *)
Check (test2_fwd )%return.

(** [no_nested_borrows::get_max] *)
Definition get_max_fwd (x : u32) (y : u32) : result u32 :=
  if x s>= y then Return x else Return y .

(** [no_nested_borrows::test3] *)
Definition test3_fwd : result unit :=
  x <- get_max_fwd (4 %u32) (3 %u32);
  y <- get_max_fwd (10 %u32) (11 %u32);
  z <- u32_add x y;
  if negb (z s= 15 %u32) then Fail_ else Return tt
  .

(** Unit test for [no_nested_borrows::test3] *)
Check (test3_fwd )%return.

(** [no_nested_borrows::test_neg1] *)
Definition test_neg1_fwd : result unit :=
  y <- i32_neg (3 %i32); if negb (y s= (-3) %i32) then Fail_ else Return tt .

(** Unit test for [no_nested_borrows::test_neg1] *)
Check (test_neg1_fwd )%return.

(** [no_nested_borrows::refs_test1] *)
Definition refs_test1_fwd : result unit :=
  if negb (1 %i32 s= 1 %i32) then Fail_ else Return tt .

(** Unit test for [no_nested_borrows::refs_test1] *)
Check (refs_test1_fwd )%return.

(** [no_nested_borrows::refs_test2] *)
Definition refs_test2_fwd : result unit :=
  if negb (2 %i32 s= 2 %i32)
  then Fail_
  else
    if negb (0 %i32 s= 0 %i32)
    then Fail_
    else
      if negb (2 %i32 s= 2 %i32)
      then Fail_
      else if negb (2 %i32 s= 2 %i32) then Fail_ else Return tt
  .

(** Unit test for [no_nested_borrows::refs_test2] *)
Check (refs_test2_fwd )%return.

(** [no_nested_borrows::test_list1] *)
Definition test_list1_fwd : result unit := Return tt .

(** Unit test for [no_nested_borrows::test_list1] *)
Check (test_list1_fwd )%return.

(** [no_nested_borrows::test_box1] *)
Definition test_box1_fwd : result unit :=
  let b := 1 %i32 in
  let x := b in
  if negb (x s= 1 %i32) then Fail_ else Return tt
  .

(** Unit test for [no_nested_borrows::test_box1] *)
Check (test_box1_fwd )%return.

(** [no_nested_borrows::copy_int] *)
Definition copy_int_fwd (x : i32) : result i32 := Return x .

(** [no_nested_borrows::test_unreachable] *)
Definition test_unreachable_fwd (b : bool) : result unit :=
  if b then Fail_ else Return tt .

(** [no_nested_borrows::test_panic] *)
Definition test_panic_fwd (b : bool) : result unit :=
  if b then Fail_ else Return tt .

(** [no_nested_borrows::test_copy_int] *)
Definition test_copy_int_fwd : result unit :=
  y <- copy_int_fwd (0 %i32); if negb (0 %i32 s= y) then Fail_ else Return tt .

(** Unit test for [no_nested_borrows::test_copy_int] *)
Check (test_copy_int_fwd )%return.

(** [no_nested_borrows::is_cons] *)
Definition is_cons_fwd (T : Type) (l : List_t T) : result bool :=
  match l with | ListCons t l0 => Return true | ListNil => Return false end .

(** [no_nested_borrows::test_is_cons] *)
Definition test_is_cons_fwd : result unit :=
  let l := ListNil in
  b <- is_cons_fwd i32 (ListCons (0 %i32) l);
  if negb b then Fail_ else Return tt
  .

(** Unit test for [no_nested_borrows::test_is_cons] *)
Check (test_is_cons_fwd )%return.

(** [no_nested_borrows::split_list] *)
Definition split_list_fwd
  (T : Type) (l : List_t T) : result (T * (List_t T)) :=
  match l with | ListCons hd tl => Return (hd, tl) | ListNil => Fail_ end .

(** [no_nested_borrows::test_split_list] *)
Definition test_split_list_fwd : result unit :=
  let l := ListNil in
  p <- split_list_fwd i32 (ListCons (0 %i32) l);
  let (hd, _) := p in
  if negb (hd s= 0 %i32) then Fail_ else Return tt
  .

(** Unit test for [no_nested_borrows::test_split_list] *)
Check (test_split_list_fwd )%return.

(** [no_nested_borrows::choose] *)
Definition choose_fwd (T : Type) (b : bool) (x : T) (y : T) : result T :=
  if b then Return x else Return y .

(** [no_nested_borrows::choose] *)
Definition choose_back
  (T : Type) (b : bool) (x : T) (y : T) (ret : T) : result (T * T) :=
  if b then Return (ret, y) else Return (x, ret) .

(** [no_nested_borrows::choose_test] *)
Definition choose_test_fwd : result unit :=
  z <- choose_fwd i32 true (0 %i32) (0 %i32);
  z0 <- i32_add z 1 %i32;
  if negb (z0 s= 1 %i32)
  then Fail_
  else (
    p <- choose_back i32 true (0 %i32) (0 %i32) z0;
    let (x, y) := p in
    if negb (x s= 1 %i32)
    then Fail_
    else if negb (y s= 0 %i32) then Fail_ else Return tt)
  .

(** Unit test for [no_nested_borrows::choose_test] *)
Check (choose_test_fwd )%return.

(** [no_nested_borrows::test_char] *)
Definition test_char_fwd : result char :=
  Return (char_of_byte Coq.Init.Byte.x61) .

(** [no_nested_borrows::NodeElem] *)
Inductive Node_elem_t (T : Type) :=
| NodeElemCons : Tree_t T -> Node_elem_t T -> Node_elem_t T
| NodeElemNil : Node_elem_t T

(** [no_nested_borrows::Tree] *)
with Tree_t (T : Type) :=
| TreeLeaf : T -> Tree_t T
| TreeNode : T -> Node_elem_t T -> Tree_t T -> Tree_t T
.

Arguments NodeElemCons {T} _ _  .
Arguments NodeElemNil {T}  .

Arguments TreeLeaf {T} _  .
Arguments TreeNode {T} _ _ _  .

(** [no_nested_borrows::list_length] *)
Fixpoint list_length_fwd (T : Type) (l : List_t T) : result u32 :=
  match l with
  | ListCons t l1 =>
    i <- list_length_fwd T l1; i0 <- u32_add 1 %u32 i; Return i0
  | ListNil => Return (0 %u32)
  end
  .

(** [no_nested_borrows::list_nth_shared] *)
Fixpoint list_nth_shared_fwd (T : Type) (l : List_t T) (i : u32) : result T :=
  match l with
  | ListCons x tl =>
    if i s= 0 %u32
    then Return x
    else (i0 <- u32_sub i 1 %u32; t <- list_nth_shared_fwd T tl i0; Return t)
  | ListNil => Fail_
  end
  .

(** [no_nested_borrows::list_nth_mut] *)
Fixpoint list_nth_mut_fwd (T : Type) (l : List_t T) (i : u32) : result T :=
  match l with
  | ListCons x tl =>
    if i s= 0 %u32
    then Return x
    else (i0 <- u32_sub i 1 %u32; t <- list_nth_mut_fwd T tl i0; Return t)
  | ListNil => Fail_
  end
  .

(** [no_nested_borrows::list_nth_mut] *)
Fixpoint list_nth_mut_back
  (T : Type) (l : List_t T) (i : u32) (ret : T) : result (List_t T) :=
  match l with
  | ListCons x tl =>
    if i s= 0 %u32
    then Return (ListCons ret tl)
    else (
      i0 <- u32_sub i 1 %u32;
      tl0 <- list_nth_mut_back T tl i0 ret;
      Return (ListCons x tl0))
  | ListNil => Fail_
  end
  .

(** [no_nested_borrows::list_rev_aux] *)
Fixpoint list_rev_aux_fwd
  (T : Type) (li : List_t T) (lo : List_t T) : result (List_t T) :=
  match li with
  | ListCons hd tl => l <- list_rev_aux_fwd T tl (ListCons hd lo); Return l
  | ListNil => Return lo
  end
  .

(** [no_nested_borrows::list_rev] *)
Definition list_rev_fwd_back (T : Type) (l : List_t T) : result (List_t T) :=
  let li := mem_replace_fwd (List_t T) l ListNil in
  l0 <- list_rev_aux_fwd T li ListNil;
  Return l0
  .

(** [no_nested_borrows::test_list_functions] *)
Definition test_list_functions_fwd : result unit :=
  let l := ListNil in
  let l0 := ListCons (2 %i32) l in
  let l1 := ListCons (1 %i32) l0 in
  i <- list_length_fwd i32 (ListCons (0 %i32) l1);
  if negb (i s= 3 %u32)
  then Fail_
  else (
    i0 <- list_nth_shared_fwd i32 (ListCons (0 %i32) l1) (0 %u32);
    if negb (i0 s= 0 %i32)
    then Fail_
    else (
      i1 <- list_nth_shared_fwd i32 (ListCons (0 %i32) l1) (1 %u32);
      if negb (i1 s= 1 %i32)
      then Fail_
      else (
        i2 <- list_nth_shared_fwd i32 (ListCons (0 %i32) l1) (2 %u32);
        if negb (i2 s= 2 %i32)
        then Fail_
        else (
          ls <- list_nth_mut_back i32 (ListCons (0 %i32) l1) (1 %u32) (3 %i32);
          i3 <- list_nth_shared_fwd i32 ls (0 %u32);
          if negb (i3 s= 0 %i32)
          then Fail_
          else (
            i4 <- list_nth_shared_fwd i32 ls (1 %u32);
            if negb (i4 s= 3 %i32)
            then Fail_
            else (
              i5 <- list_nth_shared_fwd i32 ls (2 %u32);
              if negb (i5 s= 2 %i32) then Fail_ else Return tt))))))
  .

(** Unit test for [no_nested_borrows::test_list_functions] *)
Check (test_list_functions_fwd )%return.

(** [no_nested_borrows::id_mut_pair1] *)
Definition id_mut_pair1_fwd
  (T1 T2 : Type) (x : T1) (y : T2) : result (T1 * T2) :=
  Return (x, y) .

(** [no_nested_borrows::id_mut_pair1] *)
Definition id_mut_pair1_back
  (T1 T2 : Type) (x : T1) (y : T2) (ret : (T1 * T2)) : result (T1 * T2) :=
  let (t, t0) := ret in Return (t, t0) .

(** [no_nested_borrows::id_mut_pair2] *)
Definition id_mut_pair2_fwd
  (T1 T2 : Type) (p : (T1 * T2)) : result (T1 * T2) :=
  let (t, t0) := p in Return (t, t0) .

(** [no_nested_borrows::id_mut_pair2] *)
Definition id_mut_pair2_back
  (T1 T2 : Type) (p : (T1 * T2)) (ret : (T1 * T2)) : result (T1 * T2) :=
  let (t, t0) := ret in Return (t, t0) .

(** [no_nested_borrows::id_mut_pair3] *)
Definition id_mut_pair3_fwd
  (T1 T2 : Type) (x : T1) (y : T2) : result (T1 * T2) :=
  Return (x, y) .

(** [no_nested_borrows::id_mut_pair3] *)
Definition id_mut_pair3_back'a
  (T1 T2 : Type) (x : T1) (y : T2) (ret : T1) : result T1 :=
  Return ret .

(** [no_nested_borrows::id_mut_pair3] *)
Definition id_mut_pair3_back'b
  (T1 T2 : Type) (x : T1) (y : T2) (ret : T2) : result T2 :=
  Return ret .

(** [no_nested_borrows::id_mut_pair4] *)
Definition id_mut_pair4_fwd
  (T1 T2 : Type) (p : (T1 * T2)) : result (T1 * T2) :=
  let (t, t0) := p in Return (t, t0) .

(** [no_nested_borrows::id_mut_pair4] *)
Definition id_mut_pair4_back'a
  (T1 T2 : Type) (p : (T1 * T2)) (ret : T1) : result T1 :=
  Return ret .

(** [no_nested_borrows::id_mut_pair4] *)
Definition id_mut_pair4_back'b
  (T1 T2 : Type) (p : (T1 * T2)) (ret : T2) : result T2 :=
  Return ret .

(** [no_nested_borrows::StructWithTuple] *)
Record Struct_with_tuple_t (T1 T2 : Type) :=
mkStruct_with_tuple_t
{
  Struct_with_tuple_p : (T1 * T2);
}
.

Arguments mkStruct_with_tuple_t {T1} {T2} _  .
Arguments Struct_with_tuple_p {T1} {T2}  .

(** [no_nested_borrows::new_tuple1] *)
Definition new_tuple1_fwd : result (Struct_with_tuple_t u32 u32) :=
  Return (mkStruct_with_tuple_t (1 %u32, 2 %u32)) .

(** [no_nested_borrows::new_tuple2] *)
Definition new_tuple2_fwd : result (Struct_with_tuple_t i16 i16) :=
  Return (mkStruct_with_tuple_t (1 %i16, 2 %i16)) .

(** [no_nested_borrows::new_tuple3] *)
Definition new_tuple3_fwd : result (Struct_with_tuple_t u64 i64) :=
  Return (mkStruct_with_tuple_t (1 %u64, 2 %i64)) .

(** [no_nested_borrows::StructWithPair] *)
Record Struct_with_pair_t (T1 T2 : Type) :=
mkStruct_with_pair_t
{
  Struct_with_pair_p : Pair_t T1 T2;
}
.

Arguments mkStruct_with_pair_t {T1} {T2} _  .
Arguments Struct_with_pair_p {T1} {T2}  .

(** [no_nested_borrows::new_pair1] *)
Definition new_pair1_fwd : result (Struct_with_pair_t u32 u32) :=
  Return (mkStruct_with_pair_t (mkPair_t (1 %u32) (2 %u32))) .

(** [no_nested_borrows::test_constants] *)
Definition test_constants_fwd : result unit :=
  swt <- new_tuple1_fwd;
  match swt with
  | mkStruct_with_tuple_t p =>
    let (i, _) := p in
    if negb (i s= 1 %u32)
    then Fail_
    else (
      swt0 <- new_tuple2_fwd;
      match swt0 with
      | mkStruct_with_tuple_t p0 =>
        let (i0, _) := p0 in
        if negb (i0 s= 1 %i16)
        then Fail_
        else (
          swt1 <- new_tuple3_fwd;
          match swt1 with
          | mkStruct_with_tuple_t p1 =>
            let (i1, _) := p1 in
            if negb (i1 s= 1 %u64)
            then Fail_
            else (
              swp <- new_pair1_fwd;
              match swp with
              | mkStruct_with_pair_t p2 =>
                match p2 with
                | mkPair_t i2 i3 =>
                  if negb (i2 s= 1 %u32) then Fail_ else Return tt
                end
              end)
          end)
      end)
  end
  .

(** Unit test for [no_nested_borrows::test_constants] *)
Check (test_constants_fwd )%return.

(** [no_nested_borrows::test_weird_borrows1] *)
Definition test_weird_borrows1_fwd : result unit := Return tt .

(** Unit test for [no_nested_borrows::test_weird_borrows1] *)
Check (test_weird_borrows1_fwd )%return.

(** [no_nested_borrows::test_mem_replace] *)
Definition test_mem_replace_fwd_back (px : u32) : result u32 :=
  let y := mem_replace_fwd u32 px (1 %u32) in
  if negb (y s= 0 %u32) then Fail_ else Return (2 %u32)
  .

(** [no_nested_borrows::test_shared_borrow_bool1] *)
Definition test_shared_borrow_bool1_fwd (b : bool) : result u32 :=
  if b then Return (0 %u32) else Return (1 %u32) .

(** [no_nested_borrows::test_shared_borrow_bool2] *)
Definition test_shared_borrow_bool2_fwd : result u32 := Return (0 %u32) .

(** [no_nested_borrows::test_shared_borrow_enum1] *)
Definition test_shared_borrow_enum1_fwd (l : List_t u32) : result u32 :=
  match l with
  | ListCons i l0 => Return (1 %u32)
  | ListNil => Return (0 %u32)
  end
  .

(** [no_nested_borrows::test_shared_borrow_enum2] *)
Definition test_shared_borrow_enum2_fwd : result u32 := Return (0 %u32) .

End NoNestedBorrows .
