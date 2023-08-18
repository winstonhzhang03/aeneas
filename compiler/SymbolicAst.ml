(** The "symbolic" AST is the AST directly generated by the symbolic execution.
    It is very rough and meant to be extremely straightforward to build during
    the symbolic execution: we later apply transformations to generate the
    pure AST that we export. *)

module T = Types
module V = Values
module E = Expressions
module A = LlbcAst

(** "Meta"-place: a place stored as meta-data.

    Whenever we need to introduce new symbolic variables, for instance because
    of symbolic expansions, we try to store a "place", which gives information
    about the origin of the values (this place information comes from assignment
    information, etc.).
    We later use this place information to generate meaningful name, to prettify
    the generated code.
 *)
type mplace = {
  bv : Contexts.var_binder;
      (** It is important that we store the binder, and not just the variable id,
          because the most important information in a place is the name of the
          variable!
       *)
  projection : E.projection;
      (** We store the projection because we can, but it is actually not that useful *)
}
[@@deriving show]

type call_id =
  | Fun of A.fun_id * V.FunCallId.id
      (** A "regular" function (i.e., a function which is not a primitive operation) *)
  | Unop of E.unop
  | Binop of E.binop
[@@deriving show, ord]

type call = {
  call_id : call_id;
  ctx : Contexts.eval_ctx;
      (** The context upon calling the function (after the operands have been
          evaluated). We need it to compute the translated values for shared
          borrows (we need to perform lookups).
       *)
  abstractions : V.AbstractionId.id list;
  (* TODO: rename to "...args" *)
  type_params : T.ety list;
  (* TODO: rename to "...args" *)
  const_generic_params : T.const_generic list;
  args : V.typed_value list;
  args_places : mplace option list;  (** Meta information *)
  dest : V.symbolic_value;
  dest_place : mplace option;  (** Meta information *)
}
[@@deriving show]

(** Meta information, not necessary for synthesis but useful to guide it to
    generate a pretty output.
 *)

type meta =
  | Assignment of Contexts.eval_ctx * mplace * V.typed_value * mplace option
      (** We generated an assignment (destination, assigned value, src) *)
[@@deriving show]

type variant_id = T.VariantId.id [@@deriving show]
type global_decl_id = A.GlobalDeclId.id [@@deriving show]
type 'a symbolic_value_id_map = 'a V.SymbolicValueId.Map.t [@@deriving show]
type 'a region_group_id_map = 'a T.RegionGroupId.Map.t [@@deriving show]

(** Ancestor for {!expression} iter visitor *)
class ['self] iter_expression_base =
  object (self : 'self)
    inherit [_] VisitorsRuntime.iter
    method visit_eval_ctx : 'env -> Contexts.eval_ctx -> unit = fun _ _ -> ()
    method visit_typed_value : 'env -> V.typed_value -> unit = fun _ _ -> ()
    method visit_call : 'env -> call -> unit = fun _ _ -> ()
    method visit_abs : 'env -> V.abs -> unit = fun _ _ -> ()
    method visit_loop_id : 'env -> V.loop_id -> unit = fun _ _ -> ()
    method visit_variant_id : 'env -> variant_id -> unit = fun _ _ -> ()

    method visit_const_generic_var_id : 'env -> T.const_generic_var_id -> unit =
      fun _ _ -> ()

    method visit_symbolic_value_id : 'env -> V.symbolic_value_id -> unit =
      fun _ _ -> ()

    method visit_symbolic_value : 'env -> V.symbolic_value -> unit =
      fun _ _ -> ()

    method visit_region_group_id : 'env -> T.RegionGroupId.id -> unit =
      fun _ _ -> ()

    method visit_global_decl_id : 'env -> global_decl_id -> unit = fun _ _ -> ()
    method visit_mplace : 'env -> mplace -> unit = fun _ _ -> ()
    method visit_meta : 'env -> meta -> unit = fun _ _ -> ()

    method visit_region_group_id_map
        : 'a. ('env -> 'a -> unit) -> 'env -> 'a region_group_id_map -> unit =
      fun f env m ->
        T.RegionGroupId.Map.iter
          (fun id x ->
            self#visit_region_group_id env id;
            f env x)
          m

    method visit_symbolic_value_id_map
        : 'a. ('env -> 'a -> unit) -> 'env -> 'a symbolic_value_id_map -> unit =
      fun f env m ->
        V.SymbolicValueId.Map.iter
          (fun id x ->
            self#visit_symbolic_value_id env id;
            f env x)
          m

    method visit_symbolic_value_id_set : 'env -> V.symbolic_value_id_set -> unit
        =
      fun env s ->
        V.SymbolicValueId.Set.iter (self#visit_symbolic_value_id env) s

    method visit_integer_type : 'env -> T.integer_type -> unit = fun _ _ -> ()
    method visit_scalar_value : 'env -> V.scalar_value -> unit = fun _ _ -> ()

    method visit_symbolic_expansion : 'env -> V.symbolic_expansion -> unit =
      fun _ _ -> ()
  end

(** **Rem.:** here, {!expression} is not at all equivalent to the expressions
    used in LLBC or in lambda-calculus: they are simply a first step towards
    lambda-calculus expressions.
 *)
type expression =
  | Return of Contexts.eval_ctx * V.typed_value option
      (** There are two cases:
          - the AST is for a forward function: the typed value should contain
            the value which was in the return variable
          - the AST is for a backward function: the typed value should be [None]

          The context is the evaluation context upon reaching the return, We
          need it to translate shared borrows to pure values (we need to be able
          to look up the shared values in the context).
       *)
  | Panic
  | FunCall of call * expression
  | EndAbstraction of Contexts.eval_ctx * V.abs * expression
      (** The context is the evaluation context upon ending the abstraction,
          just after we removed the abstraction from the context.

          The context is the evaluation context from after evaluating the asserted
          value. It has the same purpose as for the {!Return} case.
       *)
  | EvalGlobal of global_decl_id * V.symbolic_value * expression
      (** Evaluate a global to a fresh symbolic value *)
  | Assertion of Contexts.eval_ctx * V.typed_value * expression
      (** An assertion.

          The context is the evaluation context from after evaluating the asserted
          value. It has the same purpose as for the {!Return} case.
       *)
  | Expansion of mplace option * V.symbolic_value * expansion
      (** Expansion of a symbolic value.
    
          The place is "meta": it gives the path to the symbolic value (if available)
          which got expanded (this path is available when the symbolic expansion
          comes from a path evaluation, during an assignment for instance).
          We use it to compute meaningful names for the variables we introduce,
          to prettify the generated code.
       *)
  | IntroSymbolic of
      Contexts.eval_ctx
      * mplace option
      * V.symbolic_value
      * value_aggregate
      * expression
      (** We introduce a new symbolic value, equal to some other value.

          This is used for instance when reorganizing the environment to compute
          fixed points: we duplicate some shared symbolic values to destructure
          the shared values, in order to make the environment a bit more general
          (while losing precision of course).

          The context is the evaluation context from before introducing the new
          value. It has the same purpose as for the {!Return} case.
       *)
  | ForwardEnd of
      Contexts.eval_ctx
      * V.typed_value symbolic_value_id_map option
      * expression
      * expression region_group_id_map
      (** We use this delimiter to indicate at which point we switch to the
          generation of code specific to the backward function(s). This allows
          us in particular to factor the work out: we don't need to replay the
          symbolic execution up to this point, and can reuse it for the forward
          function and all the backward functions.

          The first expression gives the end of the translation for the forward
          function, the map from region group ids to expressions gives the end
          of the translation for the backward functions.

          The optional map from symbolic values to input values are input values
          for loops: upon entering a loop, in the translation we call the loop
          translation function, which takes care of the end of the execution.

          The evaluation context is the context at the moment we introduce the
          [ForwardEnd], and is used to translate the input values (see the
          comments for the {!Return} variant).
       *)
  | Loop of loop  (** Loop *)
  | ReturnWithLoop of V.loop_id * bool
      (** End the function with a call to a loop function.

          This encompasses the cases when we synthesize a function body
          and enter a loop for the first time, or when we synthesize a
          loop body and reach a [Continue].

          The boolean is [is_continue].
       *)
  | Meta of meta * expression  (** Meta information *)

and loop = {
  loop_id : V.loop_id;
  input_svalues : V.symbolic_value list;  (** The input symbolic values *)
  fresh_svalues : V.symbolic_value_id_set;
      (** The symbolic values introduced by the loop fixed-point *)
  rg_to_given_back_tys :
    ((T.RegionId.Set.t * T.rty list) T.RegionGroupId.Map.t[@opaque]);
      (** The map from region group ids to the types of the values given back
          by the corresponding loop abstractions.
       *)
  end_expr : expression;
      (** The end of the function (upon the moment it enters the loop) *)
  loop_expr : expression;  (** The symbolically executed loop body *)
}

and expansion =
  | ExpandNoBranch of V.symbolic_expansion * expression
      (** A symbolic expansion which doesn't generate a branching.
          Includes:
          - concrete expansion
          - borrow expansion
          *Doesn't* include:
          - expansion of ADTs with one variant
       *)
  | ExpandAdt of (variant_id option * V.symbolic_value list * expression) list
      (** ADT expansion *)
  | ExpandBool of expression * expression
      (** A boolean expansion (i.e, an [if ... then ... else ...]) *)
  | ExpandInt of
      T.integer_type * (V.scalar_value * expression) list * expression
      (** An integer expansion (i.e, a switch over an integer). The last
          expression is for the "otherwise" branch. *)

(* Remark: this type doesn't have to be mutually recursive with the other
   types, but it makes it easy to generate the visitors *)
and value_aggregate =
  | SingleValue of V.typed_value  (** Regular case *)
  | Array of V.typed_value list
      (** This is used when introducing array aggregates *)
  | ConstGenericValue of T.const_generic_var_id
      (** This is used when evaluating a const generic value: in the interpreter,
          we introduce a fresh symbolic value. *)
[@@deriving
  show,
    visitors
      {
        name = "iter_expression";
        variety = "iter";
        ancestors = [ "iter_expression_base" ];
        nude = true (* Don't inherit {!VisitorsRuntime.iter} *);
        concrete = true;
        polymorphic = false;
      }]
