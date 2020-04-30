Dividers
========

Dividers use multiplication, subtraction, addition, bit shifts, or other
facilities to compute division and remainder.  FPGAs generally don't include
hardware divider circuits, so these are relevant in both FPGA and ASIC.

# Quick-Div

Matthews, Lu, Fang, and Shannon produced Quick-Div, detailed in "Rethinking
Integer Dividerd Design for FPGA Soft-Processors," for the Taiga RISC-V soft
processor.

Quick-Div uses a number of strategies, notably a fast Count Leading Zeroes
(CLZ) circuit, to run repeat subtraction division at a high clock rate with
variable delay.  The divider can complete in few cycles if the calculation
is complete early; the worst case is division by 1.

# Paravartya divider

The Paravartya Divider completes division at one iteration per
`1 + DividendDigits - DivisorDigits` digits.  It requires single-`AND` one-
bit multiplication, plus some decisions based on a sign bit, plus some
carry addition.  In essence, it's single-bit multiply with multi-bit
accumulate.

This divider requires a set-up stage consuming one cycle—more at huge word
sizes e.g. 64- or 128-bit.  The set-up stage performs parallel CLZ on both
the dividend and the divisor—derived from Quick-Div—and sets up registers
for the initial dividend and accumulator state.  When this stage is not
in the critical path, a divide-by-power-of-two check is possible in parallel.
If detected, the second stage is a simple `AND` of the LSB bits to be shifted
out and a barrel shift right.  Likewise, if the dividend has more leading
zeroes than the divisor, the result is `Q=0, R=Dividend`.

Much of this can occur in parallel, and the divider can signal when it's
finished.  The division stage is an entirely-parallel set of two sequential
one-bit multiplies for each dividend bit, plus addition.  Accumulation is
best handled in a three-register manner:

```
Result  | 1 1 1 0 0 1 1 0
Carry   | 0 0 0 1 0 1 0 0
Sign    | 0 0 1 0 0 0 1 0
```
Above, two additions are necessary: the carry bit must propagate each
iteration and ultimately be added to the result; and the sign bit must be
subtracted from the result of this `XOR Sign`.

Carry propagation affects sign:
```
Result  | 1 0
Carry   | 0 1
Sign    | 1 0

```
Above, the carry bit is added in a single-bit addition via `Cin XOR Result`,
and the resulting carry is computed as `Cin AND NOT Sign`.  The sign bit
becomes `Sign XOR Cin`.  In this way. `-1` becomes `0`.

Carry propagation is otherwise as usual:
```
Result  | 0 1 1 0
Carry   | 0 1 0 0
Sign    | 0 0 1 0

Add     | 1 0 1 0  // Add the Carry row to the Result row
XOR     | 1 0 0 0  // XOR the resulting figure with the Sign row
Subtract| 0 1 1 0  // Subtract Sign from the resulting figure
```

The first `Add` requires the specialized process described above, halting
carry propagation at a -1 bit by clearing both that bit in the Result and in
the Sign register.  The subtraction simply removes the resuting Sign bits
from the result, with all negative bits beginning as 0 in the result—those
bits represent -1, so are being subtracted from 0 in that position.

Additions proceed iteratively, and an entire iteration can occur in parallel
as below.  Carry and Sign are mutually-exclusive, simplifying the process.
```
R    = R XOR Cin XOR A
C    = R AND Cin AND NOT S  // if -1 + 1, produce 0 no carry
S    = S AND NOT (Cin OR A) // if -1 + 1, sign is 0
```

This is similar to an incrementer circuit:  rather than adding `A` and `B`,
a half-adder uses `Cin` as `B`, and `Cout` becomes `B` for the next half-adder.
In this circuit, `R` is the `A` input, and `C` from the last stage is `Cin`.
An additional input (`A` above) makes this a three-way adder.

This stored carry circuit has implications:

* If `R=0`, `C OR S = 0`
* If `R=1`, `C AND S = 0`
* The ending value of `C`, if there is no overflow of `R`, is `0`
* If `R=1` and `Cin=1`, then the end state is `R=0` and `C = Cin AND NOT S`
* In a three-way add, if `R=1` and `Cin=1` and `A=1`, the end state is `R=1`
  and `C=1`

Thus on each iteration, `C` from the next-least-significant-bit becomes `Cin`,
and is replaced by a proper carry result.  The additional stage of division
adds any generated bits.

There's one more complication:  the added bit is signed. [Todo:  explain how
to deal with this iteratively]

Because all of these iterations can occur in parallel to the division itself,
they don't increase the divider's critical path.  The final iteration must add
the final results, which can be done by stripping `S` and adding `R + C`, then
subtracting `(R XOR S) - S`.  [FIXME:  Prove this mathematically]

A final stage may use an incrementer—a row of half-adders—to two's-complement
`S` by sending `NOT S`.  This amounts to a ripple-carry adder, but three
times as fast.  This final computation can compute each cycle in parallel
against the `R`, `S`, and `C` registers,  and so be ready and complete after
the last division stage, thus only requiring two low-area addition circuits.

```
11010110 / 1101 

   Divisor | Dividend
1  1  0  1 | 1  1  0  1  0  1  1  0
  -1  0 -1 |   -1  0 -1              * result(i+1) = *1 
           |       0  0  0           * result(i+1) = *0
           |          0  0  0        *0
           |             0  0  0
           |                0  0  0
-----------------------------------
    Result | 1  0  0  0  0 |1  1  0
     Carry |               |   

 110 is bigger than the absolute value of -101 so subtract it from 1101
 1101 - 110 = 0111
 Result is 10000r111, i.e. 16 remainder 7


  Dividend | Divisor
1  1  1  1 | 1  1  0  1  0  1  1  0
  -1 -1 -1 |   -1 -1 -1              1  
           |       0  0  0           2
           |          1  1  1        3
           |            -1 -1 -1     4   
           |                0  0  0  5   
-----------------------------------
    Result1| 1  0          |
    Result2| 1  0 -1       |       
    Result3| 1  0 -1  1    | 
    Result4| 1  0 -1  1  0 |
    Result5| 1  0 -1  1  0 | 1 0 0

    Result | 1  0 -1  1  0 | 1 0 0 

    100 is less than the absolute value of 1111
    R = 100
    Q = 10010 -100 = 1110

  Dividend | Divisor
   1  0  1 | 1  1  0  1  0  1  1  0
      0 -1 |    0 -1                 1
           |       0 -1              2
           |          0  1           3
           |             0  0        4
           |                0  -1    5
           |                    0 -1    
-----------------------------------
    Result1| 1                |
    Result2| 1  1             |     
    Result3| 1  1 -1          |
    Result4| 1  1 -1  0       |    
    Result5| 1  1 -1  0  1    |
    Result5| 1  1 -1  0  1  1 | 0 -1   

 Q: 110011 - 1000 = 101011

 Remainder is -1.  add 101 and subtract 1 from Q.
 101010 r 100

  Dividend | Divisor
1  0  1  1 | 1  1  0  1  0  1  1  0
   0 -1 -1 |    0 -1 -1              1
           |       0 -1 -1           2
           |          0  1  1        3
           |             0  1  1     4
           |                0  0  0  5
           |                   0       
-----------------------------------
    Result1| 1             |   
    Result2| 1  1          |        
    Result3| 1  1 -1       |   
    Result4| 1  1 -1 -1    |       
    Result5| 1  1 -1 -1  0 |   
    Result5| 1  1 -1 -1  0 |11 10 0   
                         1  1  0  0
                            1  0
 Q: 11000 - 110 = 10010

 Remainder is 10000
 10000 - 1010 = 0101, add 1 to Q
   10011 r 0101
```

Each bit requires the prior bits and only the prior bits in a correct
computation state, including positive, negative, or zero.  That itself
is the result of an addition.  More directly, each bit result requires
the immediate prior bit to be correct up to that point in the
calculation, which requires only the vertical add, which iterates each
cycle.  The horizontal propagation is irrelevant.

This allows for a high-frequency division circuit.  When not in the critical
path, a slightly-larger circuit can compute two bits per cycle.
