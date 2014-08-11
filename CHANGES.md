## 111.28.00

- Added a flag to disable embedding of unit tests/inline benchmarks.
  (`janestreet/core_kernel#13`)

## 109.53.00

- Bump version number

## 109.52.00

- Added `-stop-on-error` flag to `inline_test_runner`, to stop running
  tests at the first failure.

    This is useful if the remaining tests are likely to fail too or just
    long to run.

## 109.36.00

- Simplified so that it does not generate unnecessary top-level bindings.

    It had been hiding quite a few `unused import` warnings.

## 109.27.00

- Removed comments from test names displayed by `pa_ounit`.

    Before:
    ```
    File "iobuf.ml", line 141, characters 0-34: <<(** WHEN YOU CHANGE THIS, CHANGE iobuf_fields `...`>> threw ("Iobuf.create got nonpositive len" 0).
    ```

    After:
    ```
    File "iobuf.ml", line 141, characters 0-34: <<ignore (create ~len: 0)>> threw ("Iobuf.create got nonpositive len" 0).
    ```

## 109.18.00

- a number of improvements to `inline_tests_runner`, including a
  `-verbose` flag.

    1. Made pa_ounit errors more readable.
    2. Added `-verbose` flag.
    3. Made the `-only-test` locations compatible with those displayed
      by the `-verbose` flag.
    4. Renamed `-display` as `-show-counts` to avoid confusion with
      `-verbose`.
    5. Improved errors when parsing the command line.
    6. Updated the readme.
    7. Added a `-list-test-names` which shows what tests would be run,
      if this option was not given.

## 109.10.00

- Rewrote `pa_ounit` to simplify execution order and work better with
  functors.

    Rewrote `pa_ounit` to solve its shortcomings with functors, namely
    that functors need to be applied with `TEST_MODULE` for their tests
    to be registered.  The order of execution is also much simpler:
    tests are executed inline, at the toplevel (or functor application
    time).  There is still a limitation: when a library doesn't have any
    occurrence of `TEST`, `TEST_UNIT`, or `TEST_MODULE` inside of it,
    the test runners are not set up, so tests inside of functors (from
    other libraries) will not be executed. Running
    `inline_test_runner.exe` is not going to run tests anymore; people
    should run the `inline_test_runner` script instead.  Backtraces are
    now properly shown when exceptions are thrown.

