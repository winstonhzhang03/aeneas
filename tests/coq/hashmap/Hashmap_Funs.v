(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [hashmap]: function definitions *)
Require Import Primitives.
Import Primitives.
Require Import Coq.ZArith.ZArith.
Require Import List.
Import ListNotations.
Local Open Scope Primitives_scope.
Require Import Hashmap_Types.
Include Hashmap_Types.
Module Hashmap_Funs.

(** [hashmap::hash_key]:
    Source: 'tests/src/hashmap.rs', lines 27:0-27:32 *)
Definition hash_key (k : usize) : result usize :=
  Ok k.

(** [hashmap::{hashmap::HashMap<T>}::allocate_slots]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 50:4-56:5 *)
Fixpoint hashMap_allocate_slots_loop
  (T : Type) (n : nat) (slots : alloc_vec_Vec (List_t T)) (n1 : usize) :
  result (alloc_vec_Vec (List_t T))
  :=
  match n with
  | O => Fail_ OutOfFuel
  | S n2 =>
    if n1 s> 0%usize
    then (
      slots1 <- alloc_vec_Vec_push (List_t T) slots List_Nil;
      n3 <- usize_sub n1 1%usize;
      hashMap_allocate_slots_loop T n2 slots1 n3)
    else Ok slots
  end
.

(** [hashmap::{hashmap::HashMap<T>}::allocate_slots]:
    Source: 'tests/src/hashmap.rs', lines 50:4-50:76 *)
Definition hashMap_allocate_slots
  (T : Type) (n : nat) (slots : alloc_vec_Vec (List_t T)) (n1 : usize) :
  result (alloc_vec_Vec (List_t T))
  :=
  hashMap_allocate_slots_loop T n slots n1
.

(** [hashmap::{hashmap::HashMap<T>}::new_with_capacity]:
    Source: 'tests/src/hashmap.rs', lines 59:4-63:13 *)
Definition hashMap_new_with_capacity
  (T : Type) (n : nat) (capacity : usize) (max_load_dividend : usize)
  (max_load_divisor : usize) :
  result (HashMap_t T)
  :=
  slots <- hashMap_allocate_slots T n (alloc_vec_Vec_new (List_t T)) capacity;
  i <- usize_mul capacity max_load_dividend;
  i1 <- usize_div i max_load_divisor;
  Ok
    {|
      hashMap_num_entries := 0%usize;
      hashMap_max_load_factor := (max_load_dividend, max_load_divisor);
      hashMap_max_load := i1;
      hashMap_slots := slots
    |}
.

(** [hashmap::{hashmap::HashMap<T>}::new]:
    Source: 'tests/src/hashmap.rs', lines 75:4-75:24 *)
Definition hashMap_new (T : Type) (n : nat) : result (HashMap_t T) :=
  hashMap_new_with_capacity T n 32%usize 4%usize 5%usize
.

(** [hashmap::{hashmap::HashMap<T>}::clear]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 80:4-88:5 *)
Fixpoint hashMap_clear_loop
  (T : Type) (n : nat) (slots : alloc_vec_Vec (List_t T)) (i : usize) :
  result (alloc_vec_Vec (List_t T))
  :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    let i1 := alloc_vec_Vec_len (List_t T) slots in
    if i s< i1
    then (
      p <-
        alloc_vec_Vec_index_mut (List_t T) usize
          (core_slice_index_SliceIndexUsizeSliceTInst (List_t T)) slots i;
      let (_, index_mut_back) := p in
      i2 <- usize_add i 1%usize;
      slots1 <- index_mut_back List_Nil;
      hashMap_clear_loop T n1 slots1 i2)
    else Ok slots
  end
.

(** [hashmap::{hashmap::HashMap<T>}::clear]:
    Source: 'tests/src/hashmap.rs', lines 80:4-80:27 *)
Definition hashMap_clear
  (T : Type) (n : nat) (self : HashMap_t T) : result (HashMap_t T) :=
  hm <- hashMap_clear_loop T n self.(hashMap_slots) 0%usize;
  Ok
    {|
      hashMap_num_entries := 0%usize;
      hashMap_max_load_factor := self.(hashMap_max_load_factor);
      hashMap_max_load := self.(hashMap_max_load);
      hashMap_slots := hm
    |}
.

(** [hashmap::{hashmap::HashMap<T>}::len]:
    Source: 'tests/src/hashmap.rs', lines 90:4-90:30 *)
Definition hashMap_len (T : Type) (self : HashMap_t T) : result usize :=
  Ok self.(hashMap_num_entries)
.

(** [hashmap::{hashmap::HashMap<T>}::insert_in_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 97:4-114:5 *)
Fixpoint hashMap_insert_in_list_loop
  (T : Type) (n : nat) (key : usize) (value : T) (ls : List_t T) :
  result (bool * (List_t T))
  :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    match ls with
    | List_Cons ckey cvalue tl =>
      if ckey s= key
      then Ok (false, List_Cons ckey value tl)
      else (
        p <- hashMap_insert_in_list_loop T n1 key value tl;
        let (b, tl1) := p in
        Ok (b, List_Cons ckey cvalue tl1))
    | List_Nil => Ok (true, List_Cons key value List_Nil)
    end
  end
.

(** [hashmap::{hashmap::HashMap<T>}::insert_in_list]:
    Source: 'tests/src/hashmap.rs', lines 97:4-97:71 *)
Definition hashMap_insert_in_list
  (T : Type) (n : nat) (key : usize) (value : T) (ls : List_t T) :
  result (bool * (List_t T))
  :=
  hashMap_insert_in_list_loop T n key value ls
.

(** [hashmap::{hashmap::HashMap<T>}::insert_no_resize]:
    Source: 'tests/src/hashmap.rs', lines 117:4-117:54 *)
Definition hashMap_insert_no_resize
  (T : Type) (n : nat) (self : HashMap_t T) (key : usize) (value : T) :
  result (HashMap_t T)
  :=
  hash <- hash_key key;
  let i := alloc_vec_Vec_len (List_t T) self.(hashMap_slots) in
  hash_mod <- usize_rem hash i;
  p <-
    alloc_vec_Vec_index_mut (List_t T) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (List_t T))
      self.(hashMap_slots) hash_mod;
  let (l, index_mut_back) := p in
  p1 <- hashMap_insert_in_list T n key value l;
  let (inserted, l1) := p1 in
  if inserted
  then (
    i1 <- usize_add self.(hashMap_num_entries) 1%usize;
    v <- index_mut_back l1;
    Ok
      {|
        hashMap_num_entries := i1;
        hashMap_max_load_factor := self.(hashMap_max_load_factor);
        hashMap_max_load := self.(hashMap_max_load);
        hashMap_slots := v
      |})
  else (
    v <- index_mut_back l1;
    Ok
      {|
        hashMap_num_entries := self.(hashMap_num_entries);
        hashMap_max_load_factor := self.(hashMap_max_load_factor);
        hashMap_max_load := self.(hashMap_max_load);
        hashMap_slots := v
      |})
.

(** [hashmap::{hashmap::HashMap<T>}::move_elements_from_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 183:4-196:5 *)
Fixpoint hashMap_move_elements_from_list_loop
  (T : Type) (n : nat) (ntable : HashMap_t T) (ls : List_t T) :
  result (HashMap_t T)
  :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    match ls with
    | List_Cons k v tl =>
      ntable1 <- hashMap_insert_no_resize T n1 ntable k v;
      hashMap_move_elements_from_list_loop T n1 ntable1 tl
    | List_Nil => Ok ntable
    end
  end
.

(** [hashmap::{hashmap::HashMap<T>}::move_elements_from_list]:
    Source: 'tests/src/hashmap.rs', lines 183:4-183:72 *)
Definition hashMap_move_elements_from_list
  (T : Type) (n : nat) (ntable : HashMap_t T) (ls : List_t T) :
  result (HashMap_t T)
  :=
  hashMap_move_elements_from_list_loop T n ntable ls
.

(** [hashmap::{hashmap::HashMap<T>}::move_elements]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 171:4-180:5 *)
Fixpoint hashMap_move_elements_loop
  (T : Type) (n : nat) (ntable : HashMap_t T)
  (slots : alloc_vec_Vec (List_t T)) (i : usize) :
  result ((alloc_vec_Vec (List_t T)) * (HashMap_t T))
  :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    let i1 := alloc_vec_Vec_len (List_t T) slots in
    if i s< i1
    then (
      p <-
        alloc_vec_Vec_index_mut (List_t T) usize
          (core_slice_index_SliceIndexUsizeSliceTInst (List_t T)) slots i;
      let (l, index_mut_back) := p in
      let (ls, l1) := core_mem_replace (List_t T) l List_Nil in
      ntable1 <- hashMap_move_elements_from_list T n1 ntable ls;
      i2 <- usize_add i 1%usize;
      slots1 <- index_mut_back l1;
      hashMap_move_elements_loop T n1 ntable1 slots1 i2)
    else Ok (ntable, slots)
  end
.

(** [hashmap::{hashmap::HashMap<T>}::move_elements]:
    Source: 'tests/src/hashmap.rs', lines 171:4-171:95 *)
Definition hashMap_move_elements
  (T : Type) (n : nat) (ntable : HashMap_t T)
  (slots : alloc_vec_Vec (List_t T)) (i : usize) :
  result ((HashMap_t T) * (alloc_vec_Vec (List_t T)))
  :=
  hashMap_move_elements_loop T n ntable slots i
.

(** [hashmap::{hashmap::HashMap<T>}::try_resize]:
    Source: 'tests/src/hashmap.rs', lines 140:4-140:28 *)
Definition hashMap_try_resize
  (T : Type) (n : nat) (self : HashMap_t T) : result (HashMap_t T) :=
  max_usize <- scalar_cast U32 Usize core_u32_max;
  let capacity := alloc_vec_Vec_len (List_t T) self.(hashMap_slots) in
  n1 <- usize_div max_usize 2%usize;
  let (i, i1) := self.(hashMap_max_load_factor) in
  i2 <- usize_div n1 i;
  if capacity s<= i2
  then (
    i3 <- usize_mul capacity 2%usize;
    ntable <- hashMap_new_with_capacity T n i3 i i1;
    p <- hashMap_move_elements T n ntable self.(hashMap_slots) 0%usize;
    let (ntable1, _) := p in
    Ok
      {|
        hashMap_num_entries := self.(hashMap_num_entries);
        hashMap_max_load_factor := (i, i1);
        hashMap_max_load := ntable1.(hashMap_max_load);
        hashMap_slots := ntable1.(hashMap_slots)
      |})
  else
    Ok
      {|
        hashMap_num_entries := self.(hashMap_num_entries);
        hashMap_max_load_factor := (i, i1);
        hashMap_max_load := self.(hashMap_max_load);
        hashMap_slots := self.(hashMap_slots)
      |}
.

(** [hashmap::{hashmap::HashMap<T>}::insert]:
    Source: 'tests/src/hashmap.rs', lines 129:4-129:48 *)
Definition hashMap_insert
  (T : Type) (n : nat) (self : HashMap_t T) (key : usize) (value : T) :
  result (HashMap_t T)
  :=
  self1 <- hashMap_insert_no_resize T n self key value;
  i <- hashMap_len T self1;
  if i s> self1.(hashMap_max_load)
  then hashMap_try_resize T n self1
  else Ok self1
.

(** [hashmap::{hashmap::HashMap<T>}::contains_key_in_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 206:4-219:5 *)
Fixpoint hashMap_contains_key_in_list_loop
  (T : Type) (n : nat) (key : usize) (ls : List_t T) : result bool :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    match ls with
    | List_Cons ckey _ tl =>
      if ckey s= key
      then Ok true
      else hashMap_contains_key_in_list_loop T n1 key tl
    | List_Nil => Ok false
    end
  end
.

(** [hashmap::{hashmap::HashMap<T>}::contains_key_in_list]:
    Source: 'tests/src/hashmap.rs', lines 206:4-206:68 *)
Definition hashMap_contains_key_in_list
  (T : Type) (n : nat) (key : usize) (ls : List_t T) : result bool :=
  hashMap_contains_key_in_list_loop T n key ls
.

(** [hashmap::{hashmap::HashMap<T>}::contains_key]:
    Source: 'tests/src/hashmap.rs', lines 199:4-199:49 *)
Definition hashMap_contains_key
  (T : Type) (n : nat) (self : HashMap_t T) (key : usize) : result bool :=
  hash <- hash_key key;
  let i := alloc_vec_Vec_len (List_t T) self.(hashMap_slots) in
  hash_mod <- usize_rem hash i;
  l <-
    alloc_vec_Vec_index (List_t T) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (List_t T))
      self.(hashMap_slots) hash_mod;
  hashMap_contains_key_in_list T n key l
.

(** [hashmap::{hashmap::HashMap<T>}::get_in_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 224:4-237:5 *)
Fixpoint hashMap_get_in_list_loop
  (T : Type) (n : nat) (key : usize) (ls : List_t T) : result T :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    match ls with
    | List_Cons ckey cvalue tl =>
      if ckey s= key then Ok cvalue else hashMap_get_in_list_loop T n1 key tl
    | List_Nil => Fail_ Failure
    end
  end
.

(** [hashmap::{hashmap::HashMap<T>}::get_in_list]:
    Source: 'tests/src/hashmap.rs', lines 224:4-224:70 *)
Definition hashMap_get_in_list
  (T : Type) (n : nat) (key : usize) (ls : List_t T) : result T :=
  hashMap_get_in_list_loop T n key ls
.

(** [hashmap::{hashmap::HashMap<T>}::get]:
    Source: 'tests/src/hashmap.rs', lines 239:4-239:55 *)
Definition hashMap_get
  (T : Type) (n : nat) (self : HashMap_t T) (key : usize) : result T :=
  hash <- hash_key key;
  let i := alloc_vec_Vec_len (List_t T) self.(hashMap_slots) in
  hash_mod <- usize_rem hash i;
  l <-
    alloc_vec_Vec_index (List_t T) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (List_t T))
      self.(hashMap_slots) hash_mod;
  hashMap_get_in_list T n key l
.

(** [hashmap::{hashmap::HashMap<T>}::get_mut_in_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 245:4-254:5 *)
Fixpoint hashMap_get_mut_in_list_loop
  (T : Type) (n : nat) (ls : List_t T) (key : usize) :
  result (T * (T -> result (List_t T)))
  :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    match ls with
    | List_Cons ckey cvalue tl =>
      if ckey s= key
      then
        let back := fun (ret : T) => Ok (List_Cons ckey ret tl) in
        Ok (cvalue, back)
      else (
        p <- hashMap_get_mut_in_list_loop T n1 tl key;
        let (t, back) := p in
        let back1 :=
          fun (ret : T) => tl1 <- back ret; Ok (List_Cons ckey cvalue tl1) in
        Ok (t, back1))
    | List_Nil => Fail_ Failure
    end
  end
.

(** [hashmap::{hashmap::HashMap<T>}::get_mut_in_list]:
    Source: 'tests/src/hashmap.rs', lines 245:4-245:86 *)
Definition hashMap_get_mut_in_list
  (T : Type) (n : nat) (ls : List_t T) (key : usize) :
  result (T * (T -> result (List_t T)))
  :=
  hashMap_get_mut_in_list_loop T n ls key
.

(** [hashmap::{hashmap::HashMap<T>}::get_mut]:
    Source: 'tests/src/hashmap.rs', lines 257:4-257:67 *)
Definition hashMap_get_mut
  (T : Type) (n : nat) (self : HashMap_t T) (key : usize) :
  result (T * (T -> result (HashMap_t T)))
  :=
  hash <- hash_key key;
  let i := alloc_vec_Vec_len (List_t T) self.(hashMap_slots) in
  hash_mod <- usize_rem hash i;
  p <-
    alloc_vec_Vec_index_mut (List_t T) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (List_t T))
      self.(hashMap_slots) hash_mod;
  let (l, index_mut_back) := p in
  p1 <- hashMap_get_mut_in_list T n l key;
  let (t, get_mut_in_list_back) := p1 in
  let back :=
    fun (ret : T) =>
      l1 <- get_mut_in_list_back ret;
      v <- index_mut_back l1;
      Ok
        {|
          hashMap_num_entries := self.(hashMap_num_entries);
          hashMap_max_load_factor := self.(hashMap_max_load_factor);
          hashMap_max_load := self.(hashMap_max_load);
          hashMap_slots := v
        |} in
  Ok (t, back)
.

(** [hashmap::{hashmap::HashMap<T>}::remove_from_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 265:4-291:5 *)
Fixpoint hashMap_remove_from_list_loop
  (T : Type) (n : nat) (key : usize) (ls : List_t T) :
  result ((option T) * (List_t T))
  :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    match ls with
    | List_Cons ckey t tl =>
      if ckey s= key
      then
        let (mv_ls, _) :=
          core_mem_replace (List_t T) (List_Cons ckey t tl) List_Nil in
        match mv_ls with
        | List_Cons _ cvalue tl1 => Ok (Some cvalue, tl1)
        | List_Nil => Fail_ Failure
        end
      else (
        p <- hashMap_remove_from_list_loop T n1 key tl;
        let (o, tl1) := p in
        Ok (o, List_Cons ckey t tl1))
    | List_Nil => Ok (None, List_Nil)
    end
  end
.

(** [hashmap::{hashmap::HashMap<T>}::remove_from_list]:
    Source: 'tests/src/hashmap.rs', lines 265:4-265:69 *)
Definition hashMap_remove_from_list
  (T : Type) (n : nat) (key : usize) (ls : List_t T) :
  result ((option T) * (List_t T))
  :=
  hashMap_remove_from_list_loop T n key ls
.

(** [hashmap::{hashmap::HashMap<T>}::remove]:
    Source: 'tests/src/hashmap.rs', lines 294:4-294:52 *)
Definition hashMap_remove
  (T : Type) (n : nat) (self : HashMap_t T) (key : usize) :
  result ((option T) * (HashMap_t T))
  :=
  hash <- hash_key key;
  let i := alloc_vec_Vec_len (List_t T) self.(hashMap_slots) in
  hash_mod <- usize_rem hash i;
  p <-
    alloc_vec_Vec_index_mut (List_t T) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (List_t T))
      self.(hashMap_slots) hash_mod;
  let (l, index_mut_back) := p in
  p1 <- hashMap_remove_from_list T n key l;
  let (x, l1) := p1 in
  match x with
  | None =>
    v <- index_mut_back l1;
    Ok (None,
      {|
        hashMap_num_entries := self.(hashMap_num_entries);
        hashMap_max_load_factor := self.(hashMap_max_load_factor);
        hashMap_max_load := self.(hashMap_max_load);
        hashMap_slots := v
      |})
  | Some x1 =>
    i1 <- usize_sub self.(hashMap_num_entries) 1%usize;
    v <- index_mut_back l1;
    Ok (Some x1,
      {|
        hashMap_num_entries := i1;
        hashMap_max_load_factor := self.(hashMap_max_load_factor);
        hashMap_max_load := self.(hashMap_max_load);
        hashMap_slots := v
      |})
  end
.

(** [hashmap::test1]:
    Source: 'tests/src/hashmap.rs', lines 315:0-315:10 *)
Definition test1 (n : nat) : result unit :=
  hm <- hashMap_new u64 n;
  hm1 <- hashMap_insert u64 n hm 0%usize 42%u64;
  hm2 <- hashMap_insert u64 n hm1 128%usize 18%u64;
  hm3 <- hashMap_insert u64 n hm2 1024%usize 138%u64;
  hm4 <- hashMap_insert u64 n hm3 1056%usize 256%u64;
  i <- hashMap_get u64 n hm4 128%usize;
  if negb (i s= 18%u64)
  then Fail_ Failure
  else (
    p <- hashMap_get_mut u64 n hm4 1024%usize;
    let (_, get_mut_back) := p in
    hm5 <- get_mut_back 56%u64;
    i1 <- hashMap_get u64 n hm5 1024%usize;
    if negb (i1 s= 56%u64)
    then Fail_ Failure
    else (
      p1 <- hashMap_remove u64 n hm5 1024%usize;
      let (x, hm6) := p1 in
      match x with
      | None => Fail_ Failure
      | Some x1 =>
        if negb (x1 s= 56%u64)
        then Fail_ Failure
        else (
          i2 <- hashMap_get u64 n hm6 0%usize;
          if negb (i2 s= 42%u64)
          then Fail_ Failure
          else (
            i3 <- hashMap_get u64 n hm6 128%usize;
            if negb (i3 s= 18%u64)
            then Fail_ Failure
            else (
              i4 <- hashMap_get u64 n hm6 1056%usize;
              if negb (i4 s= 256%u64) then Fail_ Failure else Ok tt)))
      end))
.

End Hashmap_Funs.
