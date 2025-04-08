ABOUT THESE TEST SCRIPTS

Ben Haller, 21 Feb. 2020

--------------------------------

This folder contains test scripts, which are files that end in ".slim".
They are numbered, but those numbers do not correspond to the indices
they have in the R script, which is maybe confusing, sorry.

The first line of each test script is expected to provide a grep pattern
that extracts the text used by the R script as a basis for comparing
whether results have changed.  For example, script 001 version.slim
calls the version() function, which prints out something like:

Eidos version 2.3.2
SLiM version 3.3.2

The first line of that script is:

// version.slim : ^SLiM version (.*)$

This tells the R script to use the grep pattern "^SLiM version (.*)$"
to extract the key information used for comparison.  In this case,
that would be the string "3.3.2".  If that information changes between
the next-to-last version and the last version (for the first rep run,
seed 0), the R script will print out:

************** CHANGED *************

That is a signal that there may be a backward-compatibility issue or
a bug.  One ought to then investigate until the reason for the mismatch
is well-understood.

The rest of the test script can be anything at all.  No command-line
parameters for use in the test script are passed in from R.
