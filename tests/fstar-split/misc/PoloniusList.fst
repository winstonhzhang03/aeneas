(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [polonius_list] *)
module PoloniusList
open Primitives

#set-options "--z3rlimit 50 --fuel 1 --ifuel 1"

(** [polonius_list::List]
    Source: 'src/polonius_list.rs', lines 3:0-3:16 *)
type list_t (t : Type0) =
| List_Cons : t -> list_t t -> list_t t
| List_Nil : list_t t

(** [polonius_list::get_list_at_x]: forward function
    Source: 'src/polonius_list.rs', lines 13:0-13:76 *)
let rec get_list_at_x (ls : list_t u32) (x : u32) : result (list_t u32) =
  begin match ls with
  | List_Cons hd tl ->
    if hd = x then Return (List_Cons hd tl) else get_list_at_x tl x
  | List_Nil -> Return List_Nil
  end

(** [polonius_list::get_list_at_x]: backward function 0
    Source: 'src/polonius_list.rs', lines 13:0-13:76 *)
let rec get_list_at_x_back
  (ls : list_t u32) (x : u32) (ret : list_t u32) : result (list_t u32) =
  begin match ls with
  | List_Cons hd tl ->
    if hd = x
    then Return ret
    else let* tl1 = get_list_at_x_back tl x ret in Return (List_Cons hd tl1)
  | List_Nil -> Return ret
  end

