(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [betree_main]: type definitions *)
module BetreeMain.Types
open Primitives

#set-options "--z3rlimit 50 --fuel 1 --ifuel 1"

(** [betree_main::betree::List] *)
type betree_List_t (t : Type0) =
| Betree_List_Cons : t -> betree_List_t t -> betree_List_t t
| Betree_List_Nil : betree_List_t t

(** [betree_main::betree::UpsertFunState] *)
type betree_UpsertFunState_t =
| Betree_UpsertFunState_Add : u64 -> betree_UpsertFunState_t
| Betree_UpsertFunState_Sub : u64 -> betree_UpsertFunState_t

(** [betree_main::betree::Message] *)
type betree_Message_t =
| Betree_Message_Insert : u64 -> betree_Message_t
| Betree_Message_Delete : betree_Message_t
| Betree_Message_Upsert : betree_UpsertFunState_t -> betree_Message_t

(** [betree_main::betree::Leaf] *)
type betree_Leaf_t = { id : u64; size : u64; }

(** [betree_main::betree::Internal] *)
type betree_Internal_t =
{
  id : u64; pivot : u64; left : betree_Node_t; right : betree_Node_t;
}

(** [betree_main::betree::Node] *)
and betree_Node_t =
| Betree_Node_Internal : betree_Internal_t -> betree_Node_t
| Betree_Node_Leaf : betree_Leaf_t -> betree_Node_t

(** [betree_main::betree::Params] *)
type betree_Params_t = { min_flush_size : u64; split_size : u64; }

(** [betree_main::betree::NodeIdCounter] *)
type betree_NodeIdCounter_t = { next_node_id : u64; }

(** [betree_main::betree::BeTree] *)
type betree_BeTree_t =
{
  params : betree_Params_t;
  node_id_cnt : betree_NodeIdCounter_t;
  root : betree_Node_t;
}

(** The state type used in the state-error monad *)
val state : Type0

