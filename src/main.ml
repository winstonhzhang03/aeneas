open CfimOfJson
open Logging
open Print
module T = Types
module A = CfimAst
module I = Interpreter
module EL = Easy_logging.Logging
module TA = TypesAnalysis
module P = Pure
open SymbolicAstUtils
open PrintSymbolicAst
open SymbolicToPure

(* This is necessary to have a backtrace when raising exceptions - for some
 * reason, the -g option doesn't work.
 * JP: are you running with OCAMLRUNPARAM=b=1? *)
let () = Printexc.record_backtrace true

let usage =
  Printf.sprintf
    {|Aenaes: verification of Rust programs by translation

Usage: %s [OPTIONS] FILE
|}
    Sys.argv.(0)

let () =
  (* Read the command line arguments *)
  let spec = [] in
  let spec = Arg.align spec in
  let filename = ref "" in
  let fail () =
    print_string usage;
    exit 1
  in
  Arg.parse spec
    (fun f ->
      if not (Filename.check_suffix f ".cfim") then (
        print_string "Unrecognized file extension";
        fail ())
      else if not (Sys.file_exists f) then (
        print_string "File not found";
        fail ())
      else filename := f)
    usage;
  if !filename = "" then (
    print_string usage;
    exit 1);
  (* Set up the logging - for now we use default values - TODO: use the
   * command-line arguments *)
  Easy_logging.Handlers.set_level main_logger_handler EL.Debug;
  main_log#set_level EL.Debug;
  interpreter_log#set_level EL.Debug;
  statements_log#set_level EL.Debug;
  paths_log#set_level EL.Debug;
  expressions_log#set_level EL.Debug;
  expansion_log#set_level EL.Debug;
  borrows_log#set_level EL.Debug;
  invariants_log#set_level EL.Warning;
  (* Load the module *)
  let json = Yojson.Basic.from_file !filename in
  match cfim_module_of_json json with
  | Error s -> main_log#error "error: %s\n" s
  | Ok m ->
      (* Print the module *)
      main_log#ldebug (lazy ("\n" ^ Print.Module.module_to_string m ^ "\n"));

      (* Some options for the execution *)
      let config =
        {
          C.check_invariants = true;
          greedy_expand_symbolics_with_borrows = false;
        }
      in

      (* Test the unit functions with the concrete interpreter *)
      I.Test.test_unit_functions config m;

      (* Evaluate the symbolic interpreter on the functions *)
      let synthesize = true in
      I.Test.test_functions_symbolic config synthesize m
