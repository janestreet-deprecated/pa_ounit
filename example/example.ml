open Core.Std

module type S = sig
  type t
  val zero : t
  val succ : t -> t
end

module type Cnt = sig
  type t
  val _incr : unit -> t
end

module Cnt(V:S) : Cnt with type t = V.t = struct
  type t = V.t
  let p = ref V.zero

  let _incr () =
    p := V.succ !p;
    !p

  TEST = (V.succ V.zero > V.zero);;
end

module C1 = Cnt(Int)
TEST_MODULE = Cnt(Int)
TEST_MODULE "description" = Cnt(Int)

TEST_MODULE = struct
  open List

  TEST = (group [] ~break:(fun _ -> assert false)) = []

  let mis = ['M';'i';'s';'s';'i';'s';'s';'i';'p';'p';'i']
  let equal_letters =
    [['M'];['i'];['s';'s'];['i'];['s';'s'];['i'];['p';'p'];['i']]
  let single_letters =
    [['M';'i';'s';'s';'i';'s';'s';'i';'p';'p';'i']]
  let every_three =
    [['M'; 'i'; 's']; ['s'; 'i'; 's']; ['s'; 'i'; 'p']; ['p'; 'i' ]]

  TEST = (group ~break:(<>) mis) = equal_letters
  TEST = (group ~break:(fun _ _ -> false) mis) = single_letters
  TEST = (groupi ~break:(fun i _ _ -> i mod 3 = 0) mis) = every_three

end
