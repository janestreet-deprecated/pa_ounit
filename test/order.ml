(* checking that the execution order is right *)

let count = ref 0
let check i =
  assert (!count = i);
  incr count

module F(X : sig val start : int end) = struct
  let () = check X.start
  TEST_UNIT = check (X.start + 1)
  let () = check (X.start + 2)
end

let () = check 0
TEST_UNIT = check 1
let () = check 2
TEST = check 3; true
let () = check 4

TEST_MODULE = struct
  let () = check 5
  TEST_UNIT = check 6
  let () = check 7
  TEST = check 8; true
  TEST_MODULE = struct
    let () = check 9
    module M = F(struct let start = 10 end)
    let () = check 13
  end
  module M = F(struct let start = 14 end)
  let () = check 17
end

let () = check 18

(* let f _ = raise Exit
 * let rec g x = let _ = g in f x + 1
 * let rec h x = let _ = h in g x + 1
 * let rec i x = let _ = i in h x + 1
 * TEST_MODULE "a" = struct
 *   TEST_MODULE "b" = struct
 *     TEST = i 0 = 0
 *   end
 * end *)

(* TEST_MODULE "A" = struct
 *   TEST_MODULE "B" = struct
 *     TEST_MODULE "C" = struct
 *       TEST "D" = false
 *     end
 *   end
 * end *)
(*TEST_MODULE = struct
  TEST_UNIT = raise Exit
end*)
