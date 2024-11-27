-- THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS
-- [betree]: function definitions
import Base
import Betree.Types
import Betree.FunsExternal
open Primitives
set_option linter.dupNamespace false
set_option linter.hashCommand false
set_option linter.unusedVariables false

namespace betree

/- [betree::betree::load_internal_node]:
   Source: 'src/betree.rs', lines 36:0-38:1 -/
def betree.load_internal_node
  (id : U64) (st : State) :
  Result (State × (betree.List (U64 × betree.Message)))
  :=
  betree_utils.load_internal_node id st

/- [betree::betree::store_internal_node]:
   Source: 'src/betree.rs', lines 41:0-43:1 -/
def betree.store_internal_node
  (id : U64) (content : betree.List (U64 × betree.Message)) (st : State) :
  Result (State × Unit)
  :=
  betree_utils.store_internal_node id content st

/- [betree::betree::load_leaf_node]:
   Source: 'src/betree.rs', lines 46:0-48:1 -/
def betree.load_leaf_node
  (id : U64) (st : State) : Result (State × (betree.List (U64 × U64))) :=
  betree_utils.load_leaf_node id st

/- [betree::betree::store_leaf_node]:
   Source: 'src/betree.rs', lines 51:0-53:1 -/
def betree.store_leaf_node
  (id : U64) (content : betree.List (U64 × U64)) (st : State) :
  Result (State × Unit)
  :=
  betree_utils.store_leaf_node id content st

/- [betree::betree::fresh_node_id]:
   Source: 'src/betree.rs', lines 55:0-59:1 -/
def betree.fresh_node_id (counter : U64) : Result (U64 × U64) :=
  do
  let counter1 ← counter + 1#u64
  Result.ok (counter, counter1)

/- [betree::betree::{betree::betree::NodeIdCounter}::new]:
   Source: 'src/betree.rs', lines 206:4-208:5 -/
def betree.NodeIdCounter.new : Result betree.NodeIdCounter :=
  Result.ok { next_node_id := 0#u64 }

/- [betree::betree::{betree::betree::NodeIdCounter}::fresh_id]:
   Source: 'src/betree.rs', lines 210:4-214:5 -/
def betree.NodeIdCounter.fresh_id
  (self : betree.NodeIdCounter) : Result (U64 × betree.NodeIdCounter) :=
  do
  let i ← self.next_node_id + 1#u64
  Result.ok (self.next_node_id, { next_node_id := i })

/- [betree::betree::upsert_update]:
   Source: 'src/betree.rs', lines 234:0-273:1 -/
def betree.upsert_update
  (prev : Option U64) (st : betree.UpsertFunState) : Result U64 :=
  match prev with
  | none =>
    match st with
    | betree.UpsertFunState.Add v => Result.ok v
    | betree.UpsertFunState.Sub _ => Result.ok 0#u64
  | some prev1 =>
    match st with
    | betree.UpsertFunState.Add v =>
      do
      let margin ← core_u64_max - prev1
      if margin >= v
      then prev1 + v
      else Result.ok core_u64_max
    | betree.UpsertFunState.Sub v =>
      if prev1 >= v
      then prev1 - v
      else Result.ok 0#u64

/- [betree::betree::{betree::betree::List<T>}#1::len]: loop 0:
   Source: 'src/betree.rs', lines 279:8-282:9 -/
divergent def betree.List.len_loop
  {T : Type} (self : betree.List T) (len : U64) : Result U64 :=
  match self with
  | betree.List.Cons _ tl =>
    do
    let len1 ← len + 1#u64
    betree.List.len_loop tl len1
  | betree.List.Nil => Result.ok len

/- [betree::betree::{betree::betree::List<T>}#1::len]:
   Source: 'src/betree.rs', lines 276:4-284:5 -/
def betree.List.len {T : Type} (self : betree.List T) : Result U64 :=
  betree.List.len_loop self 0#u64

/- [betree::betree::{betree::betree::List<T>}#1::reverse]: loop 0:
   Source: 'src/betree.rs', lines 306:8-310:9 -/
divergent def betree.List.reverse_loop
  {T : Type} (self : betree.List T) (out : betree.List T) :
  Result (betree.List T)
  :=
  match self with
  | betree.List.Cons hd tl =>
    betree.List.reverse_loop tl (betree.List.Cons hd out)
  | betree.List.Nil => Result.ok out

/- [betree::betree::{betree::betree::List<T>}#1::reverse]:
   Source: 'src/betree.rs', lines 304:4-312:5 -/
def betree.List.reverse
  {T : Type} (self : betree.List T) : Result (betree.List T) :=
  betree.List.reverse_loop self betree.List.Nil

/- [betree::betree::{betree::betree::List<T>}#1::split_at]: loop 0:
   Source: 'src/betree.rs', lines 290:8-300:9 -/
divergent def betree.List.split_at_loop
  {T : Type} (n : U64) (beg : betree.List T) (self : betree.List T) :
  Result ((betree.List T) × (betree.List T))
  :=
  if n > 0#u64
  then
    match self with
    | betree.List.Cons hd tl =>
      do
      let n1 ← n - 1#u64
      betree.List.split_at_loop n1 (betree.List.Cons hd beg) tl
    | betree.List.Nil => Result.fail .panic
  else do
       let l ← betree.List.reverse beg
       Result.ok (l, self)

/- [betree::betree::{betree::betree::List<T>}#1::split_at]:
   Source: 'src/betree.rs', lines 287:4-302:5 -/
def betree.List.split_at
  {T : Type} (self : betree.List T) (n : U64) :
  Result ((betree.List T) × (betree.List T))
  :=
  betree.List.split_at_loop n betree.List.Nil self

/- [betree::betree::{betree::betree::List<T>}#1::push_front]:
   Source: 'src/betree.rs', lines 315:4-319:5 -/
def betree.List.push_front
  {T : Type} (self : betree.List T) (x : T) : Result (betree.List T) :=
  let (tl, _) := core.mem.replace self betree.List.Nil
  Result.ok (betree.List.Cons x tl)

/- [betree::betree::{betree::betree::List<T>}#1::pop_front]:
   Source: 'src/betree.rs', lines 322:4-332:5 -/
def betree.List.pop_front
  {T : Type} (self : betree.List T) : Result (T × (betree.List T)) :=
  let (ls, _) := core.mem.replace self betree.List.Nil
  match ls with
  | betree.List.Cons x tl => Result.ok (x, tl)
  | betree.List.Nil => Result.fail .panic

/- [betree::betree::{betree::betree::List<T>}#1::hd]:
   Source: 'src/betree.rs', lines 334:4-339:5 -/
def betree.List.hd {T : Type} (self : betree.List T) : Result T :=
  match self with
  | betree.List.Cons hd _ => Result.ok hd
  | betree.List.Nil => Result.fail .panic

/- [betree::betree::{betree::betree::List<(u64, T)>}#2::head_has_key]:
   Source: 'src/betree.rs', lines 343:4-348:5 -/
def betree.ListPairU64T.head_has_key
  {T : Type} (self : betree.List (U64 × T)) (key : U64) : Result Bool :=
  match self with
  | betree.List.Cons hd _ => let (i, _) := hd
                             Result.ok (i = key)
  | betree.List.Nil => Result.ok false

/- [betree::betree::{betree::betree::List<(u64, T)>}#2::partition_at_pivot]: loop 0:
   Source: 'src/betree.rs', lines 359:8-368:9 -/
divergent def betree.ListPairU64T.partition_at_pivot_loop
  {T : Type} (pivot : U64) (beg : betree.List (U64 × T))
  (end1 : betree.List (U64 × T)) (self : betree.List (U64 × T)) :
  Result ((betree.List (U64 × T)) × (betree.List (U64 × T)))
  :=
  match self with
  | betree.List.Cons hd tl =>
    let (i, _) := hd
    if i >= pivot
    then
      betree.ListPairU64T.partition_at_pivot_loop pivot beg (betree.List.Cons
        hd end1) tl
    else
      betree.ListPairU64T.partition_at_pivot_loop pivot (betree.List.Cons hd
        beg) end1 tl
  | betree.List.Nil =>
    do
    let l ← betree.List.reverse beg
    let l1 ← betree.List.reverse end1
    Result.ok (l, l1)

/- [betree::betree::{betree::betree::List<(u64, T)>}#2::partition_at_pivot]:
   Source: 'src/betree.rs', lines 355:4-370:5 -/
def betree.ListPairU64T.partition_at_pivot
  {T : Type} (self : betree.List (U64 × T)) (pivot : U64) :
  Result ((betree.List (U64 × T)) × (betree.List (U64 × T)))
  :=
  betree.ListPairU64T.partition_at_pivot_loop pivot betree.List.Nil
    betree.List.Nil self

/- [betree::betree::{betree::betree::Leaf}#3::split]:
   Source: 'src/betree.rs', lines 378:4-409:5 -/
def betree.Leaf.split
  (self : betree.Leaf) (content : betree.List (U64 × U64))
  (params : betree.Params) (node_id_cnt : betree.NodeIdCounter) (st : State) :
  Result (State × (betree.Internal × betree.NodeIdCounter))
  :=
  do
  let p ← betree.List.split_at content params.split_size
  let (content0, content1) := p
  let p1 ← betree.List.hd content1
  let (pivot, _) := p1
  let (id0, node_id_cnt1) ← betree.NodeIdCounter.fresh_id node_id_cnt
  let (id1, node_id_cnt2) ← betree.NodeIdCounter.fresh_id node_id_cnt1
  let (st1, _) ← betree.store_leaf_node id0 content0 st
  let (st2, _) ← betree.store_leaf_node id1 content1 st1
  let n := betree.Node.Leaf { id := id0, size := params.split_size }
  let n1 := betree.Node.Leaf { id := id1, size := params.split_size }
  Result.ok (st2, (betree.Internal.mk self.id pivot n n1, node_id_cnt2))

/- [betree::betree::{betree::betree::Node}#5::lookup_first_message_for_key]: loop 0:
   Source: 'src/betree.rs', lines 796:8-810:5 -/
divergent def betree.Node.lookup_first_message_for_key_loop
  (key : U64) (msgs : betree.List (U64 × betree.Message)) :
  Result ((betree.List (U64 × betree.Message)) × (betree.List (U64 ×
    betree.Message) → betree.List (U64 × betree.Message)))
  :=
  match msgs with
  | betree.List.Cons x next_msgs =>
    let (i, _) := x
    if i >= key
    then let back := fun ret => ret
         Result.ok (msgs, back)
    else
      do
      let (l, back) ←
        betree.Node.lookup_first_message_for_key_loop key next_msgs
      let back1 :=
        fun ret => let next_msgs1 := back ret
                   betree.List.Cons x next_msgs1
      Result.ok (l, back1)
  | betree.List.Nil =>
    let back := fun ret => ret
    Result.ok (betree.List.Nil, back)

/- [betree::betree::{betree::betree::Node}#5::lookup_first_message_for_key]:
   Source: 'src/betree.rs', lines 792:4-810:5 -/
@[reducible]
def betree.Node.lookup_first_message_for_key
  (key : U64) (msgs : betree.List (U64 × betree.Message)) :
  Result ((betree.List (U64 × betree.Message)) × (betree.List (U64 ×
    betree.Message) → betree.List (U64 × betree.Message)))
  :=
  betree.Node.lookup_first_message_for_key_loop key msgs

/- [betree::betree::{betree::betree::Node}#5::apply_upserts]: loop 0:
   Source: 'src/betree.rs', lines 821:8-838:9 -/
divergent def betree.Node.apply_upserts_loop
  (msgs : betree.List (U64 × betree.Message)) (prev : Option U64) (key : U64)
  :
  Result (U64 × (betree.List (U64 × betree.Message)))
  :=
  do
  let b ← betree.ListPairU64T.head_has_key msgs key
  if b
  then
    do
    let (msg, msgs1) ← betree.List.pop_front msgs
    let (_, m) := msg
    match m with
    | betree.Message.Insert _ => Result.fail .panic
    | betree.Message.Delete => Result.fail .panic
    | betree.Message.Upsert s =>
      do
      let v ← betree.upsert_update prev s
      betree.Node.apply_upserts_loop msgs1 (some v) key
  else
    do
    let v ← core.option.Option.unwrap prev
    let msgs1 ← betree.List.push_front msgs (key, betree.Message.Insert v)
    Result.ok (v, msgs1)

/- [betree::betree::{betree::betree::Node}#5::apply_upserts]:
   Source: 'src/betree.rs', lines 820:4-844:5 -/
@[reducible]
def betree.Node.apply_upserts
  (msgs : betree.List (U64 × betree.Message)) (prev : Option U64) (key : U64)
  :
  Result (U64 × (betree.List (U64 × betree.Message)))
  :=
  betree.Node.apply_upserts_loop msgs prev key

/- [betree::betree::{betree::betree::Node}#5::lookup_in_bindings]: loop 0:
   Source: 'src/betree.rs', lines 650:8-660:5 -/
divergent def betree.Node.lookup_in_bindings_loop
  (key : U64) (bindings : betree.List (U64 × U64)) : Result (Option U64) :=
  match bindings with
  | betree.List.Cons hd tl =>
    let (i, i1) := hd
    if i = key
    then Result.ok (some i1)
    else
      if i > key
      then Result.ok none
      else betree.Node.lookup_in_bindings_loop key tl
  | betree.List.Nil => Result.ok none

/- [betree::betree::{betree::betree::Node}#5::lookup_in_bindings]:
   Source: 'src/betree.rs', lines 649:4-660:5 -/
@[reducible]
def betree.Node.lookup_in_bindings
  (key : U64) (bindings : betree.List (U64 × U64)) : Result (Option U64) :=
  betree.Node.lookup_in_bindings_loop key bindings

/- [betree::betree::{betree::betree::Internal}#4::lookup_in_children]:
   Source: 'src/betree.rs', lines 414:4-420:5 -/
mutual divergent def betree.Internal.lookup_in_children
  (self : betree.Internal) (key : U64) (st : State) :
  Result (State × ((Option U64) × betree.Internal))
  :=
  if key < self.pivot
  then
    do
    let (st1, (o, n)) ← betree.Node.lookup self.left key st
    Result.ok (st1, (o, betree.Internal.mk self.id self.pivot n self.right))
  else
    do
    let (st1, (o, n)) ← betree.Node.lookup self.right key st
    Result.ok (st1, (o, betree.Internal.mk self.id self.pivot self.left n))

/- [betree::betree::{betree::betree::Node}#5::lookup]:
   Source: 'src/betree.rs', lines 712:4-785:5 -/
divergent def betree.Node.lookup
  (self : betree.Node) (key : U64) (st : State) :
  Result (State × ((Option U64) × betree.Node))
  :=
  match self with
  | betree.Node.Internal node =>
    do
    let (st1, msgs) ← betree.load_internal_node node.id st
    let (pending, lookup_first_message_for_key_back) ←
      betree.Node.lookup_first_message_for_key key msgs
    match pending with
    | betree.List.Cons p _ =>
      let (k, msg) := p
      if k != key
      then
        do
        let (st2, (o, node1)) ←
          betree.Internal.lookup_in_children node key st1
        Result.ok (st2, (o, betree.Node.Internal node1))
      else
        match msg with
        | betree.Message.Insert v => Result.ok (st1, (some v, self))
        | betree.Message.Delete => Result.ok (st1, (none, self))
        | betree.Message.Upsert _ =>
          do
          let (st2, (v, node1)) ←
            betree.Internal.lookup_in_children node key st1
          let (v1, pending1) ← betree.Node.apply_upserts pending v key
          let msgs1 := lookup_first_message_for_key_back pending1
          let (st3, _) ← betree.store_internal_node node1.id msgs1 st2
          Result.ok (st3, (some v1, betree.Node.Internal node1))
    | betree.List.Nil =>
      do
      let (st2, (o, node1)) ← betree.Internal.lookup_in_children node key st1
      Result.ok (st2, (o, betree.Node.Internal node1))
  | betree.Node.Leaf node =>
    do
    let (st1, bindings) ← betree.load_leaf_node node.id st
    let o ← betree.Node.lookup_in_bindings key bindings
    Result.ok (st1, (o, self))

end

/- [betree::betree::{betree::betree::Node}#5::filter_messages_for_key]: loop 0:
   Source: 'src/betree.rs', lines 684:8-691:9 -/
divergent def betree.Node.filter_messages_for_key_loop
  (key : U64) (msgs : betree.List (U64 × betree.Message)) :
  Result (betree.List (U64 × betree.Message))
  :=
  match msgs with
  | betree.List.Cons p _ =>
    let (k, _) := p
    if k = key
    then
      do
      let (_, msgs1) ← betree.List.pop_front msgs
      betree.Node.filter_messages_for_key_loop key msgs1
    else Result.ok msgs
  | betree.List.Nil => Result.ok betree.List.Nil

/- [betree::betree::{betree::betree::Node}#5::filter_messages_for_key]:
   Source: 'src/betree.rs', lines 683:4-692:5 -/
@[reducible]
def betree.Node.filter_messages_for_key
  (key : U64) (msgs : betree.List (U64 × betree.Message)) :
  Result (betree.List (U64 × betree.Message))
  :=
  betree.Node.filter_messages_for_key_loop key msgs

/- [betree::betree::{betree::betree::Node}#5::lookup_first_message_after_key]: loop 0:
   Source: 'src/betree.rs', lines 698:8-704:9 -/
divergent def betree.Node.lookup_first_message_after_key_loop
  (key : U64) (msgs : betree.List (U64 × betree.Message)) :
  Result ((betree.List (U64 × betree.Message)) × (betree.List (U64 ×
    betree.Message) → betree.List (U64 × betree.Message)))
  :=
  match msgs with
  | betree.List.Cons p next_msgs =>
    let (k, _) := p
    if k = key
    then
      do
      let (l, back) ←
        betree.Node.lookup_first_message_after_key_loop key next_msgs
      let back1 :=
        fun ret => let next_msgs1 := back ret
                   betree.List.Cons p next_msgs1
      Result.ok (l, back1)
    else let back := fun ret => ret
         Result.ok (msgs, back)
  | betree.List.Nil =>
    let back := fun ret => ret
    Result.ok (betree.List.Nil, back)

/- [betree::betree::{betree::betree::Node}#5::lookup_first_message_after_key]:
   Source: 'src/betree.rs', lines 694:4-706:5 -/
@[reducible]
def betree.Node.lookup_first_message_after_key
  (key : U64) (msgs : betree.List (U64 × betree.Message)) :
  Result ((betree.List (U64 × betree.Message)) × (betree.List (U64 ×
    betree.Message) → betree.List (U64 × betree.Message)))
  :=
  betree.Node.lookup_first_message_after_key_loop key msgs

/- [betree::betree::{betree::betree::Node}#5::apply_to_internal]:
   Source: 'src/betree.rs', lines 534:4-586:5 -/
def betree.Node.apply_to_internal
  (msgs : betree.List (U64 × betree.Message)) (key : U64)
  (new_msg : betree.Message) :
  Result (betree.List (U64 × betree.Message))
  :=
  do
  let (msgs1, lookup_first_message_for_key_back) ←
    betree.Node.lookup_first_message_for_key key msgs
  let b ← betree.ListPairU64T.head_has_key msgs1 key
  if b
  then
    match new_msg with
    | betree.Message.Insert _ =>
      do
      let msgs2 ← betree.Node.filter_messages_for_key key msgs1
      let msgs3 ← betree.List.push_front msgs2 (key, new_msg)
      Result.ok (lookup_first_message_for_key_back msgs3)
    | betree.Message.Delete =>
      do
      let msgs2 ← betree.Node.filter_messages_for_key key msgs1
      let msgs3 ← betree.List.push_front msgs2 (key, betree.Message.Delete)
      Result.ok (lookup_first_message_for_key_back msgs3)
    | betree.Message.Upsert s =>
      do
      let p ← betree.List.hd msgs1
      let (_, m) := p
      match m with
      | betree.Message.Insert prev =>
        do
        let v ← betree.upsert_update (some prev) s
        let (_, msgs2) ← betree.List.pop_front msgs1
        let msgs3 ←
          betree.List.push_front msgs2 (key, betree.Message.Insert v)
        Result.ok (lookup_first_message_for_key_back msgs3)
      | betree.Message.Delete =>
        do
        let (_, msgs2) ← betree.List.pop_front msgs1
        let v ← betree.upsert_update none s
        let msgs3 ←
          betree.List.push_front msgs2 (key, betree.Message.Insert v)
        Result.ok (lookup_first_message_for_key_back msgs3)
      | betree.Message.Upsert _ =>
        do
        let (msgs2, lookup_first_message_after_key_back) ←
          betree.Node.lookup_first_message_after_key key msgs1
        let msgs3 ← betree.List.push_front msgs2 (key, new_msg)
        let msgs4 := lookup_first_message_after_key_back msgs3
        Result.ok (lookup_first_message_for_key_back msgs4)
  else
    do
    let msgs2 ← betree.List.push_front msgs1 (key, new_msg)
    Result.ok (lookup_first_message_for_key_back msgs2)

/- [betree::betree::{betree::betree::Node}#5::apply_messages_to_internal]: loop 0:
   Source: 'src/betree.rs', lines 522:8-525:9 -/
divergent def betree.Node.apply_messages_to_internal_loop
  (msgs : betree.List (U64 × betree.Message))
  (new_msgs : betree.List (U64 × betree.Message)) :
  Result (betree.List (U64 × betree.Message))
  :=
  match new_msgs with
  | betree.List.Cons new_msg new_msgs_tl =>
    do
    let (i, m) := new_msg
    let msgs1 ← betree.Node.apply_to_internal msgs i m
    betree.Node.apply_messages_to_internal_loop msgs1 new_msgs_tl
  | betree.List.Nil => Result.ok msgs

/- [betree::betree::{betree::betree::Node}#5::apply_messages_to_internal]:
   Source: 'src/betree.rs', lines 518:4-526:5 -/
@[reducible]
def betree.Node.apply_messages_to_internal
  (msgs : betree.List (U64 × betree.Message))
  (new_msgs : betree.List (U64 × betree.Message)) :
  Result (betree.List (U64 × betree.Message))
  :=
  betree.Node.apply_messages_to_internal_loop msgs new_msgs

/- [betree::betree::{betree::betree::Node}#5::lookup_mut_in_bindings]: loop 0:
   Source: 'src/betree.rs', lines 668:8-675:9 -/
divergent def betree.Node.lookup_mut_in_bindings_loop
  (key : U64) (bindings : betree.List (U64 × U64)) :
  Result ((betree.List (U64 × U64)) × (betree.List (U64 × U64) →
    betree.List (U64 × U64)))
  :=
  match bindings with
  | betree.List.Cons hd tl =>
    let (i, _) := hd
    if i >= key
    then let back := fun ret => ret
         Result.ok (bindings, back)
    else
      do
      let (l, back) ← betree.Node.lookup_mut_in_bindings_loop key tl
      let back1 := fun ret => let tl1 := back ret
                              betree.List.Cons hd tl1
      Result.ok (l, back1)
  | betree.List.Nil =>
    let back := fun ret => ret
    Result.ok (betree.List.Nil, back)

/- [betree::betree::{betree::betree::Node}#5::lookup_mut_in_bindings]:
   Source: 'src/betree.rs', lines 664:4-677:5 -/
@[reducible]
def betree.Node.lookup_mut_in_bindings
  (key : U64) (bindings : betree.List (U64 × U64)) :
  Result ((betree.List (U64 × U64)) × (betree.List (U64 × U64) →
    betree.List (U64 × U64)))
  :=
  betree.Node.lookup_mut_in_bindings_loop key bindings

/- [betree::betree::{betree::betree::Node}#5::apply_to_leaf]:
   Source: 'src/betree.rs', lines 476:4-515:5 -/
def betree.Node.apply_to_leaf
  (bindings : betree.List (U64 × U64)) (key : U64) (new_msg : betree.Message)
  :
  Result (betree.List (U64 × U64))
  :=
  do
  let (bindings1, lookup_mut_in_bindings_back) ←
    betree.Node.lookup_mut_in_bindings key bindings
  let b ← betree.ListPairU64T.head_has_key bindings1 key
  if b
  then
    do
    let (hd, bindings2) ← betree.List.pop_front bindings1
    match new_msg with
    | betree.Message.Insert v =>
      do
      let bindings3 ← betree.List.push_front bindings2 (key, v)
      Result.ok (lookup_mut_in_bindings_back bindings3)
    | betree.Message.Delete =>
      Result.ok (lookup_mut_in_bindings_back bindings2)
    | betree.Message.Upsert s =>
      do
      let (_, i) := hd
      let v ← betree.upsert_update (some i) s
      let bindings3 ← betree.List.push_front bindings2 (key, v)
      Result.ok (lookup_mut_in_bindings_back bindings3)
  else
    match new_msg with
    | betree.Message.Insert v =>
      do
      let bindings2 ← betree.List.push_front bindings1 (key, v)
      Result.ok (lookup_mut_in_bindings_back bindings2)
    | betree.Message.Delete =>
      Result.ok (lookup_mut_in_bindings_back bindings1)
    | betree.Message.Upsert s =>
      do
      let v ← betree.upsert_update none s
      let bindings2 ← betree.List.push_front bindings1 (key, v)
      Result.ok (lookup_mut_in_bindings_back bindings2)

/- [betree::betree::{betree::betree::Node}#5::apply_messages_to_leaf]: loop 0:
   Source: 'src/betree.rs', lines 467:8-470:9 -/
divergent def betree.Node.apply_messages_to_leaf_loop
  (bindings : betree.List (U64 × U64))
  (new_msgs : betree.List (U64 × betree.Message)) :
  Result (betree.List (U64 × U64))
  :=
  match new_msgs with
  | betree.List.Cons new_msg new_msgs_tl =>
    do
    let (i, m) := new_msg
    let bindings1 ← betree.Node.apply_to_leaf bindings i m
    betree.Node.apply_messages_to_leaf_loop bindings1 new_msgs_tl
  | betree.List.Nil => Result.ok bindings

/- [betree::betree::{betree::betree::Node}#5::apply_messages_to_leaf]:
   Source: 'src/betree.rs', lines 463:4-471:5 -/
@[reducible]
def betree.Node.apply_messages_to_leaf
  (bindings : betree.List (U64 × U64))
  (new_msgs : betree.List (U64 × betree.Message)) :
  Result (betree.List (U64 × U64))
  :=
  betree.Node.apply_messages_to_leaf_loop bindings new_msgs

/- [betree::betree::{betree::betree::Internal}#4::flush]:
   Source: 'src/betree.rs', lines 429:4-458:5 -/
mutual divergent def betree.Internal.flush
  (self : betree.Internal) (params : betree.Params)
  (node_id_cnt : betree.NodeIdCounter)
  (content : betree.List (U64 × betree.Message)) (st : State) :
  Result (State × ((betree.List (U64 × betree.Message)) × (betree.Internal
    × betree.NodeIdCounter)))
  :=
  do
  let p ← betree.ListPairU64T.partition_at_pivot content self.pivot
  let (msgs_left, msgs_right) := p
  let len_left ← betree.List.len msgs_left
  if len_left >= params.min_flush_size
  then
    do
    let (st1, p1) ←
      betree.Node.apply_messages self.left params node_id_cnt msgs_left st
    let (n, node_id_cnt1) := p1
    let len_right ← betree.List.len msgs_right
    if len_right >= params.min_flush_size
    then
      do
      let (st2, p2) ←
        betree.Node.apply_messages self.right params node_id_cnt1 msgs_right
          st1
      let (n1, node_id_cnt2) := p2
      Result.ok (st2, (betree.List.Nil, (betree.Internal.mk self.id self.pivot
        n n1, node_id_cnt2)))
    else
      Result.ok (st1, (msgs_right, (betree.Internal.mk self.id self.pivot n
        self.right, node_id_cnt1)))
  else
    do
    let (st1, p1) ←
      betree.Node.apply_messages self.right params node_id_cnt msgs_right st
    let (n, node_id_cnt1) := p1
    Result.ok (st1, (msgs_left, (betree.Internal.mk self.id self.pivot
      self.left n, node_id_cnt1)))

/- [betree::betree::{betree::betree::Node}#5::apply_messages]:
   Source: 'src/betree.rs', lines 601:4-645:5 -/
divergent def betree.Node.apply_messages
  (self : betree.Node) (params : betree.Params)
  (node_id_cnt : betree.NodeIdCounter)
  (msgs : betree.List (U64 × betree.Message)) (st : State) :
  Result (State × (betree.Node × betree.NodeIdCounter))
  :=
  match self with
  | betree.Node.Internal node =>
    do
    let (st1, content) ← betree.load_internal_node node.id st
    let content1 ← betree.Node.apply_messages_to_internal content msgs
    let num_msgs ← betree.List.len content1
    if num_msgs >= params.min_flush_size
    then
      do
      let (st2, (content2, p)) ←
        betree.Internal.flush node params node_id_cnt content1 st1
      let (node1, node_id_cnt1) := p
      let (st3, _) ← betree.store_internal_node node1.id content2 st2
      Result.ok (st3, (betree.Node.Internal node1, node_id_cnt1))
    else
      do
      let (st2, _) ← betree.store_internal_node node.id content1 st1
      Result.ok (st2, (self, node_id_cnt))
  | betree.Node.Leaf node =>
    do
    let (st1, content) ← betree.load_leaf_node node.id st
    let content1 ← betree.Node.apply_messages_to_leaf content msgs
    let len ← betree.List.len content1
    let i ← 2#u64 * params.split_size
    if len >= i
    then
      do
      let (st2, (new_node, node_id_cnt1)) ←
        betree.Leaf.split node content1 params node_id_cnt st1
      let (st3, _) ← betree.store_leaf_node node.id betree.List.Nil st2
      Result.ok (st3, (betree.Node.Internal new_node, node_id_cnt1))
    else
      do
      let (st2, _) ← betree.store_leaf_node node.id content1 st1
      Result.ok (st2, (betree.Node.Leaf { node with size := len },
        node_id_cnt))

end

/- [betree::betree::{betree::betree::Node}#5::apply]:
   Source: 'src/betree.rs', lines 589:4-598:5 -/
def betree.Node.apply
  (self : betree.Node) (params : betree.Params)
  (node_id_cnt : betree.NodeIdCounter) (key : U64) (new_msg : betree.Message)
  (st : State) :
  Result (State × (betree.Node × betree.NodeIdCounter))
  :=
  betree.Node.apply_messages self params node_id_cnt (betree.List.Cons (key,
    new_msg) betree.List.Nil) st

/- [betree::betree::{betree::betree::BeTree}#6::new]:
   Source: 'src/betree.rs', lines 848:4-862:5 -/
def betree.BeTree.new
  (min_flush_size : U64) (split_size : U64) (st : State) :
  Result (State × betree.BeTree)
  :=
  do
  let node_id_cnt ← betree.NodeIdCounter.new
  let (id, node_id_cnt1) ← betree.NodeIdCounter.fresh_id node_id_cnt
  let (st1, _) ← betree.store_leaf_node id betree.List.Nil st
  Result.ok (st1,
    {
      params := { min_flush_size, split_size },
      node_id_cnt := node_id_cnt1,
      root := (betree.Node.Leaf { id, size := 0#u64 })
    })

/- [betree::betree::{betree::betree::BeTree}#6::apply]:
   Source: 'src/betree.rs', lines 867:4-870:5 -/
def betree.BeTree.apply
  (self : betree.BeTree) (key : U64) (msg : betree.Message) (st : State) :
  Result (State × betree.BeTree)
  :=
  do
  let (st1, p) ←
    betree.Node.apply self.root self.params self.node_id_cnt key msg st
  let (n, nic) := p
  Result.ok (st1, { self with node_id_cnt := nic, root := n })

/- [betree::betree::{betree::betree::BeTree}#6::insert]:
   Source: 'src/betree.rs', lines 873:4-876:5 -/
def betree.BeTree.insert
  (self : betree.BeTree) (key : U64) (value : U64) (st : State) :
  Result (State × betree.BeTree)
  :=
  betree.BeTree.apply self key (betree.Message.Insert value) st

/- [betree::betree::{betree::betree::BeTree}#6::delete]:
   Source: 'src/betree.rs', lines 879:4-882:5 -/
def betree.BeTree.delete
  (self : betree.BeTree) (key : U64) (st : State) :
  Result (State × betree.BeTree)
  :=
  betree.BeTree.apply self key betree.Message.Delete st

/- [betree::betree::{betree::betree::BeTree}#6::upsert]:
   Source: 'src/betree.rs', lines 885:4-888:5 -/
def betree.BeTree.upsert
  (self : betree.BeTree) (key : U64) (upd : betree.UpsertFunState) (st : State)
  :
  Result (State × betree.BeTree)
  :=
  betree.BeTree.apply self key (betree.Message.Upsert upd) st

/- [betree::betree::{betree::betree::BeTree}#6::lookup]:
   Source: 'src/betree.rs', lines 894:4-896:5 -/
def betree.BeTree.lookup
  (self : betree.BeTree) (key : U64) (st : State) :
  Result (State × ((Option U64) × betree.BeTree))
  :=
  do
  let (st1, (o, n)) ← betree.Node.lookup self.root key st
  Result.ok (st1, (o, { self with root := n }))

/- [betree::main]:
   Source: 'src/main.rs', lines 4:0-4:12 -/
def main : Result Unit :=
  Result.ok ()

/- Unit test for [betree::main] -/
#assert (main == Result.ok ())

end betree
