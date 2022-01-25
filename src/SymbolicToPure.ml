open Errors
module Id = Identifiers
module T = Types
module V = Values
module E = Expressions
module A = CfimAst
module M = Modules
module S = SymbolicAst
module TA = TypesAnalysis
open Pure

(** TODO: move this, it is not useful for symbolic -> pure *)
type name =
  | FunName of A.FunDefId.id * V.BackwardFunctionId.id option
  | TypeName of T.TypeDefId.id
[@@deriving show, ord]

let name_to_string (n : name) : string = show_name n

module NameOrderedType = struct
  type t = name

  let compare = compare_name

  let to_string = name_to_string

  let pp_t = pp_name

  let show_t = show_name
end

module NameMap = Collections.MakeMapInj (NameOrderedType) (Id.NameOrderedType)
(** Notice that we use the *injective* map to map identifiers to names.

    Of course, even if those names (which are string lists) don't collide,
    when converting them to strings we can still introduce collisions: we
    check that later.
    
    Note that we use injective maps for sanity: though we write the name
    generation with collision in mind, it is always good to have such checks.
 *)

let translate_fun_name (fdef : A.fun_def) (bid : V.BackwardFunctionId.id option)
    : Id.name =
  let sg = fdef.signature in
  (* General function to generate a suffix for a region group
   * (i.e., an abstraction)*)
  let rg_to_string (rg : T.region_var_group) : string =
    (* We are just a little bit smart:
       - if there is exactly one region id in the region group and this region
         has a name, we use this name
       - otherwise, we use the region number (note that region names shouldn't
         start with numbers)
    *)
    match rg.T.regions with
    | [ rid ] -> (
        let rvar = T.RegionVarId.nth sg.region_params rid in
        match rvar.name with
        | None -> T.RegionGroupId.to_string rg.T.id
        | Some name -> name)
    | _ -> T.RegionGroupId.to_string rg.T.id
  in
  (* There are several cases:
     - this is a forward function: we add "_fwd"
     - this is a backward function:
       - this function has one backward function: we add "_back"
       - this function has several backward function: we add "_back" and an
         additional suffix to identify the precise backward function
  *)
  let suffix =
    match bid with
    | None -> "_fwd"
    | Some bid -> (
        match sg.regions_hierarchy with
        | [] ->
            failwith "Unreachable"
            (* we can't get there if we ask for a back function *)
        | [ _ ] ->
            (* Exactly one backward function *)
            "_back"
        | _ ->
            (* Several backward functions - note that **we use the backward function id
             * as if it were a region group id** (there is a direct mapping between the
             * two - TODO: merge them) *)
            let rg = V.BackwardFunctionId.nth sg.regions_hierarchy bid in
            "_back" ^ rg_to_string rg)
  in
  (* Final name *)
  let rec add_to_last (n : Id.name) : Id.name =
    match n with
    | [] -> failwith "Unreachable"
    | [ x ] -> [ x ^ suffix ]
    | x :: n -> x :: add_to_last n
  in
  add_to_last fdef.name

(** Generates a name for a type (simply reuses the name in the definition) *)
let translate_type_name (def : T.type_def) : Id.name = def.T.name

type type_context = { type_defs : type_def TypeDefId.Map.t }

type fun_context = { fun_defs : fun_def FunDefId.Map.t }

(* TODO: do we really need that actually? *)
type synth_ctx = {
  names : NameMap.t;
  (* TODO: remove? *)
  type_context : type_context;
  fun_context : fun_context;
  declarations : M.declaration_group list;
}

type bs_ctx = { types_infos : TA.type_infos }
(** Body synthesis context *)

let rec translate_sty (ty : T.sty) : ty =
  let translate = translate_sty in
  match ty with
  | T.Adt (type_id, regions, tys) ->
      (* Can't translate types with regions for now *)
      assert (regions = []);
      let tys = List.map translate tys in
      Adt (type_id, tys)
  | TypeVar vid -> TypeVar vid
  | Bool -> Bool
  | Char -> Char
  | Never -> failwith "Unreachable"
  | Integer int_ty -> Integer int_ty
  | Str -> Str
  | Array ty -> Array (translate ty)
  | Slice ty -> Slice (translate ty)
  | Ref (_, rty, _) -> translate rty

let translate_field (f : T.field) : field =
  let field_name = f.field_name in
  let field_ty = translate_sty f.field_ty in
  { field_name; field_ty }

let translate_fields (fl : T.field list) : field list =
  List.map translate_field fl

let translate_variant (v : T.variant) : variant =
  let variant_name = v.variant_name in
  let fields = translate_fields v.fields in
  { variant_name; fields }

let translate_variants (vl : T.variant list) : variant list =
  List.map translate_variant vl

(** Translate a type def kind to IM *)
let translate_type_def_kind (kind : T.type_def_kind) : type_def_kind =
  match kind with
  | T.Struct fields -> Struct (translate_fields fields)
  | T.Enum variants -> Enum (translate_variants variants)

(** Translate a type definition from IM 

    TODO: this is not symbolic to pure but IM to pure. Still, I don't see the
    point of moving this definition for now.
 *)
let translate_type_def (def : T.type_def) : type_def =
  (* Translate *)
  let def_id = def.T.def_id in
  let name = translate_type_name def in
  (* Can't translate types with regions for now *)
  assert (def.region_params = []);
  let type_params = def.type_params in
  let kind = translate_type_def_kind def.T.kind in
  { def_id; name; type_params; kind }

(** Translate a type, seen as an input/output of a forward function
    (preserve all borrows, etc.)
*)

let rec translate_fwd_ty (ctx : bs_ctx) (ty : 'r T.ty) : ty =
  let translate = translate_fwd_ty ctx in
  match ty with
  | T.Adt (type_id, regions, tys) ->
      (* Can't translate types with regions for now *)
      assert (regions = []);
      (* No general parametricity for now *)
      assert (not (List.exists (TypesUtils.ty_has_borrows ctx.types_infos) tys));
      (* Translate the type parameters *)
      let tys = List.map translate tys in
      Adt (type_id, tys)
  | TypeVar vid -> TypeVar vid
  | Bool -> Bool
  | Char -> Char
  | Never -> failwith "Unreachable"
  | Integer int_ty -> Integer int_ty
  | Str -> Str
  | Array ty ->
      assert (not (TypesUtils.ty_has_borrows ctx.types_infos ty));
      Array (translate ty)
  | Slice ty ->
      assert (not (TypesUtils.ty_has_borrows ctx.types_infos ty));
      Slice (translate ty)
  | Ref (_, rty, _) -> translate rty

(** Translate a type, when some regions may have ended.
    
    We return an option, because the translated type may be empty.
    
    [inside_mut]: are we inside a mutable borrow?
 *)
let rec translate_back_ty (ctx : bs_ctx) (keep_region : 'r -> bool)
    (inside_mut : bool) (ty : 'r T.ty) : ty option =
  let translate = translate_back_ty ctx keep_region inside_mut in
  (* A small helper for "leave" types *)
  let wrap ty = if inside_mut then Some ty else None in
  match ty with
  | T.Adt (type_id, regions, tys) -> (
      match type_id with
      | T.AdtId _ | Assumed _ ->
          (* Don't accept ADTs (which are not tuples) with borrows for now *)
          assert (not (TypesUtils.ty_has_borrows ctx.types_infos ty));
          None
      | T.Tuple -> (
          (* Tuples can contain borrows (which we eliminated) *)
          let tys_t = List.filter_map translate tys in
          match tys_t with [] -> None | _ -> Some (Adt (T.Tuple, tys_t))))
  | TypeVar vid -> wrap (TypeVar vid)
  | Bool -> wrap Bool
  | Char -> wrap Char
  | Never -> failwith "Unreachable"
  | Integer int_ty -> wrap (Integer int_ty)
  | Str -> wrap Str
  | Array ty -> (
      assert (not (TypesUtils.ty_has_borrows ctx.types_infos ty));
      match translate ty with None -> None | Some ty -> Some (Array ty))
  | Slice ty -> (
      assert (not (TypesUtils.ty_has_borrows ctx.types_infos ty));
      match translate ty with None -> None | Some ty -> Some (Slice ty))
  | Ref (r, rty, rkind) -> (
      match rkind with
      | T.Shared ->
          (* Ignore shared references, unless we are below a mutable borrow *)
          if inside_mut then translate rty else None
      | T.Mut ->
          (* Dive in, remembering the fact that we are inside a mutable borrow *)
          let inside_mut = true in
          if keep_region r then translate_back_ty ctx keep_region inside_mut rty
          else None)

(** Small utility: list the transitive parents of a region var group.
    We don't do that in an efficient manner, but it doesn't matter.
 *)
let rec list_parent_region_groups (def : A.fun_def) (gid : T.RegionGroupId.id) :
    T.RegionGroupId.Set.t =
  let rg = T.RegionGroupId.nth def.signature.regions_hierarchy gid in
  let parents =
    List.fold_left
      (fun s gid ->
        (* Compute the parents *)
        let parents = list_parent_region_groups def gid in
        (* Parents U current region *)
        let parents = T.RegionGroupId.Set.add gid parents in
        (* Make the union with the accumulator *)
        T.RegionGroupId.Set.union s parents)
      T.RegionGroupId.Set.empty rg.parents
  in
  parents

let translate_fun_sig (ctx : bs_ctx) (def : A.fun_def)
    (bid : V.BackwardFunctionId.id option) : fun_sig =
  let sg = def.signature in
  (* Retrieve the list of parent backward functions *)
  let gid, parents =
    match bid with
    | None -> (None, T.RegionGroupId.Set.empty)
    | Some bid ->
        let gid = T.RegionGroupId.of_int (V.BackwardFunctionId.to_int bid) in
        let parents = list_parent_region_groups def gid in
        (Some gid, parents)
  in
  (* List the inputs for:
   * - the forward function
   * - the parent backward functions, in proper order
   * - the current backward function (if it is a backward function)
   *)
  let fwd_inputs = List.map (translate_fwd_ty ctx) sg.inputs in
  (* For the backward functions: for now we don't supported nested borrows,
   * so just check that there aren't parent regions *)
  assert (T.RegionGroupId.Set.is_empty parents);
  (* Small helper to translate types for backward functions *)
  let translate_back_ty_for_gid (gid : T.RegionGroupId.id) : T.sty -> ty option
      =
    let rg = T.RegionGroupId.nth sg.regions_hierarchy gid in
    let regions = T.RegionVarId.Set.of_list rg.regions in
    let keep_region r =
      match r with
      | T.Static -> raise Unimplemented
      | T.Var r -> T.RegionVarId.Set.mem r regions
    in
    let inside_mut = false in
    translate_back_ty ctx keep_region inside_mut
  in
  (* Compute the additinal inputs for the current function, if it is a backward
   * function *)
  let back_inputs =
    match gid with
    | None -> []
    | Some gid ->
        (* For now, we don't allow nested borrows, so the additional inputs to the
         * backward function can only come from borrows that were returned like
         * in (for the backward function we introduce for 'a):
         * ```
         * fn f<'a>(...) -> &'a mut u32;
         * ```
         * Upon ending the abstraction for 'a, we need to get back the borrow
         * the function returned.
         *)
        List.filter_map (translate_back_ty_for_gid gid) [ sg.output ]
  in
  let inputs = List.append fwd_inputs back_inputs in
  (* Outputs *)
  let outputs : ty list =
    match gid with
    | None ->
        (* This is a forward function: there is one output *)
        [ translate_fwd_ty ctx sg.output ]
    | Some gid ->
        (* This is a backward function: there might be several outputs.
         * The outputs are the borrows inside the regions of the abstractions
         * and which are present in the input values. For instance, see:
         * ```
         * fn f<'a>(x : 'a mut u32) -> ...;
         * ```
         * Upon ending the abstraction for 'a, we give back the borrow which
         * was consumed through the `x` parameter.
         *)
        List.filter_map (translate_back_ty_for_gid gid) sg.inputs
  in
  (* Type parameters *)
  let type_params = sg.type_params in
  (* Return *)
  { type_params; inputs; outputs }

let translate_typed_value (v : V.typed_value) (ctx : bs_ctx) :
    bs_ctx * typed_value =
  raise Unimplemented

let rec translate_expression (def : A.fun_def)
    (bid : V.BackwardFunctionId.id option) (body : S.expression) (ctx : bs_ctx)
    : expression =
  match body with
  | S.Return v ->
      let _, v = translate_typed_value v ctx in
      Return (Value v)
  | Panic -> Panic
  | FunCall (call, e) -> raise Unimplemented
  | EndAbstraction (abs, e) -> raise Unimplemented
  | Expansion (sv, exp) -> raise Unimplemented
  | Meta (_, e) ->
      (* We ignore the meta information *)
      translate_expression def bid e ctx

let translate_fun_def (types_infos : TA.type_infos) (def : A.fun_def)
    (bid : V.BackwardFunctionId.id option) (body : S.expression) : fun_def =
  let bs_ctx = { types_infos } in
  (* Translate the function *)
  let def_id = def.A.def_id in
  let name = translate_fun_name def bid in
  let signature = translate_fun_sig bs_ctx def bid in
  let body = translate_expression def bid body bs_ctx in
  { def_id; name; signature; body }
