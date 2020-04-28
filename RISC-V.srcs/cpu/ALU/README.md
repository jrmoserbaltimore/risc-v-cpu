Arithmetic Logic Unit
=====================

The ALUs here implement RV32I and RV64I instructions.  Various configurations
may enable multiple copies of particular facilities (adders, multipliers,
incrementers), multi-port ALUs (for SMT or OOE), and other features.

ALUs execute instructions in the order and with the data they are given.
Out-of-order and speculative execution are carried out before sending
instructions to the ALU.

# Soft ALU

`alus-fabric.sv` provides a soft ALU incorporating a speculative Han-Carlson
adder-subtractor, a reversible barrel shifter, bitwise operations, a
comparator, a Dadda multiplier, and a Paravartya divider.

The soft ALU uses its internal adders, shifters, and comparators to
support the multiplier and divider.  It is likely a better ASIC design
than FPGA.

# Xilinx DSP48E1 ALU

`alu-dsp48.sv` provides a Xilinx DSP48E1 ALU, based on Cheah Hui
Yan's [iDEA soft processor](https://www.xilinx.com/support/documentation/white_papers/wp406-DSP-Design-Productivity.pdf).
The DSP48E1 provides a high-speed adder-subtractor, a multiplier,
and bitwise operations.  The adder-subtractor can provide a
comparator by performing `A-B`, with the carry bit indicating A is
less than B.

The general layout looks as below:

```
  A          B
  |          |
  |          *
  |      _________
  |     |         |
  |     |    *    |
  |     |  __|    |
  |     | |  |    |
  |     | |  |    |
  |___  | |  |    |
  |   | | |  |    |
  |   | | |  |    |
  |   DIVSH  |    |
  |  _| |    |    |
  | |   |  __|    |
  | |   | |       |
  MUX   MUX       |
  |     |         |
  DSP48E1         |
     |____________|
     |
   OUTPUT
    ***
```
Approach:

* Instantiate cascading DSP48E1 units
* Instantiate divider-shifter DIVSH.
* Fan out input data to a mux on the DSP and to DIVSH.
* Fan DSP output out to both output and DIVSH.
* DIVSH uses internal MUX to select inputs.
* DIVSH controls ALU circuit to leverage DSP48E1.
* DIVSH contains look-up table for bit shifting, uses the DSP
multiplier to perform bit shifts.

DSP operations face only a single input mux on the critical path,
and that mux idles favoring the input.  DSP handles addition,
subtraction, and bitwise AND, OR, and XOR.  All other circuits
pass output through the DSP set to OR with zero.

The Divider-Shifter contains a look-up table to select a power
of 2 for multiplication of the data to be shifted.  It also
contains reversal circuitry to turn the input backwards for a
right shift, and sign-extension for arithmetic shift right.

The bit-shift look-up table contains `n` entries for an `n`-bit
shifter.  The table must have `XLEN` `XLEN`-bit entries, e.g. 32
32-bit entries or 128 bytes, 64 64-bit entries or 512 bytes, and
128 128-bit entries or 4096 bytes.  Doubling  'XLEN` increases
the size of the lookup table by a factor of 4.

DIV is a multi-cycle instruction and uses the DSP48E1 to
compute bit-shifts, multiplications, additions, and comparisons
to implement complex division algorithms.  It follows the
[Paravartya binary division algorithm](https://www.researchgate.net/profile/Sandeep_Saini7/publication/264118516_Binary_division_algorithm_and_high_speed_deconvolution_algorithm_Based_on_Ancient_Indian_Vedic_Mathematics/links/53fc730c0cf2364ccc049cb7/Binary-division-algorithm-and-high-speed-deconvolution-algorithm-Based-on-Ancient-Indian-Vedic-Mathematics.pdf)
described by Jain, Pancholi, Garg, and Saini.

The INPUT and OUTPUT fan-out are both two.

The DSP provides the adder, bitwise operations, comparator, and
multiplier, and gets the shortest critical path.  Comparatively
rare divison gets a long, multi-cycle operation.  Bit shift is a
look-up table and a multiplication.
