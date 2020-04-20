Adders
======

Various adders are available, using various amount of space and operating
at various speeds.

# Speculative Adders

Speculative adders take up additional space, but operate at higher frequencies.
They can run at higher fmax in synchronous circuits, consuming a two-cycle
ADD in the rare occasion they miss-speculate.

## Han-Carlson

The Han-Carlson Speculative Adder shortens the critical path by one stage.  It
detects and corrects for error in the rare case of an error.  This adder
consumes minimal area and has a high fmax.
