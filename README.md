# SLiM-Tests
Tests for SLiM, above and beyond the built-in self-tests.

---------------

This repository contains a suite of test scripts that are used to validate SLiM and to evaluate changes in performance.  Typical SLiM users can just use the `-testEidos` and `-testSLiM` command-line options on `slim` to make sure it has been built correctly; these scripts are intended more for use by those developing SLiM itself.

This repository has a specific structure:

- The slim* folders, each of which contains a `slim` executable for a particular version of SLiM.  The executable binaries provided here are built for macOS, and should (probably) work on any reasonably recent macOS system (say, 10.9 and later).  If you are on a different platform, you should remove all of these `slim` executables from your local clone, check out tagged releases of SLiM from the [SLiM repository](https://github.com/MesserLab/SLiM) for the versions you are interested in, build them, and copy the executables into these slim* folders.  These folders are also where the output from all of the test runs goes.
- The `run_slim_tests.R` script.  This is the test harness that actually runs the test scripts, tabulates their output, averages across replicates, etc.  See that file for comments on how it works.  I generally run it from inside the R GUI, not at the command line, but of course you can adapt it to your purposes.
- The `test scripts` folder.  This contains all of the test scripts used.  There is a `_README.txt` file in that folder that discusses them.
- The `bigmixed_burnin` folder.  One of the tests expects to read in a very large save file, which takes too long to generate for that to itself be part of the test.  This folder contains the model that generates that save file.  However, you should not need to worry about this, since the save file in question is included in this repository.

Note that the test harness uses only one core.  That is intentional, so that runtimes are as accurate as possible; if multiple cores were used, the runtime for one task would depend on how busy the other tasks were keeping the system.  For this reason, if you are interested in comparing runtimes as well as finding discrepancies/bugs, you should quit all other apps before running the test harness.  Doing replicate runs is also recommended for more accurate timing statistics.

License
----------

The code in the SLiM-Tests repository has been placed in the public domain without restriction.


Development & Feedback
-----------------------------------
SLiM is under active development, and our goal is to make it as broadly useful as possible.  If you have feedback or feature requests, or if you are interested in contributing to SLiM, please contact Philipp Messer at [messer@cornell.edu](mailto:messer@cornell.edu). Please note that Philipp is also looking for graduate students and postdocs.