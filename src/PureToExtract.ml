(** This module is used to extract the pure ASTs to various theorem provers.
    It defines utilities and helpers to make the work as easy as possible:
    we try to factorize as much as possible the different extractions to the
    backends we target.
 *)

open Errors
open Pure
open TranslateCore
module C = Contexts
module RegionVarId = T.RegionVarId
module F = Format

(** The local logger *)
let log = L.pure_to_extract_log

type region_group_info = {
  id : RegionGroupId.id;
      (** The id of the region group.
          Note that a simple way of generating unique names for backward
          functions is to use the region group ids.
       *)
  region_names : string option list;
      (** The names of the region variables included in this group.
          Note that names are not always available...
       *)
}

module StringSet = Collections.MakeSet (Collections.OrderedString)
module StringMap = Collections.MakeMap (Collections.OrderedString)

type name = Identifiers.name

type 'ctx g_formatter = {
  bool_name : string;
  char_name : string;
  int_name : integer_type -> string;
  str_name : string;
  field_name : name -> FieldId.id -> string option -> string;
      (** Inputs:
          - type name
          - field id
          - field name
          
          Note that fields don't always have names, but we still need to
          generate some names if we want to extract the structures to records...
          We might want to extract such structures to tuples, later, but field
          access then causes trouble because not all provers accept syntax like
          `x.3` where `x` is a tuple.
       *)
  variant_name : name -> string -> string;
      (** Inputs:
          - type name
          - variant name
       *)
  struct_constructor : name -> string;
      (** Structure constructors are used when constructing structure values.
      
          For instance, in F*:
          ```
          type pair = { x : nat; y : nat }
          let p : pair = Mkpair 0 1
          ```
          
          Inputs:
          - type name
       *)
  type_name : name -> string;  (** Provided a basename, compute a type name. *)
  fun_name : A.fun_id -> name -> int -> region_group_info option -> string;
      (** Inputs:
          - function id: this is especially useful to identify whether the
            function is an assumed function or a local function
          - function basename
          - number of region groups
          - region group information in case of a backward function
            (`None` if forward function)
       *)
  var_basename : StringSet.t -> string option -> ty -> string;
      (** Generates a variable basename.
      
          Inputs:
          - the set of names used in the context so far
          - the basename we got from the symbolic execution, if we have one
          - the type of the variable (can be useful for heuristics, in order
            not to always use "x" for instance, whenever naming anonymous
            variables)

          Note that once the formatter generated a basename, we add an index
          if necessary to prevent name clashes: the burden of name clashes checks
          is thus on the caller's side.
       *)
  type_var_basename : StringSet.t -> string -> string;
      (** Generates a type variable basename. *)
  append_index : string -> int -> string;
      (** Appends an index to a name - we use this to generate unique
          names: when doing so, the role of the formatter is just to concatenate
          indices to names, the responsability of finding a proper index is
          delegated to helper functions.
       *)
  extract_constant_value : F.formatter -> bool -> constant_value -> unit;
      (** Format a constant value.
      
          Inputs:
          - formatter
          - [inside]: if `true`, the value should be wrapped in parentheses
            if it is made of an application (ex.: `U32 3`)
       *)
  extract_unop :
    'ctx ->
    F.formatter ->
    ('ctx -> F.formatter -> bool -> texpression -> 'ctx) ->
    bool ->
    unop ->
    texpression ->
    'ctx;
      (** Format a unary operation
      
          Inputs:
          - extraction context (see below)
          - formatter
          - expression formatter
          - [inside]
          - unop
          - argument
       *)
  extract_binop :
    'ctx ->
    F.formatter ->
    ('ctx -> F.formatter -> bool -> texpression -> 'ctx) ->
    bool ->
    E.binop ->
    integer_type ->
    texpression ->
    texpression ->
    'ctx;
      (** Format a binary operation
      
          Inputs:
          - extraction context (see below)
          - formatter
          - expression formatter
          - [inside]
          - binop
          - argument 0
          - argument 1
       *)
}
(** A formatter's role is twofold:
    1. Come up with name suggestions.
    For instance, provided some information about a function (its basename,
    information about the region group, etc.) it should come up with an
    appropriate name for the forward/backward function.
    
    It can of course apply many transformations, like changing to camel case/
    snake case, adding prefixes/suffixes, etc.
    
    2. Format some specific terms, like constants.
 *)

(** We use identifiers to look for name clashes *)
type id =
  | FunId of A.fun_id * RegionGroupId.id option
  | TypeId of type_id
  | StructId of type_id
      (** We use this when we manipulate the names of the structure
          constructors.
          
          For instance, in F*:
          ```
          type pair = { x: nat; y : nat }
          let p : pair = Mkpair 0 1
          ```
       *)
  | VariantId of type_id * VariantId.id
      (** If often happens that variant names must be unique (it is the case in
          F* ) which is why we register them here.
       *)
  | FieldId of type_id * FieldId.id
      (** If often happens that in the case of structures, the field names
          must be unique (it is the case in F* ) which is why we register
          them here.
       *)
  | TypeVarId of TypeVarId.id
  | VarId of VarId.id
  | UnknownId
      (** Used for stored various strings like keywords, definitions which
          should always be in context, etc. and which can't be linked to one
          of the above.
       *)
[@@deriving show, ord]

module IdOrderedType = struct
  type t = id

  let compare = compare_id

  let to_string = show_id

  let pp_t = pp_id

  let show_t = show_id
end

module IdMap = Collections.MakeMap (IdOrderedType)

type names_map = {
  id_to_name : string IdMap.t;
  name_to_id : id StringMap.t;
      (** The name to id map is used to look for name clashes, and generate nice
          debugging messages: if there is a name clash, it is useful to know
          precisely which identifiers are mapped to the same name...
       *)
  names_set : StringSet.t;
}
(** The names map stores the mappings from names to identifiers and vice-versa.

      We use it for lookups (during the translation) and to check for name clashes.
  *)

let names_map_add (id : id) (name : string) (nm : names_map) : names_map =
  (* Sanity check: no clashes *)
  assert (not (StringSet.mem name nm.names_set));
  (* Insert *)
  let id_to_name = IdMap.add id name nm.id_to_name in
  let name_to_id = StringMap.add name id nm.name_to_id in
  let names_set = StringSet.add name nm.names_set in
  { id_to_name; name_to_id; names_set }

let names_map_add_assumed_type (id : assumed_ty) (name : string)
    (nm : names_map) : names_map =
  names_map_add (TypeId (Assumed id)) name nm

let names_map_add_assumed_struct (id : assumed_ty) (name : string)
    (nm : names_map) : names_map =
  names_map_add (StructId (Assumed id)) name nm

let names_map_add_assumed_variant (id : assumed_ty) (variant_id : VariantId.id)
    (name : string) (nm : names_map) : names_map =
  names_map_add (VariantId (Assumed id, variant_id)) name nm

let names_map_add_assumed_function (fid : A.assumed_fun_id)
    (rg_id : RegionGroupId.id option) (name : string) (nm : names_map) :
    names_map =
  names_map_add (FunId (A.Assumed fid, rg_id)) name nm

(* TODO: remove those functions? We use the ones of extraction_ctx *)
let names_map_get (id : id) (nm : names_map) : string =
  IdMap.find id nm.id_to_name

let names_map_get_function (id : A.fun_id) (rg : RegionGroupId.id option)
    (nm : names_map) : string =
  names_map_get (FunId (id, rg)) nm

let names_map_get_local_function (id : FunDefId.id)
    (rg : RegionGroupId.id option) (nm : names_map) : string =
  names_map_get_function (A.Local id) rg nm

let names_map_get_type (id : type_id) (nm : names_map) : string =
  assert (id <> Tuple);
  names_map_get (TypeId id) nm

let names_map_get_local_type (id : TypeDefId.id) (nm : names_map) : string =
  names_map_get_type (AdtId id) nm

let names_map_get_var (id : VarId.id) (nm : names_map) : string =
  names_map_get (VarId id) nm

let names_map_get_type_var (id : TypeVarId.id) (nm : names_map) : string =
  names_map_get (TypeVarId id) nm

(** Make a (variable) basename unique (by adding an index).

    We do this in an inefficient manner (by testing all indices starting from
    0) but it shouldn't be a bottleneck.
    
    [append]: appends an index to a string
 *)
let basename_to_unique (names_set : StringSet.t)
    (append : string -> int -> string) (basename : string) : string =
  let rec gen (i : int) : string =
    let s = append basename i in
    if StringSet.mem s names_set then gen (i + 1) else s
  in
  if StringSet.mem basename names_set then gen 0 else basename

type extraction_ctx = {
  trans_ctx : trans_ctx;
  names_map : names_map;
  fmt : formatter;
  indent_incr : int;
      (** The indent increment we insert whenever we need to indent more *)
}
(** Extraction context.

    Note that the extraction context contains information coming from the
    CFIM AST (not only the pure AST). This is useful for naming, for instance:
    we use the region information to generate the names of the backward
    functions, etc.
 *)

and formatter = extraction_ctx g_formatter

let ctx_add (id : id) (name : string) (ctx : extraction_ctx) : extraction_ctx =
  (* TODO : nice debugging message if collision *)
  let names_map = names_map_add id name ctx.names_map in
  { ctx with names_map }

let ctx_get (id : id) (ctx : extraction_ctx) : string =
  IdMap.find id ctx.names_map.id_to_name

let ctx_get_function (id : A.fun_id) (rg : RegionGroupId.id option)
    (ctx : extraction_ctx) : string =
  ctx_get (FunId (id, rg)) ctx

let ctx_get_local_function (id : FunDefId.id) (rg : RegionGroupId.id option)
    (ctx : extraction_ctx) : string =
  ctx_get_function (A.Local id) rg ctx

let ctx_get_type (id : type_id) (ctx : extraction_ctx) : string =
  assert (id <> Tuple);
  ctx_get (TypeId id) ctx

let ctx_get_local_type (id : TypeDefId.id) (ctx : extraction_ctx) : string =
  ctx_get_type (AdtId id) ctx

let ctx_get_assumed_type (id : assumed_ty) (ctx : extraction_ctx) : string =
  ctx_get_type (Assumed id) ctx

let ctx_get_var (id : VarId.id) (ctx : extraction_ctx) : string =
  ctx_get (VarId id) ctx

let ctx_get_type_var (id : TypeVarId.id) (ctx : extraction_ctx) : string =
  ctx_get (TypeVarId id) ctx

let ctx_get_field (type_id : type_id) (field_id : FieldId.id)
    (ctx : extraction_ctx) : string =
  ctx_get (FieldId (type_id, field_id)) ctx

let ctx_get_struct (def_id : type_id) (ctx : extraction_ctx) : string =
  ctx_get (StructId def_id) ctx

let ctx_get_variant (def_id : type_id) (variant_id : VariantId.id)
    (ctx : extraction_ctx) : string =
  ctx_get (VariantId (def_id, variant_id)) ctx

(** Generate a unique type variable name and add it to the context *)
let ctx_add_type_var (basename : string) (id : TypeVarId.id)
    (ctx : extraction_ctx) : extraction_ctx * string =
  let name = ctx.fmt.type_var_basename ctx.names_map.names_set basename in
  let name =
    basename_to_unique ctx.names_map.names_set ctx.fmt.append_index name
  in
  let ctx = ctx_add (TypeVarId id) name ctx in
  (ctx, name)

(** See [ctx_add_type_var] *)
let ctx_add_type_vars (vars : (string * TypeVarId.id) list)
    (ctx : extraction_ctx) : extraction_ctx * string list =
  List.fold_left_map
    (fun ctx (name, id) -> ctx_add_type_var name id ctx)
    ctx vars

(** Generate a unique variable name and add it to the context *)
let ctx_add_var (basename : string) (id : VarId.id) (ctx : extraction_ctx) :
    extraction_ctx * string =
  let name =
    basename_to_unique ctx.names_map.names_set ctx.fmt.append_index basename
  in
  let ctx = ctx_add (VarId id) name ctx in
  (ctx, name)

(** See [ctx_add_var] *)
let ctx_add_vars (vars : var list) (ctx : extraction_ctx) :
    extraction_ctx * string list =
  List.fold_left_map
    (fun ctx (v : var) ->
      let name = ctx.fmt.var_basename ctx.names_map.names_set v.basename v.ty in
      ctx_add_var name v.id ctx)
    ctx vars

let ctx_add_type_params (vars : type_var list) (ctx : extraction_ctx) :
    extraction_ctx * string list =
  List.fold_left_map
    (fun ctx (var : type_var) -> ctx_add_type_var var.name var.index ctx)
    ctx vars

let ctx_add_type_def_struct (def : type_def) (ctx : extraction_ctx) :
    extraction_ctx * string =
  let cons_name = ctx.fmt.struct_constructor def.name in
  let ctx = ctx_add (StructId (AdtId def.def_id)) cons_name ctx in
  (ctx, cons_name)

let ctx_add_type_def (def : type_def) (ctx : extraction_ctx) :
    extraction_ctx * string =
  let def_name = ctx.fmt.type_name def.name in
  let ctx = ctx_add (TypeId (AdtId def.def_id)) def_name ctx in
  (ctx, def_name)

let ctx_add_field (def : type_def) (field_id : FieldId.id) (field : field)
    (ctx : extraction_ctx) : extraction_ctx * string =
  let name = ctx.fmt.field_name def.name field_id field.field_name in
  let ctx = ctx_add (FieldId (AdtId def.def_id, field_id)) name ctx in
  (ctx, name)

let ctx_add_fields (def : type_def) (fields : (FieldId.id * field) list)
    (ctx : extraction_ctx) : extraction_ctx * string list =
  List.fold_left_map
    (fun ctx (vid, v) -> ctx_add_field def vid v ctx)
    ctx fields

let ctx_add_variant (def : type_def) (variant_id : VariantId.id)
    (variant : variant) (ctx : extraction_ctx) : extraction_ctx * string =
  let name = ctx.fmt.variant_name def.name variant.variant_name in
  let ctx = ctx_add (VariantId (AdtId def.def_id, variant_id)) name ctx in
  (ctx, name)

let ctx_add_variants (def : type_def) (variants : (VariantId.id * variant) list)
    (ctx : extraction_ctx) : extraction_ctx * string list =
  List.fold_left_map
    (fun ctx (vid, v) -> ctx_add_variant def vid v ctx)
    ctx variants

let ctx_add_fun_def (def : fun_def) (ctx : extraction_ctx) : extraction_ctx =
  (* Lookup the CFIM def to compute the region group information *)
  let def_id = def.def_id in
  let cfim_def = FunDefId.Map.find def_id ctx.trans_ctx.fun_context.fun_defs in
  let sg = cfim_def.signature in
  let num_rgs = List.length sg.regions_hierarchy in
  let rg_info =
    match def.back_id with
    | None -> None
    | Some rg_id ->
        let rg = T.RegionGroupId.nth sg.regions_hierarchy rg_id in
        let regions =
          List.map
            (fun rid -> T.RegionVarId.nth sg.region_params rid)
            rg.regions
        in
        let region_names =
          List.map (fun (r : T.region_var) -> r.name) regions
        in
        Some { id = rg_id; region_names }
  in
  let def_id = A.Local def_id in
  let name = ctx.fmt.fun_name def_id def.basename num_rgs rg_info in
  let ctx = ctx_add (FunId (def_id, def.back_id)) name ctx in
  ctx

type names_map_init = {
  keywords : string list;
  assumed_adts : (assumed_ty * string) list;
  assumed_structs : (assumed_ty * string) list;
  assumed_variants : (assumed_ty * VariantId.id * string) list;
  assumed_functions : (A.assumed_fun_id * RegionGroupId.id option * string) list;
}

(** Initialize a names map with a proper set of keywords/names coming from the
    target language/prover. *)
let initialize_names_map (init : names_map_init) : names_map =
  let name_to_id =
    StringMap.of_list (List.map (fun x -> (x, UnknownId)) init.keywords)
  in
  let names_set = StringSet.of_list init.keywords in
  (* We fist initialize [id_to_name] as empty, because the id of a keyword is [UnknownId].
   * Also note that we don't need this mapping for keywords: we insert keywords only
   * to check collisions. *)
  let id_to_name = IdMap.empty in
  let nm = { id_to_name; name_to_id; names_set } in
  (* Then we add:
   * - the assumed types
   * - the assumed struct constructors
   * - the assumed variants
   * - the assumed functions
   *)
  let nm =
    List.fold_left
      (fun nm (type_id, name) -> names_map_add_assumed_type type_id name nm)
      nm init.assumed_adts
  in
  let nm =
    List.fold_left
      (fun nm (type_id, name) -> names_map_add_assumed_struct type_id name nm)
      nm init.assumed_structs
  in
  let nm =
    List.fold_left
      (fun nm (type_id, variant_id, name) ->
        names_map_add_assumed_variant type_id variant_id name nm)
      nm init.assumed_variants
  in
  let nm =
    List.fold_left
      (fun nm (fun_id, rg_id, name) ->
        names_map_add_assumed_function fun_id rg_id name nm)
      nm init.assumed_functions
  in
  (* Return *)
  nm

let compute_type_def_name (fmt : formatter) (def : type_def) : string =
  fmt.type_name def.name

(** A helper function: generates a function suffix from a region group
    information.
    TODO: move all those helpers.
*)
let default_fun_suffix (num_region_groups : int) (rg : region_group_info option)
    : string =
  (* There are several cases:
     - [rg] is `Some`: this is a forward function:
       - we add "_fwd"
     - [rg] is `None`: this is a backward function:
       - this function has one region group: we add "_back"
       - this function has several backward function: we add "_back" and an
         additional suffix to identify the precise backward function
     Note that we always add a suffix (in case there are no region groups,
     we could not add the "_fwd" suffix) to prevent name clashes between
     definitions (in particular between type and function definitions).
  *)
  match rg with
  | None -> "_fwd"
  | Some rg ->
      assert (num_region_groups > 0);
      if num_region_groups = 1 then (* Exactly one backward function *)
        "_back"
      else if
        (* Several region groups/backward functions:
           - if all the regions in the group have names, we use those names
           - otherwise we use an index
        *)
        List.for_all Option.is_some rg.region_names
      then
        (* Concatenate the region names *)
        "_back" ^ String.concat "" (List.map Option.get rg.region_names)
      else (* Use the region index *)
        "_back" ^ RegionGroupId.to_string rg.id

(** Extract information from a function, and give this information to a
    [formatter] to generate a function's name.
    
    Note that we need region information coming from CFIM (when generating
    the name for a backward function, we try to use the names of the regions
    to 
 *)
let compute_fun_def_name (ctx : trans_ctx) (fmt : formatter) (fun_id : A.fun_id)
    (rg_id : RegionGroupId.id option) : string =
  (* Lookup the function CFIM signature (we need the region information) *)
  let sg = CfimAstUtils.lookup_fun_sig fun_id ctx.fun_context.fun_defs in
  let basename = CfimAstUtils.lookup_fun_name fun_id ctx.fun_context.fun_defs in
  (* Compute the regions information *)
  let num_region_groups = List.length sg.regions_hierarchy in
  let rg_info =
    match rg_id with
    | None -> None
    | Some rg_id ->
        let rg = RegionGroupId.nth sg.regions_hierarchy rg_id in
        let regions =
          List.map (fun rid -> RegionVarId.nth sg.region_params rid) rg.regions
        in
        let region_names =
          List.map (fun (r : T.region_var) -> r.name) regions
        in
        Some { id = rg.id; region_names }
  in
  fmt.fun_name fun_id basename num_region_groups rg_info
