% Pa_ounit

Pa\_ounit is a syntax extension that helps writing in-line tests in ocaml code.

New syntactic constructs
------------------------
The following constructs are now valid structure items:

    TEST name? = <boolean expr> (* true means ok, false or exn means broken *)
    TEST_UNIT name? = <unit expr> (* () means ok, exn means broken *)
    TEST_MODULE name? = <module expr> (* to group TESTs (to share some setup for instance) *)

Contrary to the previous version of pa_ounit, if the tests are executed, they will be
executed when the control flow reaches the structure item (ie at toplevel for a toplevel
TEST, when the functor is applied for a TEST defined in the body of a functor, etc.).

Examples
--------

###prime.ml

    let is_prime = <magic>

    TEST = is_prime 5
    TEST = is_prime 7
    TEST = not (is_prime 1)
    TEST = not (is_prime 8)


###tests in a functor.

    module Make(C : S) = struct
         <magic>
         TEST = <some expression>
    end

    module M = Make(Int)

###grouping test and side-effecting initialisation.

Since the module passed as an argument to `TEST_MODULE` is only initialised when
we run the tests. It is therefore ok to perform side-effects in a `TEST_MODULE`

    TEST_MODULE = struct
        module UID = Uniq_id.Int(struct end)

        TEST = UID.create() <> UID.create()
    end

Building and running the tests
------------------------------

Code using this extension must be compiled and linked using the pa\_ounit\_lib
library. The pa_ounit syntax extension can take a `-pa-ounit-lib libname` flag (which
defaults to `dummy`).

Tests are executed when the executable containing the tests is called with command line
arguments:

    your.exe inline-test-runner libname [options]

otherwise they are ignored.

This `libname` is a way of restricting the tests run by the executable. The dependencies
of your library (or executable) could also use `pa_ounit`, but you don't necessarily want
to run their tests too. For instance, `core` is built by giving `-pa-ounit-lib core` to
camlp4, and `core_extended` is built by giving `-pa-ounit-lib core_extended` to
camlp4. And now when an executable linked with both `core` and `core_extended` is run with
a `libname` of `core_extended`, only the tests of `core_extended` are run.

Finally, after running tests, `Pa_ounit_lib.Runtime.summarize ()` should be called (to
exit with an error and a summary of the number of failed tests if there were errors or
exit normally otherwise).

For instance, to execute core tests:

    echo 'Pa_ounit_lib.Runtime.summarize ()' > test.ml
    ocamlfind ocamlopt -o test -linkall -linkpkg -package core -thread test.ml
    ./test inline-test-runner core -log -display

Command line arguments
----------------------
The executable that runs tests can take additional command line arguments. The most useful
of these are:

*   -verbose

    to see the tests as they run

*    -only-test location

     where location is either a filename [-only-test main.ml], a filename
     with a line number [-only-test main.ml:32], or with the syntax that the
     compiler uses: [File "main.ml"], or [File "main.ml", line 32] or [File "main.ml",
     line 32, characters 2-6] (characters are ignored).
     The position that matters is the position of the TEST or TEST\_UNIT or
     TEST\_MODULE construct. The positions shown by `-verbose` are valid
     inputs for `-only-test`.

     If no [-only-test] flag is given, all the tests are
     run. Otherwise all the tests matching any of the locations are run.
