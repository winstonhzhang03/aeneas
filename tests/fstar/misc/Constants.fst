(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [constants] *)
module Constants
open Primitives

#set-options "--z3rlimit 50 --fuel 1 --ifuel 1"

(** [constants::X0]
    Source: 'tests/src/constants.rs', lines 8:0-8:22 *)
let x0_body : result u32 = Ok 0
let x0 : u32 = eval_global x0_body

(** [constants::X1]
    Source: 'tests/src/constants.rs', lines 10:0-10:29 *)
let x1_body : result u32 = Ok core_u32_max
let x1 : u32 = eval_global x1_body

(** [constants::X2]
    Source: 'tests/src/constants.rs', lines 13:0-16:2 *)
let x2_body : result u32 = Ok 3
let x2 : u32 = eval_global x2_body

(** [constants::incr]:
    Source: 'tests/src/constants.rs', lines 20:0-22:1 *)
let incr (n : u32) : result u32 =
  u32_add n 1

(** [constants::X3]
    Source: 'tests/src/constants.rs', lines 18:0-18:29 *)
let x3_body : result u32 = incr 32
let x3 : u32 = eval_global x3_body

(** [constants::mk_pair0]:
    Source: 'tests/src/constants.rs', lines 26:0-28:1 *)
let mk_pair0 (x : u32) (y1 : u32) : result (u32 & u32) =
  Ok (x, y1)

(** [constants::Pair]
    Source: 'tests/src/constants.rs', lines 39:0-42:1 *)
type pair_t (t1 : Type0) (t2 : Type0) = { x : t1; y : t2; }

(** [constants::mk_pair1]:
    Source: 'tests/src/constants.rs', lines 30:0-32:1 *)
let mk_pair1 (x : u32) (y1 : u32) : result (pair_t u32 u32) =
  Ok { x; y = y1 }

(** [constants::P0]
    Source: 'tests/src/constants.rs', lines 34:0-34:42 *)
let p0_body : result (u32 & u32) = mk_pair0 0 1
let p0 : (u32 & u32) = eval_global p0_body

(** [constants::P1]
    Source: 'tests/src/constants.rs', lines 35:0-35:46 *)
let p1_body : result (pair_t u32 u32) = mk_pair1 0 1
let p1 : pair_t u32 u32 = eval_global p1_body

(** [constants::P2]
    Source: 'tests/src/constants.rs', lines 36:0-36:34 *)
let p2_body : result (u32 & u32) = Ok (0, 1)
let p2 : (u32 & u32) = eval_global p2_body

(** [constants::P3]
    Source: 'tests/src/constants.rs', lines 37:0-37:51 *)
let p3_body : result (pair_t u32 u32) = Ok { x = 0; y = 1 }
let p3 : pair_t u32 u32 = eval_global p3_body

(** [constants::Wrap]
    Source: 'tests/src/constants.rs', lines 52:0-54:1 *)
type wrap_t (t : Type0) = { value : t; }

(** [constants::{constants::Wrap<T>}::new]:
    Source: 'tests/src/constants.rs', lines 57:4-59:5 *)
let wrap_new (#t : Type0) (value : t) : result (wrap_t t) =
  Ok { value }

(** [constants::Y]
    Source: 'tests/src/constants.rs', lines 44:0-44:38 *)
let y_body : result (wrap_t i32) = wrap_new 2
let y : wrap_t i32 = eval_global y_body

(** [constants::unwrap_y]:
    Source: 'tests/src/constants.rs', lines 46:0-48:1 *)
let unwrap_y : result i32 =
  Ok y.value

(** [constants::YVAL]
    Source: 'tests/src/constants.rs', lines 50:0-50:33 *)
let yval_body : result i32 = unwrap_y
let yval : i32 = eval_global yval_body

(** [constants::get_z1::Z1]
    Source: 'tests/src/constants.rs', lines 65:4-65:22 *)
let get_z1_z1_body : result i32 = Ok 3
let get_z1_z1 : i32 = eval_global get_z1_z1_body

(** [constants::get_z1]:
    Source: 'tests/src/constants.rs', lines 64:0-67:1 *)
let get_z1 : result i32 =
  Ok get_z1_z1

(** [constants::add]:
    Source: 'tests/src/constants.rs', lines 69:0-71:1 *)
let add (a : i32) (b : i32) : result i32 =
  i32_add a b

(** [constants::Q1]
    Source: 'tests/src/constants.rs', lines 77:0-77:22 *)
let q1_body : result i32 = Ok 5
let q1 : i32 = eval_global q1_body

(** [constants::Q2]
    Source: 'tests/src/constants.rs', lines 78:0-78:23 *)
let q2_body : result i32 = Ok q1
let q2 : i32 = eval_global q2_body

(** [constants::Q3]
    Source: 'tests/src/constants.rs', lines 79:0-79:31 *)
let q3_body : result i32 = add q2 3
let q3 : i32 = eval_global q3_body

(** [constants::get_z2]:
    Source: 'tests/src/constants.rs', lines 73:0-75:1 *)
let get_z2 : result i32 =
  let* i = get_z1 in let* i1 = add i q3 in add q1 i1

(** [constants::S1]
    Source: 'tests/src/constants.rs', lines 83:0-83:23 *)
let s1_body : result u32 = Ok 6
let s1 : u32 = eval_global s1_body

(** [constants::S2]
    Source: 'tests/src/constants.rs', lines 84:0-84:30 *)
let s2_body : result u32 = incr s1
let s2 : u32 = eval_global s2_body

(** [constants::S3]
    Source: 'tests/src/constants.rs', lines 85:0-85:35 *)
let s3_body : result (pair_t u32 u32) = Ok p3
let s3 : pair_t u32 u32 = eval_global s3_body

(** [constants::S4]
    Source: 'tests/src/constants.rs', lines 86:0-86:47 *)
let s4_body : result (pair_t u32 u32) = mk_pair1 7 8
let s4 : pair_t u32 u32 = eval_global s4_body

(** [constants::V]
    Source: 'tests/src/constants.rs', lines 89:0-91:1 *)
type v_t (t : Type0) (n : usize) = { x : array t n; }

(** [constants::{constants::V<T, N>}#1::LEN]
    Source: 'tests/src/constants.rs', lines 94:4-94:29 *)
let v_len_body (t : Type0) (n : usize) : result usize = Ok n
let v_len (t : Type0) (n : usize) : usize = eval_global (v_len_body t n)

(** [constants::use_v]:
    Source: 'tests/src/constants.rs', lines 97:0-99:1 *)
let use_v (t : Type0) (n : usize) : result usize =
  Ok (v_len t n)

