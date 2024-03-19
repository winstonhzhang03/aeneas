(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [demo] *)
module Demo
open Primitives

#set-options "--z3rlimit 50 --fuel 1 --ifuel 1"

(** [demo::choose]:
    Source: 'src/demo.rs', lines 5:0-5:70 *)
let choose
  (t : Type0) (b : bool) (x : t) (y : t) : result (t & (t -> result (t & t))) =
  if b
  then let back_'a = fun ret -> Return (ret, y) in Return (x, back_'a)
  else let back_'a = fun ret -> Return (x, ret) in Return (y, back_'a)

(** [demo::mul2_add1]:
    Source: 'src/demo.rs', lines 13:0-13:31 *)
let mul2_add1 (x : u32) : result u32 =
  let* i = u32_add x x in u32_add i 1

(** [demo::use_mul2_add1]:
    Source: 'src/demo.rs', lines 17:0-17:43 *)
let use_mul2_add1 (x : u32) (y : u32) : result u32 =
  let* i = mul2_add1 x in u32_add i y

(** [demo::incr]:
    Source: 'src/demo.rs', lines 21:0-21:31 *)
let incr (x : u32) : result u32 =
  u32_add x 1

(** [demo::use_incr]:
    Source: 'src/demo.rs', lines 25:0-25:17 *)
let use_incr : result unit =
  let* i = incr 0 in let* i1 = incr i in let* _ = incr i1 in Return ()

(** [demo::CList]
    Source: 'src/demo.rs', lines 34:0-34:17 *)
type cList_t (t : Type0) =
| CList_CCons : t -> cList_t t -> cList_t t
| CList_CNil : cList_t t

(** [demo::list_nth]:
    Source: 'src/demo.rs', lines 39:0-39:56 *)
let rec list_nth (t : Type0) (n : nat) (l : cList_t t) (i : u32) : result t =
  if is_zero n
  then Fail OutOfFuel
  else
    let n1 = decrease n in
    begin match l with
    | CList_CCons x tl ->
      if i = 0 then Return x else let* i1 = u32_sub i 1 in list_nth t n1 tl i1
    | CList_CNil -> Fail Failure
    end

(** [demo::list_nth_mut]:
    Source: 'src/demo.rs', lines 54:0-54:68 *)
let rec list_nth_mut
  (t : Type0) (n : nat) (l : cList_t t) (i : u32) :
  result (t & (t -> result (cList_t t)))
  =
  if is_zero n
  then Fail OutOfFuel
  else
    let n1 = decrease n in
    begin match l with
    | CList_CCons x tl ->
      if i = 0
      then
        let back_'a = fun ret -> Return (CList_CCons ret tl) in
        Return (x, back_'a)
      else
        let* i1 = u32_sub i 1 in
        let* (x1, list_nth_mut_back) = list_nth_mut t n1 tl i1 in
        let back_'a =
          fun ret ->
            let* tl1 = list_nth_mut_back ret in Return (CList_CCons x tl1) in
        Return (x1, back_'a)
    | CList_CNil -> Fail Failure
    end

(** [demo::list_nth_mut1]: loop 0:
    Source: 'src/demo.rs', lines 69:0-78:1 *)
let rec list_nth_mut1_loop
  (t : Type0) (n : nat) (l : cList_t t) (i : u32) :
  result (t & (t -> result (cList_t t)))
  =
  if is_zero n
  then Fail OutOfFuel
  else
    let n1 = decrease n in
    begin match l with
    | CList_CCons x tl ->
      if i = 0
      then
        let back_'a = fun ret -> Return (CList_CCons ret tl) in
        Return (x, back_'a)
      else
        let* i1 = u32_sub i 1 in
        let* (x1, back_'a) = list_nth_mut1_loop t n1 tl i1 in
        let back_'a1 =
          fun ret -> let* tl1 = back_'a ret in Return (CList_CCons x tl1) in
        Return (x1, back_'a1)
    | CList_CNil -> Fail Failure
    end

(** [demo::list_nth_mut1]:
    Source: 'src/demo.rs', lines 69:0-69:77 *)
let list_nth_mut1
  (t : Type0) (n : nat) (l : cList_t t) (i : u32) :
  result (t & (t -> result (cList_t t)))
  =
  let* (x, back_'a) = list_nth_mut1_loop t n l i in Return (x, back_'a)

(** [demo::i32_id]:
    Source: 'src/demo.rs', lines 80:0-80:28 *)
let rec i32_id (n : nat) (i : i32) : result i32 =
  if is_zero n
  then Fail OutOfFuel
  else
    let n1 = decrease n in
    if i = 0
    then Return 0
    else let* i1 = i32_sub i 1 in let* i2 = i32_id n1 i1 in i32_add i2 1

(** [demo::list_tail]:
    Source: 'src/demo.rs', lines 88:0-88:64 *)
let rec list_tail
  (t : Type0) (n : nat) (l : cList_t t) :
  result ((cList_t t) & (cList_t t -> result (cList_t t)))
  =
  if is_zero n
  then Fail OutOfFuel
  else
    let n1 = decrease n in
    begin match l with
    | CList_CCons x tl ->
      let* (c, list_tail_back) = list_tail t n1 tl in
      let back_'a =
        fun ret -> let* tl1 = list_tail_back ret in Return (CList_CCons x tl1)
        in
      Return (c, back_'a)
    | CList_CNil -> Return (CList_CNil, Return)
    end

(** Trait declaration: [demo::Counter]
    Source: 'src/demo.rs', lines 97:0-97:17 *)
noeq type counter_t (self : Type0) = { incr : self -> result (usize & self); }

(** [demo::{(demo::Counter for usize)}::incr]:
    Source: 'src/demo.rs', lines 102:4-102:31 *)
let counterUsize_incr (self : usize) : result (usize & usize) =
  let* self1 = usize_add self 1 in Return (self, self1)

(** Trait implementation: [demo::{(demo::Counter for usize)}]
    Source: 'src/demo.rs', lines 101:0-101:22 *)
let counterUsize : counter_t usize = { incr = counterUsize_incr; }

(** [demo::use_counter]:
    Source: 'src/demo.rs', lines 109:0-109:59 *)
let use_counter
  (t : Type0) (counterInst : counter_t t) (cnt : t) : result (usize & t) =
  counterInst.incr cnt

