type descr = string
let test_modules_ran = ref 0
let test_modules_failed = ref 0
let tests_ran = ref 0
let tests_failed = ref 0
let dynamic_lib : string option ref = ref None
type filename = string
type line_number = int
let action : [
| `Ignore
| `Run_lib of string * (filename * line_number option * bool ref) list
| `Collect of OUnit.test list ref
] ref = ref `Ignore
let module_descr = ref []
let strict = ref false
let display = ref false
let log = ref None

let () =
  match Array.to_list Sys.argv with
  | name :: "inline-test-runner" :: lib :: rest -> begin
    (* when we see this argument, we switch to test mode *)
    let tests = ref [] in
    Arg.parse_argv (Array.of_list (name :: rest)) [
      "-strict", Arg.Set strict, " End with an error if no tests were run";
      "-display", Arg.Set display, " Show the number of tests ran";
      "-log", Arg.Unit (fun () ->
        (try Sys.remove "inline_tests.log" with _ -> ());
        log := Some (open_out "inline_tests.log")
      ), " Log the tests run";
      "-only-test", Arg.String (fun s ->
        try
        let filename, index =
          if String.contains s ':' then
            let i = String.index s ':' in
            let filename = String.sub s 0 i in
            let index = int_of_string (String.sub s (i + 1) (String.length s - i - 1)) in
            filename, Some index
          else
            s, None
        in
        tests := (filename, index, ref false) :: !tests
        with Invalid_argument _ | Failure _ ->
          failwith (Printf.sprintf " Argument %s doesn't fit the format filename[:line_number]" s)
        ), " Run only the tests specified by all the -only-test options";
    ] (fun anon ->
      failwith (Printf.sprintf "Unexpected anonymous argument %s" anon)
    ) (Printf.sprintf "%s %s %s [args]" name "inline-test-runner" lib);
    action := `Run_lib (lib, !tests)
    end
  | _ ->
    ()

let with_descr (descr : descr) f =
  let prev = !module_descr in
  module_descr := descr :: prev;
  try
    f ();
    module_descr := prev;
  with e ->
    module_descr := prev;
    raise e

let string_of_module_descr () =
  String.concat "" (
    List.map (fun s -> "  in TES" ^ "T_MODULE at " ^ s ^ "\n") !module_descr
  )

let position_match def_filename def_line_number l =
  List.exists (fun (filename, line_number_opt, used) ->
    let position_start =
      String.length def_filename - String.length filename in
    let found =
      position_start >= 0 &&
        let end_of_def_filename =
          String.sub def_filename
            position_start
            (String.length filename) in
        end_of_def_filename = filename
        && (position_start = 0 || def_filename.[position_start - 1] = '/')
        && (match line_number_opt with
            | None -> true
            | Some line_number -> def_line_number = line_number)
    in
    if found then used := true;
    found
  ) l

let test (descr : descr) def_filename def_line_number f =
  match !action with
  | `Run_lib (lib, l) ->
    let should_run =
      Some lib = !dynamic_lib
      && begin match l with
      | [] -> true
      | _ :: _ -> position_match def_filename def_line_number l
      end in
    if should_run then begin
      incr tests_ran;
      begin match !log with
      | None -> ()
      | Some ch -> Printf.fprintf ch "%s\n%s" descr (string_of_module_descr ())
      end;
      try
        if not (f ()) then begin
          incr tests_failed;
          Printf.eprintf "%s is false.\n%s" descr
            (string_of_module_descr ())
        end
      with exn ->
        let backtrace = Printexc.get_backtrace () in
        incr tests_failed;
        Printf.eprintf "%s threw %s.\n%s%s" descr (Printexc.to_string exn)
          backtrace (string_of_module_descr ())
    end
  | `Ignore -> ()
  | `Collect r ->
    r := OUnit.TestCase (fun () ->
      if not (f ()) then failwith descr
    ) :: !r


let set_lib static_lib =
  match !dynamic_lib with
  | None -> dynamic_lib := Some static_lib
  | Some _ -> ()
    (* possible if the interface is used explicitely or if we happen to dynlink something
       that contain tests *)

let unset_lib static_lib =
  match !dynamic_lib with
  | None ->
    (* not giving an error, because when some annoying people put pa_ounit in their list
       of preprocessors, pa_ounit is set up twice and we have two calls to unset_lib at
       the end of the file, and the second one comes in this branch *)
    ()
  | Some lib ->
    if lib = static_lib then dynamic_lib := None

let test_unit descr def_filename def_line_number f =
  test descr def_filename def_line_number (fun () -> f (); true)

let collect f =
  let prev_action = !action in
  let tests = ref [] in
  action := `Collect tests;
  try
    f ();
    let tests = List.rev !tests in
    action := prev_action;
    OUnit.TestList tests
  with e ->
    action := prev_action;
    raise e

let test_module descr _def_filename _def_line_number f =
  match !action with
  | `Run_lib (lib, _) ->
    (* run test_modules, in case they define the test we are looking for (if we are
       even looking for a test) *)
    if Some lib = !dynamic_lib then begin
      incr test_modules_ran;
      try
        with_descr descr f
      with exn ->
        let backtrace = Printexc.get_backtrace () in
        incr test_modules_failed;
        Printf.eprintf ("TES" ^^ "T_MODULE threw %s.\n%s%s") (Printexc.to_string exn)
          backtrace (string_of_module_descr ())
    end
  | `Ignore -> ()
  | `Collect r ->
    r := (
      (* tEST_MODULE are going to be executed inline, unlike before *)
      OUnit.TestLabel (descr, collect f)
    ) :: !r

let summarize () =
  begin match !log with
  | None -> ()
  | Some ch -> close_out ch
  end;
  match !tests_failed, !test_modules_failed with
  | 0, 0 -> begin
    if !display then begin
      Printf.eprintf "%d tests ran, %d test_modules ran\n" !tests_ran !test_modules_ran
    end;
    let errors =
      match !action with
      | `Run_lib (_, tests) ->
        let unused_tests =
          List.filter (fun (_, _, used) -> not !used) tests in
        begin match unused_tests with
        | [] -> None
        | _ :: _ -> Some unused_tests
        end
      | `Ignore
      | `Collect _ -> None in
    match errors with
    | Some tests ->
      Printf.eprintf "Pa_ounit error: the following -only-test flags matched nothing:";
      List.iter (fun (filename, line_number_opt, _) ->
        match line_number_opt with
        | None -> Printf.eprintf " %s" filename
        | Some line_number -> Printf.eprintf " %s:%d" filename line_number
      ) tests;
      Printf.eprintf ".\n";
      exit 1
    | None ->
      if !tests_ran = 0 && !strict then begin
        Printf.eprintf "Pa_ounit error: no tests have been run.\n";
        exit 1
      end;
      exit 0
  end
  | count, count_test_modules ->
    Printf.eprintf "FAILED %d / %d tests%s\n" count !tests_ran
      (if count_test_modules = 0 then "" else Printf.sprintf (", %d TES" ^^ "T_MODULES") count_test_modules);
    exit 2
