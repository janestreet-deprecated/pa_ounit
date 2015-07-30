(* Generated code should depend on the environment in scope as little as
   possible.  E.g. rather than [foo = []] do [match foo with [] ->], to eliminate the
   use of [=].  It is especially important to not use polymorphic comparisons, since we
   are moving more and more to code that doesn't have them in scope. *)


let libname = ref None
let drop_tests : [`No | `Deadcode | `Remove ] ref = ref `No
let () =
  (* Beware that camlp4 has a broken command line parser and using the flag
     -ounit-ident will not work, because camlp4 will interpret that as
     -o unit-ident and so the standard output of your preprocessor will be empty.
     Of course, there is no special case for -o, it is also a problem with any other
     flag. And of course you have no warning whatsoever. *)
  Camlp4.Options.add "-pa-ounit-lib" (Arg.String (fun s -> libname := Some s))
    "A base name to use for generated identifiers\
     (has to be globally unique in a program).";
  Camlp4.Options.add "-pa-ounit-drop"
    (Arg.Unit (fun () -> drop_tests:= `Remove))
    "Drop unit tests";
  Camlp4.Options.add "-pa-ounit-drop-with-deadcode"
    (Arg.Unit (fun () -> drop_tests:= `Deadcode))
    "Drop unit tests by wrapping them inside deadcode to prevent unused variable warnings."

open Camlp4.PreCast

let maybe_drop _loc expr =
  match !drop_tests with
  | `No       -> <:str_item< value () = $expr$; >>
  | `Deadcode -> <:str_item< value () = if False then $expr$ else (); >>
  | `Remove   -> <:str_item< >>

let libname () =
  match !libname with
  | None -> "dummy" (* would break for the external tree if I gave an error, I think *)
  | Some name -> name

(* To allow us to validate the migration to ppx, we need to modify the [string_of_expr]
   which is used for message strings, to use the ocaml compiler Ast printer - which is
   what the ppx version uses.

   This was the original definition of: [string_of_expr]

      let syntax_printer =
        let module PP = Camlp4.Printers.OCaml.Make (Syntax) in
        new PP.printer ~comments:false ()

      let string_of_expr expr =
        let buffer = Buffer.create 16 in
        Format.bprintf buffer "%a%!" syntax_printer#expr expr;
        Buffer.contents buffer
*)

let string_of_expr (expr: Ast.expr) : string = (* via ocaml AST *)
  let module Convert = Camlp4.Struct.Camlp4Ast2OCamlAst.Make (Ast) in
  (* The call to [Convert.str_item] may (incredibly!) mutate float strings contained in
     the AST, so we map the AST first, copying the float strings... *)
  let copy_floats_in_expr = object
    inherit Ast.map as super
    method! expr x =
      match super#expr x with
      | ExFlo (loc,string) -> ExFlo (loc,String.copy string)
      | e -> e
  end in
  let expr = copy_floats_in_expr#expr expr in
  let str : Ast.str_item = StExp (Ast.loc_of_expr expr,expr) in
  match (Convert.str_item str) with
    | [{pstr_desc = Pstr_eval (e,_); _}] -> Pprintast.string_of_expression e
    | _ -> assert false

let rec short_desc_of_expr ~max_len = function
  | <:expr< let $_$ in $e$ >>
  | <:expr< let rec $_$ in $e$ >>
  | <:expr< let module $_$ = $_$ in $e$ >> ->
    short_desc_of_expr ~max_len e
  | e ->
    let s = string_of_expr e in
    let res =
      if String.length s >= max_len then
        let s_short = String.sub s 0 (max_len - 5) in
        s_short ^ "[...]"
      else s in
    for i = 0 to String.length res -1 do
      if res.[i] = '\n' then
        res.[i] <- ' '
    done;
    res

let descr _loc e_opt id_opt =
  let filename = Loc.file_name _loc in
  let line = Loc.start_line _loc in
  let start_pos = Loc.start_off _loc - Loc.start_bol _loc in
  let end_pos = Loc.stop_off _loc - Loc.start_bol _loc in
  let descr =
    match id_opt, e_opt with
    | None, None -> ""
    | None, Some e -> ": <<" ^ String.escaped (short_desc_of_expr ~max_len:50 e) ^ ">>"
    | Some id, _ -> ": " ^ id in
   <:expr< $str:descr$ >>,
   <:expr< $str:filename$ >>,
   <:expr< $int:string_of_int line$ >>,
   <:expr< $int:string_of_int start_pos$ >>,
   <:expr< $int:string_of_int end_pos$ >>

let apply_to_descr lid _loc e_opt id_opt more_arg =
  let descr, filename, line, start_pos, end_pos = descr _loc e_opt id_opt in
  maybe_drop _loc
    <:expr<
      Pa_ounit_lib.Runtime.$lid:lid$ $descr$ $filename$ $line$ $start_pos$ $end_pos$
        $more_arg$
    >>

EXTEND Gram
  GLOBAL: Syntax.str_item;
  Syntax.str_item:
    [[
      "TEST"; id = OPT Syntax.a_STRING; "=" ; e = Syntax.expr ->
      apply_to_descr "test" _loc (Some e) id <:expr< fun () -> $e$ >>
    | "TEST_UNIT"; id = OPT Syntax.a_STRING; "=" ; e = Syntax.expr ->
      apply_to_descr "test_unit" _loc (Some e) id <:expr< fun () -> $e$ >>
    | "TEST_MODULE"; id = OPT Syntax.a_STRING ; "=" ; expr = Syntax.module_expr ->
      apply_to_descr "test_module" _loc None id <:expr< fun () -> let module M = $expr$ in () >>
    ]];
END

let () =
  let current_str_parser, _ = Camlp4.Register.current_parser () in
  Camlp4.Register.register_str_item_parser (fun ?directive_handler _loc stream ->
    let ml = current_str_parser ?directive_handler _loc stream in
    <:str_item<
      $maybe_drop _loc <:expr<Pa_ounit_lib.Runtime.set_lib $str:libname ()$>>$;
      $ml$;
      $maybe_drop _loc <:expr<Pa_ounit_lib.Runtime.unset_lib $str:libname ()$>>$;
    >>
  )
