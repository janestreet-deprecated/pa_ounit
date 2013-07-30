(* Generated code should depend on the environment in scope as little as
   possible.  E.g. rather than [foo = []] do [match foo with [] ->], to eliminate the
   use of [=].  It is especially important to not use polymorphic comparisons, since we
   are moving more and more to code that doesn't have them in scope. *)


let libname = ref None
let () =
  (* Beware that camlp4 has a broken command line parser and using the flag
     -ounit-ident will not work, because camlp4 will interpret that as
     -o unit-ident and so the standard output of your preprocessor will be empty.
     Of course, there is no special case for -o, it is also a problem with any other
     flag. And of course you have no warning whatsoever. *)
  Camlp4.Options.add "-pa-ounit-lib" (Arg.String (fun s -> libname := Some s))
  "A base name to use for generated identifiers (has to be globally unique in a program)."

open Camlp4.PreCast

let libname () =
  match !libname with
  | None -> "dummy" (* would break for the external tree if I gave an error, I think *)
  | Some name -> name

let syntax_printer =
  let module PP = Camlp4.Printers.OCaml.Make (Syntax) in
  new PP.printer ~comments:false ()

let string_of_expr expr =
  let buffer = Buffer.create 16 in
  Format.bprintf buffer "%a%!" syntax_printer#expr expr;
  Buffer.contents buffer

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
  <:str_item<
    value () =
      Pa_ounit_lib.Runtime.$lid:lid$ $descr$ $filename$ $line$ $start_pos$ $end_pos$
        $more_arg$;
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
      value () = Pa_ounit_lib.Runtime.set_lib $str:libname ()$;
      $ml$;
      value () = Pa_ounit_lib.Runtime.unset_lib $str:libname ()$;
    >>
  )
