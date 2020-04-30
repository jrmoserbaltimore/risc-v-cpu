Adders
======

These adders are appropriate for ASIC or, in some circumstances, extremely
large word size on FPGA.

Adders include:

* Speculative Han-Carlson
* Carry-Select
* A hybrid parallel-prefix/carry-select adder

The speculative Han-Carlson adder is derived from Katyayni, Reddy, et al.,
"Design of Efficient Han-Carlson-Adder," International Journal of Innovations
in Engineering and Technology.  The adder is about 40% faster than a regular
Han-Carlson adder, but produces errors rarely:  it excludes the connections
to propagate carry halfway across the width of the adder.  An error detection
circuit quickly detects this and prevents a completion signal from escaping,
so the adder requires a second cycle in these cases.  This is rare, so the
adder is faster all but 1 in 10,000 times.  It's not *twice* as fast because
the speculative stage includes the delay from the error detection circuit.

The hybrid PSA/CSA adder is derived from V. N. Sreeramulu, "Design of High
Speed and Low Power Adder by using Prefix Tree Structure," International
Journal of Science, Engineering and Technology Research (IJSETR), Volume 4,
Issue 9, September 2015.
