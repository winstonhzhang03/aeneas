(** This files contains passes we apply on the AST *before* calling the
    (concrete/symbolic) interpreter on it
 *)

open Types
open Expressions
open LlbcAst
open Utils
open LlbcAstUtils
open Errors

let log = Logging.pre_passes_log

(** Rustc inserts a lot of drops before the assignments.

    We consider those drops are part of the assignment, and splitting the
    drop and the assignment is problematic for us because it can introduce
    [⊥] under borrows. For instance, we encountered situations like the
    following one:
    
    {[
      drop( *x ); // Illegal! Inserts a ⊥ under a borrow
      *x = move ...;
    ]}

    Rem.: we don't use this anymore
 *)
let filter_drop_assigns (f : fun_decl) : fun_decl =
  (* The visitor *)
  let obj =
    object (self)
      inherit [_] map_statement as super

      method! visit_Sequence env st1 st2 =
        match (st1.content, st2.content) with
        | Drop p1, Assign (p2, _) ->
            if p1 = p2 then (self#visit_statement env st2).content
            else super#visit_Sequence env st1 st2
        | Drop p1, Sequence ({ content = Assign (p2, _); _ }, _) ->
            if p1 = p2 then (self#visit_statement env st2).content
            else super#visit_Sequence env st1 st2
        | _ -> super#visit_Sequence env st1 st2
    end
  in
  (* Map  *)
  let body =
    match f.body with
    | Some body -> Some { body with body = obj#visit_statement () body.body }
    | None -> None
  in
  { f with body }

(** This pass slightly restructures the control-flow to remove the need to
    merge branches during the symbolic execution in some quite common cases
    where doing a merge is actually not necessary and leads to an ugly translation.

    TODO: this is useless

    For instance, it performs the following transformation:
    {[
      if b {
          var@0 := &mut *x;
      }
      else {
          var@0 := move y;
      }
      return;

      ~~>

      if b {
          var@0 := &mut *x;
          return;
      }
      else {
          var@0 := move y;
          return;
      }
    ]}

    This way, the translated body doesn't have an intermediate assignment,
    for the `if ... then ... else ...` expression (together with a backward
    function).

    More precisly, we move (and duplicate) a statement happening after a branching
    inside the branches if:
    - this statement ends with [return] or [panic]
    - this statement is only made of a sequence of nops, assignments (with some
      restrictions on the rvalue), fake reads, drops (usually, returns will be
      followed by such statements)
 *)
let remove_useless_cf_merges (crate : crate) (f : fun_decl) : fun_decl =
  let f0 = f in
  (* Return [true] if the statement can be moved inside the branches of a switch.
   *
   * [must_end_with_exit]: we need this boolean because the inner statements
   * (inside the encountered sequences) don't need to end with [return] or [panic],
   * but all the paths inside the whole statement have to.
   * *)
  let rec can_be_moved_aux (must_end_with_exit : bool) (st : statement) : bool =
    match st.content with
    | SetDiscriminant _
    | Assert _
    | Call _
    | Break _
    | Continue _
    | Switch _
    | Loop _
    | Error _ -> false
    | Assign (_, rv) -> (
        match rv with
        | Use _ | RvRef _ -> not must_end_with_exit
        | Aggregate (AggregatedAdt (TTuple, _, _, _), []) ->
            not must_end_with_exit
        | _ -> false)
    | FakeRead _ | Drop _ | Nop -> not must_end_with_exit
    | Abort _ | Return -> true
    | Sequence (st1, st2) ->
        can_be_moved_aux false st1 && can_be_moved_aux must_end_with_exit st2
  in
  let can_be_moved = can_be_moved_aux true in

  (* The visitor *)
  let obj =
    object
      inherit [_] map_statement as super

      method! visit_Sequence env st1 st2 =
        match st1.content with
        | Switch switch ->
            if can_be_moved st2 then
              super#visit_Switch env (chain_statements_in_switch switch st2)
            else super#visit_Sequence env st1 st2
        | _ -> super#visit_Sequence env st1 st2
    end
  in

  (* Map  *)
  let body =
    match f.body with
    | Some body -> Some { body with body = obj#visit_statement () body.body }
    | None -> None
  in
  let f = { f with body } in
  log#ldebug
    (lazy
      ("Before/after [remove_useless_cf_merges]:\n"
      ^ Print.Crate.crate_fun_decl_to_string crate f0
      ^ "\n\n"
      ^ Print.Crate.crate_fun_decl_to_string crate f
      ^ "\n"));
  f

(** This pass restructures the control-flow by inserting all the statements
    which occur after loops *inside* the loops, thus removing the need to
    have breaks (we later check that we removed all the breaks).

    This is needed because of the way we perform the symbolic execution
    on the loops for now.

    Rem.: we check that there are no nested loops (all the breaks must break
    to the first outer loop, and the statements we insert inside the loops
    mustn't contain breaks themselves).

    For instance, it performs the following transformation:
    {[
      loop {
        if b {
          ...
          continue 0;
        }
        else {
          ...
          break 0;
        }
      };
      x := x + 1;
      return;

      ~~>

      loop {
        if b {
          ...
          continue 0;
        }
        else {
          ...
          x := x + 1;
          return;
        }
      };
    ]}

    We also insert the statements occurring after branchings (matches or
    if then else) inside the branches. For instance:
    {[
      if b {
        s0;
      }
      else {
        s1;
      }
      return;

        ~~>

      if b {
        s0;
        return;
      }
      else {
        s1;
        return;
      }
    ]}

    This is necessary because loops might appear inside branchings: if we don't
    do this some paths inside the loop might not end with a break/continue/return.Aeneas
  *)
let remove_loop_breaks (crate : crate) (f : fun_decl) : fun_decl =
  let f0 = f in

  (* Check that a statement doesn't contain loops, breaks or continues *)
  let statement_has_no_loop_break_continue (st : statement) : bool =
    let obj =
      object
        inherit [_] iter_statement
        method! visit_Loop _ _ = raise Found
        method! visit_Break _ _ = raise Found
        method! visit_Continue _ _ = raise Found
      end
    in
    try
      obj#visit_statement () st;
      true
    with Found -> false
  in

  (* Replace a break statement with another statement (we check that the
     break statement breaks exactly one level, and that there are no nested
     loops.
  *)
  let replace_breaks_with (st : statement) (nst : statement) : statement =
    let obj =
      object
        inherit [_] map_statement as super

        method! visit_statement entered_loop st =
          match st.content with
          | Loop loop ->
              cassert __FILE__ __LINE__ (not entered_loop) st.span
                "Nested loops are not supported yet";
              { st with content = super#visit_Loop true loop }
          | Break i ->
              cassert __FILE__ __LINE__ (i = 0) st.span
                "Breaks to outer loops are not supported yet";
              {
                st with
                content = nst.content;
                comments_before = st.comments_before @ nst.comments_before;
              }
          | _ -> super#visit_statement entered_loop st
      end
    in
    obj#visit_statement false st
  in

  (* The visitor *)
  let replace_visitor =
    object
      inherit [_] map_statement as super

      method! visit_statement env st =
        match st.content with
        | Sequence (st1, st2) -> begin
            match st1.content with
            | Loop _ ->
                cassert __FILE__ __LINE__
                  (statement_has_no_loop_break_continue st2)
                  st2.span "Sequences of loops are not supported yet";
                super#visit_statement env (replace_breaks_with st st2)
            | Switch _ ->
                (* This pushes st2 inside of the switch *)
                super#visit_statement env (chain_statements st1 st2)
            | _ -> super#visit_statement env st
          end
        | _ -> super#visit_statement env st
    end
  in

  (* Map  *)
  let body =
    match f.body with
    | Some body ->
        Some { body with body = replace_visitor#visit_statement () body.body }
    | None -> None
  in

  let f = { f with body } in
  log#ldebug
    (lazy
      ("Before/after [remove_loop_breaks]:\n"
      ^ Print.Crate.crate_fun_decl_to_string crate f0
      ^ "\n\n"
      ^ Print.Crate.crate_fun_decl_to_string crate f
      ^ "\n"));
  f

(** Remove the use of shallow borrows from a function.

    In theory, this allows the code to do more things than what Rust allows,
    and in particular it would allow to modify the variant of an enumeration
    in a guard, while matching over this enumeration.

    In practice, this is not a soundness issue.

    **Soundness**:
    ==============
    For instance, let's consider the following Rust code:
    {[
      match ls : &mut List<u32> {
        Nil => return None,
        Cons(hd, tl) if *hd > 0 => return Some(hd),
        Cons(hd, tl) => ...,
      }
    ]}

    The Rust compiler enforces the fact that the guard doesn't modify the
    variant of [ls]. It does so by compiling to (approximately) the following
    MIR code:
    {[
      let d = discriminant( *ls);
      switch d {
        0 => ... // Nil case
        1 => { // Cons case
          // Introduce hd and tl
          hd := &mut ( *ls as Cons).0;
          tl := &mut ( *ls as Cons).1;

          // Evaluate the guard
          tmp := &shallow *ls; // Create a shallow borrow of ls
          b := *hd > 0;
          fake_read(tmp); // Make sure the shallow borrow lives until the end of the guard

          // We evaluated the guard: go to the proper branch
          if b then {
            ... // First Cons branch
          }
          else {
            ... // Second Cons branch
          }
        }
      }
    ]}

    Shallow borrows are a bit like shared borrows but with the following
    difference:
    - they do forbid modifying the value directly below the loan
    - but they allow modifying a strict subvalue
    For instance, above, for as long as [tmp] lives:
    - we can't change the variant of [*ls]
    - but we can update [hd] and [tl]

    On our side, we have to pay attention to two things:
    - Removing shallow borrows don't modify the behavior of the program.
      In practice, adding shallow borrows can lead to a MIR program being
      rejected, but it doesn't change this program's behavior.

      Regarding this, there is something important. At the top-level AST,
      if the guard modifies the variant (say, to [Nil]) and evaluates to [false],
      then we go to the second [Cons] branch, which doesn't really make sense
      (though it is not a soundness issue - for soundness, see next point).

      At the level of MIR, as the match has been desugared, there is no issue
      in modifying the variant of the scrutinee.

    - We have to make sure the evaluation in sound. In particular, modifying
      the variant of [*ls] should invalidate [hd] and [tl]. This is important
      for the Rust compiler to enforce this on its side. In the case of LLBC,
      we don't need additional constraints because modifying [*ls] will
      indeed invalidate [hd] and [tl].

      More specifically, at the beginning of the [Cons] branch and just after
      we introduced [hd] and [tl] we have the following environment:
      {[
        ... // l0 comes from somewhere - we omit the corresponding loan
        ls -> MB l0 (Cons (ML l1) (ML l2))
        hd -> MB l1 s1
        tl -> MB l2 s2
      ]}

      If we evaluate: [*ls := Nil], we get:
      {[
        ... // l0 comes from somewhere - we omit the corresponding loan
        ls -> MB l0 Nil
        hd -> ⊥ // invalidated
        tl -> ⊥ // invalidated
      ]}

    **Implementation**:
    ===================
    The pass is implemented as follows:
    - we look for all the variables which appear in pattern of the following
      shape and remove them:
      {[
        let x = &shallow ...;
        ...
      ]}
    - whenever we find such a variable [x], we remove all the subsequent
      occurrences of [fake_read(x)].

    We then check that [x] completely disappeared from the function body (for
    sanity).
 *)
let remove_shallow_borrows (crate : crate) (f : fun_decl) : fun_decl =
  let f0 = f in
  let filter_in_body (body : statement) : statement =
    let filtered = ref VarId.Set.empty in

    let filter_visitor =
      object
        inherit [_] map_statement as super

        method! visit_Assign env p rv =
          match (p.kind, rv) with
          | PlaceBase var_id, RvRef (_, BShallow) ->
              (* Filter *)
              filtered := VarId.Set.add var_id !filtered;
              Nop
          | _ ->
              (* Don't filter *)
              super#visit_Assign env p rv

        method! visit_FakeRead env p =
          match p.kind with
          | PlaceBase var_id when VarId.Set.mem var_id !filtered ->
              (* filter *)
              Nop
          | _ ->
              (* Don't filter *)
              super#visit_FakeRead env p
      end
    in

    (* Filter the variables *)
    let body = filter_visitor#visit_statement () body in

    (* Check that the filtered variables completely disappeared from the body *)
    let check_visitor =
      object
        inherit [_] iter_statement as super

        (* Remember the span of the statement we enter *)
        method! visit_statement _ st = super#visit_statement st.span st

        method! visit_var_id span id =
          cassert __FILE__ __LINE__
            (not (VarId.Set.mem id !filtered))
            span
            "Filtered variables should have completely disappeared from the \
             body"
      end
    in
    check_visitor#visit_statement body.span body;

    (* Return the updated body *)
    body
  in

  let body =
    match f.body with
    | None -> None
    | Some body -> Some { body with body = filter_in_body body.body }
  in
  let f = { f with body } in
  log#ldebug
    (lazy
      ("Before/after [remove_shallow_borrows]:\n"
      ^ Print.Crate.crate_fun_decl_to_string crate f0
      ^ "\n\n"
      ^ Print.Crate.crate_fun_decl_to_string crate f
      ^ "\n"));
  f

(* Remove the type aliases from the type declarations and declaration groups *)
let filter_type_aliases (crate : crate) : crate =
  let type_decl_is_alias (ty : type_decl) =
    match ty.kind with
    | Alias _ -> true
    | _ -> false
  in
  (* Whether the declaration group has a single entry that is a type alias.
     Type aliases should not be in recursive groups so we also ensure this doesn't
     happen. *)
  let decl_group_is_single_alias = function
    | TypeGroup (NonRecGroup id) ->
        type_decl_is_alias (TypeDeclId.Map.find id crate.type_decls)
    | TypeGroup (RecGroup ids) ->
        List.iter
          (fun id ->
            let ty = TypeDeclId.Map.find id crate.type_decls in
            if type_decl_is_alias ty then
              craise __FILE__ __LINE__ ty.item_meta.span
                "found a type alias within a recursive group; this is \
                 unexpected")
          ids;
        false
    | _ -> false
  in
  {
    crate with
    type_decls =
      TypeDeclId.Map.filter
        (fun _id ty -> not (type_decl_is_alias ty))
        crate.type_decls;
    declarations =
      List.filter
        (fun decl -> not (decl_group_is_single_alias decl))
        crate.declarations;
  }

(** Whenever we write a string literal in Rust, rustc actually
    introduces a constant of type [&str].
    Generally speaking, because [str] is unsized, it doesn't
    make sense to manipulate values of type [str] directly.
    But in the context of Aeneas, it is reasonable to decompose
    those literals into: a string stored in a local variable,
    then a borrow of this variable.
 *)
let decompose_str_borrows (f : fun_decl) : fun_decl =
  (* Map  *)
  let body =
    match f.body with
    | Some body ->
        let new_locals = ref [] in
        let _, gen =
          VarId.mk_stateful_generator_starting_at_id
            (VarId.of_int (List.length body.locals.vars))
        in
        let fresh_local ty =
          let local = { index = gen (); var_ty = ty; name = None } in
          new_locals := local :: !new_locals;
          local.index
        in

        (* Function to decompose a constant literal *)
        let decompose_rvalue (span : Meta.span) (lv : place) (rv : rvalue)
            (next : statement option) : raw_statement =
          let new_statements = ref [] in

          (* Visit the rvalue *)
          let visitor =
            object
              inherit [_] map_statement as super

              (* We have to visit all the constant operands.
                 As we might need to replace them with borrows, while borrows
                 are rvalues (i.e., not operands) we have to introduce two
                 intermediate statements: the string initialization, then
                 the borrow, that we can finally move.
              *)
              method! visit_Constant env cv =
                match (cv.value, cv.ty) with
                | ( CLiteral (VStr str),
                    TRef (_, (TAdt (TBuiltin TStr, _) as str_ty), ref_kind) ) ->
                    (* We need to introduce intermediate assignments *)
                    (* First the string initialization *)
                    let local_id =
                      let local_id = fresh_local str_ty in
                      let new_cv : constant_expr =
                        { value = CLiteral (VStr str); ty = str_ty }
                      in
                      let st =
                        {
                          span;
                          content =
                            Assign
                              ( { kind = PlaceBase local_id; ty = str_ty },
                                Use (Constant new_cv) );
                          comments_before = [];
                        }
                      in
                      new_statements := st :: !new_statements;
                      local_id
                    in
                    (* Then the borrow *)
                    let local_id =
                      let nlocal_id = fresh_local cv.ty in
                      let bkind =
                        match ref_kind with
                        | RMut -> BMut
                        | RShared -> BShared
                      in
                      let rv =
                        RvRef ({ kind = PlaceBase local_id; ty = str_ty }, bkind)
                      in
                      let lv = { kind = PlaceBase nlocal_id; ty = cv.ty } in
                      let st =
                        {
                          span;
                          content = Assign (lv, rv);
                          comments_before = [];
                        }
                      in
                      new_statements := st :: !new_statements;
                      nlocal_id
                    in
                    (* Finally we can move the value *)
                    Move { kind = PlaceBase local_id; ty = cv.ty }
                | _ -> super#visit_Constant env cv
            end
          in

          let rv = visitor#visit_rvalue () rv in

          (* Construct the sequence *)
          let assign =
            { span; content = Assign (lv, rv); comments_before = [] }
          in
          let statements, last =
            match next with
            | None -> (!new_statements, assign)
            | Some st -> (assign :: !new_statements, st)
          in
          (* Note that the new statements are in reverse order *)
          (List.fold_left
             (fun st nst ->
               { span; content = Sequence (nst, st); comments_before = [] })
             last statements)
            .content
        in

        (* Visit all the statements and decompose the literals *)
        let visitor =
          object
            inherit [_] map_statement as super
            method! visit_statement _ st = super#visit_statement st.span st

            method! visit_Sequence span st1 st2 =
              match st1.content with
              | Assign (lv, rv) -> decompose_rvalue st1.span lv rv (Some st2)
              | _ -> super#visit_Sequence span st1 st2

            method! visit_Assign span lv rv = decompose_rvalue span lv rv None
          end
        in

        let body_body = visitor#visit_statement body.body.span body.body in
        Some
          {
            body with
            body = body_body;
            locals =
              {
                body.locals with
                vars = body.locals.vars @ List.rev !new_locals;
              };
          }
    | None -> None
  in
  { f with body }

let apply_passes (crate : crate) : crate =
  let function_passes =
    [
      remove_loop_breaks crate;
      remove_shallow_borrows crate;
      decompose_str_borrows;
    ]
  in
  (* Attempt to apply a pass: if it fails we replace the body by [None] *)
  let apply_function_pass (pass : fun_decl -> fun_decl) (f : fun_decl) =
    try pass f
    with CFailure _ ->
      (* The error was already registered, we don't need to register it twice.
         However, we replace the body of the function, and save an error to
         report to the user the fact that we will ignore the function body *)
      let fmt = Print.Crate.crate_to_fmt_env crate in
      let name = Print.name_to_string fmt f.item_meta.name in
      save_error __FILE__ __LINE__ f.item_meta.span
        ("Ignoring the body of '" ^ name ^ "' because of previous error");
      { f with body = None }
  in
  let fun_decls =
    List.fold_left
      (fun fl pass -> FunDeclId.Map.map (apply_function_pass pass) fl)
      crate.fun_decls function_passes
  in
  let crate = { crate with fun_decls } in
  let crate = filter_type_aliases crate in
  log#ldebug
    (lazy ("After pre-passes:\n" ^ Print.Crate.crate_to_string crate ^ "\n"));
  crate
