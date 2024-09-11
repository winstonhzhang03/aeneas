(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [hashmap]: templates for the decreases clauses *)
module Hashmap.Clauses.Template
open Primitives
open Hashmap.Types

#set-options "--z3rlimit 50 --fuel 1 --ifuel 1"

(** [hashmap::{hashmap::HashMap<T>}::allocate_slots]: decreases clause
    Source: 'tests/src/hashmap.rs', lines 63:4-69:5 *)
unfold
let hashMap_allocate_slots_loop_decreases (#t : Type0)
  (slots : alloc_vec_Vec (aList_t t)) (n : usize) : nat =
  admit ()

(** [hashmap::{hashmap::HashMap<T>}::clear]: decreases clause
    Source: 'tests/src/hashmap.rs', lines 97:8-102:5 *)
unfold
let hashMap_clear_loop_decreases (#t : Type0)
  (slots : alloc_vec_Vec (aList_t t)) (i : usize) : nat =
  admit ()

(** [hashmap::{hashmap::HashMap<T>}::insert_in_list]: decreases clause
    Source: 'tests/src/hashmap.rs', lines 111:4-128:5 *)
unfold
let hashMap_insert_in_list_loop_decreases (#t : Type0) (key : usize)
  (value : t) (ls : aList_t t) : nat =
  admit ()

(** [hashmap::{hashmap::HashMap<T>}::move_elements_from_list]: decreases clause
    Source: 'tests/src/hashmap.rs', lines 194:4-207:5 *)
unfold
let hashMap_move_elements_from_list_loop_decreases (#t : Type0)
  (ntable : hashMap_t t) (ls : aList_t t) : nat =
  admit ()

(** [hashmap::{hashmap::HashMap<T>}::move_elements]: decreases clause
    Source: 'tests/src/hashmap.rs', lines 182:8-191:5 *)
unfold
let hashMap_move_elements_loop_decreases (#t : Type0) (ntable : hashMap_t t)
  (slots : alloc_vec_Vec (aList_t t)) (i : usize) : nat =
  admit ()

(** [hashmap::{hashmap::HashMap<T>}::contains_key_in_list]: decreases clause
    Source: 'tests/src/hashmap.rs', lines 217:4-230:5 *)
unfold
let hashMap_contains_key_in_list_loop_decreases (#t : Type0) (key : usize)
  (ls : aList_t t) : nat =
  admit ()

(** [hashmap::{hashmap::HashMap<T>}::get_in_list]: decreases clause
    Source: 'tests/src/hashmap.rs', lines 235:4-248:5 *)
unfold
let hashMap_get_in_list_loop_decreases (#t : Type0) (key : usize)
  (ls : aList_t t) : nat =
  admit ()

(** [hashmap::{hashmap::HashMap<T>}::get_mut_in_list]: decreases clause
    Source: 'tests/src/hashmap.rs', lines 256:4-265:5 *)
unfold
let hashMap_get_mut_in_list_loop_decreases (#t : Type0) (ls : aList_t t)
  (key : usize) : nat =
  admit ()

(** [hashmap::{hashmap::HashMap<T>}::remove_from_list]: decreases clause
    Source: 'tests/src/hashmap.rs', lines 276:4-302:5 *)
unfold
let hashMap_remove_from_list_loop_decreases (#t : Type0) (key : usize)
  (ls : aList_t t) : nat =
  admit ()

