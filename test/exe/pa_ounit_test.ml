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
