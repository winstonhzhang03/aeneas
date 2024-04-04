-- THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS
-- [betree_main]: external functions.
-- This is a template file: rename it to "FunsExternal.lean" and fill the holes.
import Base
import BetreeMain.Types
open Primitives
open betree_main

/- [betree_main::betree_utils::load_internal_node]:
   Source: 'src/betree_utils.rs', lines 98:0-98:63 -/
axiom betree_utils.load_internal_node
  : U64 → State → Result (State × (betree.List (U64 × betree.Message)))

/- [betree_main::betree_utils::store_internal_node]:
   Source: 'src/betree_utils.rs', lines 115:0-115:71 -/
axiom betree_utils.store_internal_node
  :
  U64 → betree.List (U64 × betree.Message) → State → Result (State ×
    Unit)

/- [betree_main::betree_utils::load_leaf_node]:
   Source: 'src/betree_utils.rs', lines 132:0-132:55 -/
axiom betree_utils.load_leaf_node
  : U64 → State → Result (State × (betree.List (U64 × U64)))

/- [betree_main::betree_utils::store_leaf_node]:
   Source: 'src/betree_utils.rs', lines 145:0-145:63 -/
axiom betree_utils.store_leaf_node
  : U64 → betree.List (U64 × U64) → State → Result (State × Unit)

/- [core::option::{core::option::Option<T>}::unwrap]:
   Source: '/rustc/d59363ad0b6391b7fc5bbb02c9ccf9300eef3753/library/core/src/option.rs', lines 932:4-932:34
   Name pattern: core::option::{core::option::Option<@T>}::unwrap -/
axiom core.option.Option.unwrap
  (T : Type) : Option T → State → Result (State × T)

