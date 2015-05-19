let () =
  match Sys.getenv "ENABLE_FAILURES" with
  | exception Not_found -> ()
  | (_ : string) ->
    let module M = struct
      TEST = false
      TEST = raise Exit
      TEST_MODULE "name" = struct
        TEST = false
        TEST = false
        TEST = raise Exit
        TEST_MODULE = struct
          let () = raise Exit
        end
      end
      TEST_MODULE = struct
        let () = raise Exit
      end
    end in
    ()
;;
