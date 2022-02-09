(** The following module defines micro-passes which operate on the pure AST *)

open Pure
open PureUtils
open TranslateCore

(** The local logger *)
let log = L.pure_micro_passes_log

type config = {
  decompose_monadic_let_bindings : bool;
      (** Some provers like F* don't support the decomposition of return values
          in monadic let-bindings:
          ```
          // NOT supported in F*
          let (x, y) <-- f ();
          ...
          ```

          In such situations, we might want to introduce an intermediate
          assignment:
          ```
          let tmp <-- f ();
          let (x, y) = tmp in
          ...
          ```
       *)
  unfold_monadic_let_bindings : bool;
      (** Controls the unfolding of monadic let-bindings to explicit matches:
          
          `y <-- f x; ...`

          becomes:
          
          `match f x with | Failure -> Failure | Return y -> ...`

          
          This is useful when extracting to F*: the support for monadic
          definitions is not super powerful.
          Note that when [undolf_monadic_let_bindings] is true, setting
          [decompose_monadic_let_bindings] to true and only makes the code
          more verbose.
       *)
  filter_useless_monadic_calls : bool;
      (** Controls whether we try to filter the calls to monadic functions
          (which can fail) when their outputs are not used.
          
          See the comments for [expression_contains_child_call_in_all_paths]
          for additional explanations.
          
          TODO: rename to [filter_useless_monadic_calls]
       *)
  filter_useless_functions : bool;
      (** If [filter_useless_monadic_calls] is activated, some functions
          become useless: if this option is true, we don't extract them.

          The calls to functions which always get filtered are:
          - the forward functions with unit return value
          - the backward functions which don't output anything (backward
            functions coming from rust functions with no mutable borrows
            as input values - note that if a function doesn't take mutable
            borrows as inputs, it can't return mutable borrows; we actually
            dynamically check for that).
       *)
  add_unit_args : bool;
      (** Add unit input arguments to functions with no arguments. *)
}
(** A configuration to control the application of the passes *)

(** Small utility.

    We sometimes have to insert new fresh variables in a function body, in which
    case we need to make their indices greater than the indices of all the variables
    in the body.
    TODO: things would be simpler if we used a better representation of the
    variables indices...
 *)
let get_expression_min_var_counter (e : expression) : VarId.generator =
  let obj =
    object
      inherit [_] reduce_expression

      method zero _ = VarId.zero

      method plus id0 id1 _ = VarId.max (id0 ()) (id1 ())
      (* Get the maximum *)

      method! visit_var _ v _ = v.id
    end
  in
  let id = obj#visit_expression () e () in
  VarId.generator_from_incr_id id

type pn_ctx = string VarId.Map.t
(** "pretty-name context": see [compute_pretty_names] *)

(** This function computes pretty names for the variables in the pure AST. It
    relies on the "meta"-place information in the AST to generate naming
    constraints, and then uses those to compute the names.
    
    The way it works is as follows:
    - we only modify the names of the unnamed variables
    - whenever we see an rvalue/lvalue which is exactly an unnamed variable,
      and this value is linked to some meta-place information which contains
      a name and an empty path, we consider we should use this name
      
    Something important is that, for every variable we find, the name of this
    variable is influenced by the information we find *below* in the AST.

    For instance, the following situations happen:
    
    - let's say we evaluate:
      ```
      match (ls : List<T>) {
        List::Cons(x, hd) => {
          ...
        }
      }
      ```
      
      Actually, in MIR, we get:
      ```
      tmp := discriminant(ls);
      switch tmp {
        0 => {
          x := (ls as Cons).0;
          hd := (ls as Cons).1;
          ...
        }
      }
      ```
      If `ls` maps to a symbolic value `s0` upon evaluating the match in symbolic
      mode, we expand this value upon evaluating `tmp = discriminant(ls)`.
      However, at this point, we don't know which should be the names of
      the symbolic values we introduce for the fields of `Cons`!
      Let's imagine we have (for the `Cons` branch): `s0 ~~> Cons s1 s2`.
      The assigments lead to the following binding in the evaluation context:
      ```
      x -> s1
      hd -> s2
      ```
      
      When generating the symbolic AST, we save as meta-information that we
      assign `s1` to the place `x` and `s2` to the place `hd`. This way,
      we learn we can use the names `x` and `hd` for the variables which are
      introduced by the match:
      ```
      match ls with
      | Cons x hd -> ...
      | ...
      ```
   - TODO: inputs and end abstraction...
 *)
let compute_pretty_names (def : fun_def) : fun_def =
  (* Small helpers *)
  (* 
   * When we do branchings, we need to merge (the constraints saved in) the
   * contexts returned by the different branches.
   *
   * Note that by doing so, some mappings from var id to name
   * in one context may be overriden by the ones in the other context.
   *
   * This should be ok because:
   * - generally, the overriden variables should have been introduced *inside*
   *   the branches, in which case we don't care
   * - or they were introduced before, in which case the naming should generally
   *   be consistent? In the worse case, it isn't, but it leads only to less
   *   readable code, not to unsoundness. This case should be pretty rare,
   *   also.
   *)
  let merge_ctxs (ctx0 : pn_ctx) (ctx1 : pn_ctx) : pn_ctx =
    VarId.Map.fold (fun id name ctx -> VarId.Map.add id name ctx) ctx0 ctx1
  in
  let merge_ctxs_ls (ctxs : pn_ctx list) : pn_ctx =
    List.fold_left (fun ctx0 ctx1 -> merge_ctxs ctx0 ctx1) VarId.Map.empty ctxs
  in

  let add_var (ctx : pn_ctx) (v : var) : pn_ctx =
    assert (not (VarId.Map.mem v.id ctx));
    match v.basename with
    | None -> ctx
    | Some name -> VarId.Map.add v.id name ctx
  in
  let update_var (ctx : pn_ctx) (v : var) : var =
    match v.basename with
    | Some _ -> v
    | None -> (
        match VarId.Map.find_opt v.id ctx with
        | None -> v
        | Some basename -> { v with basename = Some basename })
  in
  let update_typed_lvalue ctx (lv : typed_lvalue) : typed_lvalue =
    let obj =
      object
        inherit [_] map_typed_lvalue

        method! visit_var _ v = update_var ctx v
      end
    in
    obj#visit_typed_lvalue () lv
  in

  let add_constraint (mp : mplace) (var_id : VarId.id) (ctx : pn_ctx) : pn_ctx =
    match (mp.name, mp.projection) with
    | Some name, [] ->
        (* Check if the variable already has a name - if not: insert the new name *)
        if VarId.Map.mem var_id ctx then ctx else VarId.Map.add var_id name ctx
    | _ -> ctx
  in
  let add_right_constraint (mp : mplace) (rv : typed_rvalue) (ctx : pn_ctx) :
      pn_ctx =
    match rv.value with
    | RvPlace { var = var_id; projection = [] } -> add_constraint mp var_id ctx
    | _ -> ctx
  in
  let add_opt_right_constraint (mp : mplace option) (rv : typed_rvalue)
      (ctx : pn_ctx) : pn_ctx =
    match mp with None -> ctx | Some mp -> add_right_constraint mp rv ctx
  in
  let add_left_constraint (lv : typed_lvalue) (ctx : pn_ctx) : pn_ctx =
    let obj =
      object (self)
        inherit [_] reduce_typed_lvalue

        method zero _ = VarId.Map.empty

        method plus ctx0 ctx1 _ = merge_ctxs (ctx0 ()) (ctx1 ())

        method! visit_var _ v () = add_var (self#zero ()) v
      end
    in
    let ctx1 = obj#visit_typed_lvalue () lv () in
    merge_ctxs ctx ctx1
  in

  (* *)
  let rec update_texpression (e : texpression) (ctx : pn_ctx) :
      pn_ctx * texpression =
    let ty = e.ty in
    let ctx, e =
      match e.e with
      | Value (v, mp) -> update_value v mp ctx
      | Call call -> update_call call ctx
      | Let (monadic, lb, re, e) -> update_let monadic lb re e ctx
      | Switch (scrut, body) -> update_switch_body scrut body ctx
      | Meta (meta, e) -> update_meta meta e ctx
    in
    (ctx, { e; ty })
  (* *)
  and update_value (v : typed_rvalue) (mp : mplace option) (ctx : pn_ctx) :
      pn_ctx * expression =
    let ctx = add_opt_right_constraint mp v ctx in
    (ctx, Value (v, mp))
  (* *)
  and update_call (call : call) (ctx : pn_ctx) : pn_ctx * expression =
    let ctx, args =
      List.fold_left_map
        (fun ctx arg -> update_texpression arg ctx)
        ctx call.args
    in
    let call = { call with args } in
    (ctx, Call call)
  (* *)
  and update_let (monadic : bool) (lv : typed_lvalue) (re : texpression)
      (e : texpression) (ctx : pn_ctx) : pn_ctx * expression =
    let ctx = add_left_constraint lv ctx in
    let ctx, re = update_texpression re ctx in
    let ctx, e = update_texpression e ctx in
    let lv = update_typed_lvalue ctx lv in
    (ctx, Let (monadic, lv, re, e))
  (* *)
  and update_switch_body (scrut : texpression) (body : switch_body)
      (ctx : pn_ctx) : pn_ctx * expression =
    let ctx, scrut = update_texpression scrut ctx in

    let ctx, body =
      match body with
      | If (e_true, e_false) ->
          let ctx1, e_true = update_texpression e_true ctx in
          let ctx2, e_false = update_texpression e_false ctx in
          let ctx = merge_ctxs ctx1 ctx2 in
          (ctx, If (e_true, e_false))
      | Match branches ->
          let ctx_branches_ls =
            List.map
              (fun br ->
                let ctx = add_left_constraint br.pat ctx in
                let ctx, branch = update_texpression br.branch ctx in
                let pat = update_typed_lvalue ctx br.pat in
                (ctx, { pat; branch }))
              branches
          in
          let ctxs, branches = List.split ctx_branches_ls in
          let ctx = merge_ctxs_ls ctxs in
          (ctx, Match branches)
    in
    (ctx, Switch (scrut, body))
  (* *)
  and update_meta (meta : meta) (e : texpression) (ctx : pn_ctx) :
      pn_ctx * expression =
    match meta with
    | Assignment (mp, rvalue) ->
        let ctx = add_right_constraint mp rvalue ctx in
        let ctx, e = update_texpression e ctx in
        (ctx, e.e)
  in

  let input_names =
    List.filter_map
      (fun (v : var) ->
        match v.basename with None -> None | Some name -> Some (v.id, name))
      def.inputs
  in
  let ctx = VarId.Map.of_list input_names in
  let _, body = update_texpression def.body ctx in
  { def with body }

(** Remove the meta-information *)
let remove_meta (def : fun_def) : fun_def =
  let obj =
    object
      inherit [_] map_expression as super

      method! visit_Meta env _ e = super#visit_expression env e.e
    end
  in
  let body = obj#visit_texpression () def.body in
  { def with body }

(** Inline the useless variable reassignments (a lot of variable assignments
    like `let x = y in ...ÿ` are introduced through the compilation to MIR
    and by the translation, and the variable used on the left is often unnamed.

    [inline_named]: if `true`, inline all the assignments of the form
    `let VAR = VAR in ...`, otherwise inline only the ones where the variable
    on the left is anonymous.
 *)
let inline_useless_var_reassignments (inline_named : bool) (def : fun_def) :
    fun_def =
  (* Register a substitution.
     When registering that we need to substitute v0 with v1, we check
     if v1 is itself substituted by v2, in which case we register:
     `v0 --> v2` instead of `v0 --> v1`
  *)
  let add_subst v0 v1 m =
    match VarId.Map.find_opt v1 m with
    | None -> VarId.Map.add v0 v1 m
    | Some v2 -> VarId.Map.add v0 v2 m
  in

  let obj =
    object
      inherit [_] map_expression as super

      method! visit_Let env monadic lv re e =
        (* Check that:
         * - the let-binding is not monadic
         * - the left-value is a variable
         * - the assigned expression is a value *)
        match (monadic, lv.value, re.e) with
        | false, LvVar (Var (lv_var, _)), Value (rv, _) -> (
            (* Check that:
             * - the left variable is unnamed or that [inline_named] is true
             * - the right-value is a variable
             *)
            match ((inline_named, lv_var.basename), rv.value) with
            | (true, _ | false, None), RvPlace { var; projection = [] } ->
                (* Update the environment and explore the next expression
                 * (dropping the currrent let) *)
                let env = add_subst lv_var.id var env in
                super#visit_expression env e.e
            | _ -> super#visit_Let env monadic lv re e)
        | _ -> super#visit_Let env monadic lv re e
      (** Visit the let-bindings to filter the useless ones (and update
          the substitution map while doing so *)

      method! visit_place env p =
        (* Check if we need to substitute *)
        match VarId.Map.find_opt p.var env with
        | None -> (* No substitution *) p
        | Some nv ->
            (* Substitute *)
            { p with var = nv }
      (** Visit the places used as rvalues, to substitute them if necessary *)
    end
  in
  let body = obj#visit_texpression VarId.Map.empty def.body in
  { def with body }

(** Given a forward or backward function call, is there, for every execution
    path, a child backward function called later with exactly the same input
    list prefix? We use this to filter useless function calls: if there are
    such child calls, we can remove this one (in case its outputs are not
    used).
    We do this check because we can't simply remove function calls whose
    outputs are not used, as they might fail. However, if a function fails,
    its children backward functions then fail on the same inputs (ignoring
    the additional inputs those receive).
    
    For instance, if we have:
    ```
    fn f<'a>(x : &'a mut T);
    ```
    
    We often have  things like this in the synthesized code:
    ```
    _ <-- f x;
    ...
    nx <-- f@back'a x y;
    ...
    ```

    In this situation, we can remove the call `f x`.
 *)
let expression_contains_child_call_in_all_paths (ctx : trans_ctx) (call0 : call)
    (e : texpression) : bool =
  let check_call call1 : bool =
    (* Check the func_ids, to see if call1's function is a child of call0's function *)
    match (call0.func, call1.func) with
    | Regular (id0, rg_id0), Regular (id1, rg_id1) ->
        (* Both are "regular" calls: check if they come from the same rust function *)
        if id0 = id1 then
          (* Same rust functions: check the regions hierarchy *)
          let call1_is_child =
            match (rg_id0, rg_id1) with
            | None, _ ->
                (* The function used in call0 is the forward function: the one
                 * used in call1 is necessarily a child *)
                true
            | Some _, None ->
                (* Opposite of previous case *)
                false
            | Some rg_id0, Some rg_id1 ->
                if rg_id0 = rg_id1 then true
                else
                  (* We need to use the regions hierarchy *)
                  (* First, lookup the signature of the CFIM function *)
                  let sg =
                    CfimAstUtils.lookup_fun_sig id0 ctx.fun_context.fun_defs
                  in
                  (* Compute the set of ancestors of the function in call1 *)
                  let call1_ancestors =
                    CfimAstUtils.list_parent_region_groups sg rg_id1
                  in
                  (* Check if the function used in call0 is inside *)
                  T.RegionGroupId.Set.mem rg_id0 call1_ancestors
          in
          (* If call1 is a child, then we need to check if the input arguments
           * used in call0 are a prefix of the input arguments used in call1
           * (note call1 being a child, it will likely consume strictly more
           * given back values).
           * *)
          if call1_is_child then
            let call1_args =
              Collections.List.prefix (List.length call0.args) call1.args
            in
            let args = List.combine call0.args call1_args in
            (* Note that the input values are expressions, *which may contain
             * meta-values* (which we need to ignore). We only consider the
             * case where both expressions are actually values. *)
            let input_eq (v0, v1) =
              match (v0.e, v1.e) with
              | Value (v0, _), Value (v1, _) -> v0 = v1
              | _ -> false
            in
            call0.type_params = call1.type_params && List.for_all input_eq args
          else (* Not a child *)
            false
        else (* Not the same function *)
          false
    | _ -> false
  in

  let visitor =
    object (self)
      inherit [_] reduce_expression

      method zero _ = false

      method plus b0 b1 _ = b0 () && b1 ()

      method! visit_expression env e =
        match e with
        | Value (_, _) -> fun _ -> false
        | Let (_, _, { e = Call call1; ty = _ }, e) ->
            let call_is_child = check_call call1 in
            if call_is_child then fun () -> true
            else self#visit_texpression env e
        | Let (_, _, re, e) ->
            fun () ->
              self#visit_texpression env re ()
              && self#visit_texpression env e ()
        | Call call1 -> fun () -> check_call call1
        | Meta (_, e) -> self#visit_texpression env e
        | Switch (_, body) -> self#visit_switch_body env body
      (** We need to reimplement the way we compose the booleans *)

      method! visit_texpression env e =
        (* We take care not to visit the type *)
        self#visit_expression env e.e

      method! visit_switch_body env body =
        match body with
        | If (e1, e2) ->
            fun () ->
              self#visit_texpression env e1 ()
              && self#visit_texpression env e2 ()
        | Match branches ->
            fun () ->
              List.for_all
                (fun br -> self#visit_texpression env br.branch ())
                branches
    end
  in
  visitor#visit_texpression () e ()

(** Filter the useless assignments (removes the useless variables, filters
    the function calls) *)
let filter_useless (filter_monadic_calls : bool) (ctx : trans_ctx)
    (def : fun_def) : fun_def =
  (* We first need a transformation on *left-values*, which filters the useless
   * variables and tells us whether the value contains any variable which has
   * not been replaced by `_` (in which case we need to keep the assignment,
   * etc.).
   * 
   * This is implemented as a map-reduce.
   *
   * Returns: ( filtered_left_value, *all_dummies* )
   *
   * `all_dummies`:
   * If the returned boolean is true, it means that all the variables appearing
   * in the filtered left-value are *dummies* (meaning that if this left-value
   * appears at the left of a let-binding, this binding might potentially be
   * removed).
   *)
  let lv_visitor =
    object
      inherit [_] mapreduce_typed_lvalue

      method zero _ = true

      method plus b0 b1 _ = b0 () && b1 ()

      method! visit_var_or_dummy env v =
        match v with
        | Dummy -> (Dummy, fun _ -> true)
        | Var (v, mp) ->
            if VarId.Set.mem v.id env then (Var (v, mp), fun _ -> false)
            else (Dummy, fun _ -> true)
    end
  in
  let filter_typed_lvalue (used_vars : VarId.Set.t) (lv : typed_lvalue) :
      typed_lvalue * bool =
    let lv, all_dummies = lv_visitor#visit_typed_lvalue used_vars lv in
    (lv, all_dummies ())
  in

  (* We then implement the transformation on *expressions* through a mapreduce.
   * Note that the transformation is bottom-up.
   * The map filters the useless assignments, the reduce computes the set of
   * used variables.
   *)
  let expr_visitor =
    object (self)
      inherit [_] mapreduce_expression as super

      method zero _ = VarId.Set.empty

      method plus s0 s1 _ = VarId.Set.union (s0 ()) (s1 ())

      method! visit_place _ p = (p, fun _ -> VarId.Set.singleton p.var)
      (** Whenever we visit a place, we need to register the used variable *)

      method! visit_expression env e =
        match e with
        | Value (_, _) | Call _ | Switch (_, _) | Meta (_, _) ->
            super#visit_expression env e
        | Let (monadic, lv, re, e) ->
            (* Compute the set of values used in the next expression *)
            let e, used = self#visit_texpression env e in
            let used = used () in
            (* Filter the left values *)
            let lv, all_dummies = filter_typed_lvalue used lv in
            (* Small utility - called if we can't filter the let-binding *)
            let dont_filter () =
              let re, used_re = self#visit_texpression env re in
              let used = VarId.Set.union used (used_re ()) in
              (Let (monadic, lv, re, e), fun _ -> used)
            in
            (* Potentially filter the let-binding *)
            if all_dummies then
              if not monadic then
                (* Not a monadic let-binding: simple case *)
                (e.e, fun _ -> used)
              else
                (* Monadic let-binding: trickier.
                 * We can filter if the right-expression is a function call,
                 * under some conditions. *)
                match (filter_monadic_calls, re.e) with
                | true, Call call ->
                    (* We need to check if there is a child call - see
                     * the comments for:
                     * [expression_contains_child_call_in_all_paths] *)
                    let has_child_call =
                      expression_contains_child_call_in_all_paths ctx call e
                    in
                    if has_child_call then (* Filter *)
                      (e.e, fun _ -> used)
                    else (* No child call: don't filter *)
                      dont_filter ()
                | _ ->
                    (* Not a call or not allowed to filter: we can't filter *)
                    dont_filter ()
            else (* There are used variables: don't filter *)
              dont_filter ()
    end
  in
  (* Visit the body *)
  let body, used_vars = expr_visitor#visit_texpression () def.body in
  (* Visit the parameters - TODO: update: we can filter only if the definition
   * is not recursive (otherwise it might mess up with the decrease clauses:
   * the decrease clauses uses all the inputs given to the function, if some
   * inputs are replaced by '_' we can't give it to the function used in the
   * decreases clause).
   * For now we deactivate the filtering. *)
  let used_vars = used_vars () in
  let inputs_lvs =
    if false then
      List.map (fun lv -> fst (filter_typed_lvalue used_vars lv)) def.inputs_lvs
    else def.inputs_lvs
  in
  (* Return *)
  { def with body; inputs_lvs }

(** Return `None` if the function is a backward function with no outputs (so
    that we eliminate the definition which is useless).

    Note that the calls to such functions are filtered when translating from
    symbolic to pure. Here, we remove the definitions altogether, because they
    are now useless
  *)
let filter_if_backward_with_no_outputs (config : config) (def : fun_def) :
    fun_def option =
  if
    config.filter_useless_functions && Option.is_some def.back_id
    && def.signature.outputs = []
  then None
  else Some def

(** Return `false` if the forward function is useless and should be filtered.

    - a forward function with no output (comes from a Rust function with
      unit return type)
    - the function has mutable borrows as inputs (which is materialized
      by the fact we generated backward functions which were not filtered).

    In such situation, every call to the Rust function will be translated to:
    - a call to the forward function which returns nothing
    - calls to the backward functions
    As a failing backward function implies the forward function also fails,
    we can filter the calls to the forward function, which thus becomes
    useless.
    In such situation, we can remove the forward function definition
    altogether.
  *)
let keep_forward (config : config) (trans : pure_fun_translation) : bool =
  let fwd, backs = trans in
  (* Note that at this point, the output types are no longer seen as tuples:
   * they should be lists of length 1. *)
  if
    config.filter_useless_functions
    && fwd.signature.outputs = [ mk_result_ty unit_ty ]
    && backs <> []
  then false
  else true

(** Add unit arguments (optionally) to functions with no arguments, and
    change their output type to use `result`
  *)
let to_monadic (add_unit_args : bool) (def : fun_def) : fun_def =
  (* Update the body *)
  let obj =
    object
      inherit [_] map_expression as super

      method! visit_call env call =
        if call.args = [] && add_unit_args then
          let args = [ mk_value_expression unit_rvalue None ] in
          { call with args } (* Otherwise: nothing to do *)
        else super#visit_call env call
    end
  in
  let body = obj#visit_texpression () def.body in
  let def = { def with body } in

  (* Update the signature: first the input types *)
  let def =
    if def.inputs = [] && add_unit_args then (
      assert (def.signature.inputs = []);
      let signature = { def.signature with inputs = [ unit_ty ] } in
      let var_cnt = get_expression_min_var_counter def.body.e in
      let id, _ = VarId.fresh var_cnt in
      let var = { id; basename = None; ty = unit_ty } in
      let inputs = [ var ] in
      let input_lv = mk_typed_lvalue_from_var var None in
      let inputs_lvs = [ input_lv ] in
      { def with signature; inputs; inputs_lvs })
    else def
  in
  (* Then the output type *)
  let output_ty =
    match (def.back_id, def.signature.outputs) with
    | None, [ out_ty ] ->
        (* Forward function: there is always exactly one output *)
        mk_result_ty out_ty
    | Some _, outputs ->
        (* Backward function: we have to group them *)
        mk_result_ty (mk_simpl_tuple_ty outputs)
    | _ -> failwith "Unreachable"
  in
  let outputs = [ output_ty ] in
  let signature = { def.signature with outputs } in
  { def with signature }

(** Convert the unit variables to `()` if they are used as right-values or
    `_` if they are used as left values in patterns. *)
let unit_vars_to_unit (def : fun_def) : fun_def =
  (* The map visitor *)
  let obj =
    object
      inherit [_] map_expression as super

      method! visit_var_or_dummy _ v =
        match v with
        | Dummy -> Dummy
        | Var (v, mp) -> if v.ty = unit_ty then Dummy else Var (v, mp)
      (** Replace in lvalues *)

      method! visit_typed_rvalue env rv =
        if rv.ty = unit_ty then unit_rvalue else super#visit_typed_rvalue env rv
      (** Replace in rvalues *)
    end
  in
  (* Update the body *)
  let body = obj#visit_texpression () def.body in
  (* Update the input parameters *)
  let inputs_lvs = List.map (obj#visit_typed_lvalue ()) def.inputs_lvs in
  (* Return *)
  { def with body; inputs_lvs }

(** Eliminate the box functions like `Box::new`, `Box::deref`, etc. Most of them
    are translated to identity, and `Box::free` is translated to `()`.

    Note that the box types have already been eliminated during the translation
    from symbolic to pure.
    The reason why we don't eliminate the box functions at the same time is
    that we would need to eliminate them in two different places: when translating
    function calls, and when translating end abstractions. Here, we can do
    something simpler, in one micro-pass.
 *)
let eliminate_box_functions (_ctx : trans_ctx) (def : fun_def) : fun_def =
  (* The map visitor *)
  let obj =
    object
      inherit [_] map_expression as super

      method! visit_Call env call =
        match call.func with
        | Regular (A.Assumed aid, rg_id) -> (
            match (aid, rg_id) with
            | A.BoxNew, _ ->
                let arg = Collections.List.to_cons_nil call.args in
                arg.e
            | A.BoxDeref, None ->
                (* `Box::deref` forward is the identity *)
                let arg = Collections.List.to_cons_nil call.args in
                arg.e
            | A.BoxDeref, Some _ ->
                (* `Box::deref` backward is `()` (doesn't give back anything) *)
                (mk_value_expression unit_rvalue None).e
            | A.BoxDerefMut, None ->
                (* `Box::deref_mut` forward is the identity *)
                let arg = Collections.List.to_cons_nil call.args in
                arg.e
            | A.BoxDerefMut, Some _ ->
                (* `Box::deref_mut` back is the identity *)
                let arg =
                  match call.args with
                  | [ _; given_back ] -> given_back
                  | _ -> failwith "Unreachable"
                in
                arg.e
            | A.BoxFree, _ -> (mk_value_expression unit_rvalue None).e
            | ( ( A.Replace | A.VecNew | A.VecPush | A.VecInsert | A.VecLen
                | A.VecIndex | A.VecIndexMut ),
                _ ) ->
                super#visit_Call env call)
        | _ -> super#visit_Call env call
    end
  in
  (* Update the body *)
  let body = obj#visit_texpression () def.body in
  { def with body }

(** Decompose the monadic let-bindings.

    See the explanations in [config].
 *)
let decompose_monadic_let_bindings (_ctx : trans_ctx) (def : fun_def) : fun_def
    =
  (* Set up the var id generator *)
  let cnt = get_expression_min_var_counter def.body.e in
  let _, fresh_id = VarId.mk_stateful_generator cnt in
  (* It is a very simple map *)
  let obj =
    object (self)
      inherit [_] map_expression as super

      method! visit_Let env monadic lv re next_e =
        if not monadic then super#visit_Let env monadic lv re next_e
        else
          (* If monadic, we need to check if the left-value is a variable:
           * - if yes, don't decompose
           * - if not, make the decomposition in two steps
           *)
          match lv.value with
          | LvVar _ ->
              (* Variable: nothing to do *)
              super#visit_Let env monadic lv re next_e
          | _ ->
              (* Not a variable: decompose *)
              (* Introduce a temporary variable to receive the value of the
               * monadic binding *)
              let vid = fresh_id () in
              let tmp : var = { id = vid; basename = None; ty = lv.ty } in
              let ltmp = mk_typed_lvalue_from_var tmp None in
              let rtmp = mk_typed_rvalue_from_var tmp in
              let rtmp = mk_value_expression rtmp None in
              (* Visit the next expression *)
              let next_e = self#visit_texpression env next_e in
              (* Create the let-bindings *)
              (mk_let true ltmp re (mk_let false lv rtmp next_e)).e
    end
  in
  (* Update the body *)
  let body = obj#visit_texpression () def.body in
  (* Return *)
  { def with body }

(** Unfold the monadic let-bindings to explicit matches. *)
let unfold_monadic_let_bindings (_ctx : trans_ctx) (def : fun_def) : fun_def =
  (* It is a very simple map *)
  let obj =
    object (self)
      inherit [_] map_expression as super

      method! visit_Let env monadic lv re e =
        if not monadic then super#visit_Let env monadic lv re e
        else
          let fail_pat = mk_result_fail_lvalue lv.ty in
          let fail_value = mk_result_fail_rvalue e.ty in
          let fail_branch =
            { pat = fail_pat; branch = mk_value_expression fail_value None }
          in
          let success_pat = mk_result_return_lvalue lv in
          let success_branch = { pat = success_pat; branch = e } in
          let switch_body = Match [ fail_branch; success_branch ] in
          let e = Switch (re, switch_body) in
          self#visit_expression env e
    end
  in
  (* Update the body *)
  let body = obj#visit_texpression () def.body in
  (* Return *)
  { def with body }

(** Apply all the micro-passes to a function.

    Will return `None` if the function is a backward function with no outputs.

    [ctx]: used only for printing.
 *)
let apply_passes_to_def (config : config) (ctx : trans_ctx) (def : fun_def) :
    fun_def option =
  (* Debug *)
  log#ldebug
    (lazy
      ("PureMicroPasses.apply_passes_to_def: "
      ^ Print.name_to_string def.basename
      ^ " ("
      ^ Print.option_to_string T.RegionGroupId.to_string def.back_id
      ^ ")"));

  (* First, find names for the variables which are unnamed *)
  let def = compute_pretty_names def in
  log#ldebug
    (lazy ("compute_pretty_name:\n\n" ^ fun_def_to_string ctx def ^ "\n"));

  (* TODO: we might want to leverage more the assignment meta-data, for
   * aggregates for instance. *)

  (* TODO: reorder the branches of the matches/switches *)

  (* The meta-information is now useless: remove it *)
  let def = remove_meta def in
  log#ldebug (lazy ("remove_meta:\n\n" ^ fun_def_to_string ctx def ^ "\n"));

  (* Remove the backward functions with no outputs.
   * Note that the calls to those functions should already have been removed,
   * when translating from symbolic to pure. Here, we remove the definitions
   * altogether, because they are now useless *)
  let def = filter_if_backward_with_no_outputs config def in

  match def with
  | None -> None
  | Some def ->
      (* Add unit arguments for functions with no arguments, and change their return type.
       * **Rk.**: from now onwards, the types in the AST are correct (until now,
       * functions had return type `t` where they should have return type `result t`).
       * Also, from now onwards, the outputs list has length 1. x*)
      let def = to_monadic config.add_unit_args def in
      log#ldebug (lazy ("to_monadic:\n\n" ^ fun_def_to_string ctx def ^ "\n"));

      (* Convert the unit variables to `()` if they are used as right-values or
       * `_` if they are used as left values. *)
      let def = unit_vars_to_unit def in
      log#ldebug
        (lazy ("unit_vars_to_unit:\n\n" ^ fun_def_to_string ctx def ^ "\n"));

      (* Inline the useless variable reassignments *)
      let inline_named_vars = true in
      let def = inline_useless_var_reassignments inline_named_vars def in
      log#ldebug
        (lazy
          ("inline_useless_var_assignments:\n\n" ^ fun_def_to_string ctx def
         ^ "\n"));

      (* Eliminate the box functions *)
      let def = eliminate_box_functions ctx def in
      log#ldebug
        (lazy
          ("eliminate_box_functions:\n\n" ^ fun_def_to_string ctx def ^ "\n"));

      (* Filter the useless variables, assignments, function calls, etc. *)
      let def = filter_useless config.filter_useless_monadic_calls ctx def in
      log#ldebug
        (lazy ("filter_useless:\n\n" ^ fun_def_to_string ctx def ^ "\n"));

      (* Decompose the monadic let-bindings *)
      let def =
        if config.decompose_monadic_let_bindings then (
          let def = decompose_monadic_let_bindings ctx def in
          log#ldebug
            (lazy
              ("decompose_monadic_let_bindings:\n\n" ^ fun_def_to_string ctx def
             ^ "\n"));
          def)
        else (
          log#ldebug
            (lazy
              "ignoring decompose_monadic_let_bindings due to the configuration\n");
          def)
      in

      (* Unfold the monadic let-bindings *)
      let def =
        if config.unfold_monadic_let_bindings then (
          let def = unfold_monadic_let_bindings ctx def in
          log#ldebug
            (lazy
              ("unfold_monadic_let_bindings:\n\n" ^ fun_def_to_string ctx def
             ^ "\n"));
          def)
        else (
          log#ldebug
            (lazy
              "ignoring unfold_monadic_let_bindings due to the configuration\n");
          def)
      in

      (* We are done *)
      Some def

(** Return the forward/backward translations on which we applied the micro-passes.

    Also returns a boolean indicating whether the forward function should be kept
    or not (because useful/useless - `true` means we need to keep the forward
    function).
    Note that we don't "filter" the forward function and return a boolean instead,
    because this function contains useful information to extract the backward
    functions: keeping it is not necessary but more convenient.
 *)
let apply_passes_to_pure_fun_translation (config : config) (ctx : trans_ctx)
    (trans : pure_fun_translation) : bool * pure_fun_translation =
  (* Apply the passes to the individual functions *)
  let forward, backwards = trans in
  let forward = Option.get (apply_passes_to_def config ctx forward) in
  let backwards = List.filter_map (apply_passes_to_def config ctx) backwards in
  let trans = (forward, backwards) in
  (* Compute whether we need to filter the forward function or not *)
  (keep_forward config trans, trans)
