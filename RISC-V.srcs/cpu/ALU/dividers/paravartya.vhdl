-- vim: ts=4 sw=4 et
-- Paravartya divider
--
-- Division is basically free.
--
-- 11010110 / 1101 
--
--   Dividend | Divisor
-- 1  1  0  1 | 1  1  0  1  0  1  1  0
--   -1  0 -1 |   -1  0 -1              * result(i+1) = *1 
--            |       0  0  0           * result(i+1) = *0
--            |          0  0  0        *0
--            |             0  0  0
--            |                0  0  0
-- -----------------------------------
--     Result | 1  0  0  0  0 |1  1  0
--      Carry |               |   
--
--  110 is bigger than the absolute value of -101 so subtract it from 1101
--  1101 - 110 = 0111
--  Result is 10000r111, i.e. 16 remainder 7
--
--
--   Dividend | Divisor
-- 1  1  1  1 | 1  1  0  1  0  1  1  0
--   -1 -1 -1 |   -1 -1 -1              1  
--            |       0  0  0           2
--            |          1  1  1        3
--            |            -1 -1 -1     4   
--            |                0  0  0  5   
-- -----------------------------------
--     Result1| 1  0          |
--     Result2| 1  0 -1       |       
--     Result3| 1  0 -1  1    | 
--     Result4| 1  0 -1  1  0 |
--     Result5| 1  0 -1  1  0 | 1 0 0
--
--     Result | 1  0 -1  1  0 | 1 0 0 
--
--     100 is less than the absolute value of 1111
--     R = 100
--     Q = 10010 -100 = 1110
--
--   Dividend | Divisor
--    1  0  1 | 1  1  0  1  0  1  1  0
--       0 -1 |    0 -1                 1
--            |       0 -1              2
--            |          0  1           3
--            |             0  0        4
--            |                0  -1    5
--            |                    0 -1    
-- -----------------------------------
--     Result1| 1                |
--     Result2| 1  1             |     
--     Result3| 1  1 -1          |
--     Result4| 1  1 -1  0       |    
--     Result5| 1  1 -1  0  1    |
--     Result5| 1  1 -1  0  1  1 | 0 -1   
--
--  Q: 110011 - 1000 = 101011
--
--  Remainder is -1.  add 101 and subtract 1 from Q.
--  101010 r 100
--
--   Dividend | Divisor
-- 1  0  1  1 | 1  1  0  1  0  1  1  0
--    0 -1 -1 |    0 -1 -1              1
--            |       0 -1 -1           2
--            |          0  1  1        3
--            |             0  1  1     4
--            |                0  0  0  5
--            |                   0       
-- -----------------------------------
--     Result1| 1             |   
--     Result2| 1  1          |        
--     Result3| 1  1 -1       |   
--     Result4| 1  1 -1 -1    |       
--     Result5| 1  1 -1 -1  0 |   
--     Result5| 1  1 -1 -1  0 |11 10 0   
--                          1  1  0  0
--                             1  0
--  Q: 11000 - 110 = 10010
--
--  Remainder is 10000
--  10000 - 1010 = 0101, add 1 to Q
--    10011 r 0101
--
-- Each bit requires the prior bits and only the prior bits in a correct
-- computation state, including positive, negative, or zero.  That itself
-- is the result of an addition.  In essence, while all bits can be
-- calculated in parallel, the computation of the current bit requires
-- the prior bit's correct value at the current stage, which in turn is
-- the result of a bunch of addition of results from prior stages.
--
-- Implemented in combinational logic, this creates parallel calculation
-- of quotient bits *and* remainder bits laminated with a parallel array
-- of adders to compute each bit at each stage of computation.  In effect,
-- the purely-combinational form of this is a massive ripple-carry divider.
--
-- The iterative version here is a slow divider, as is Nikhilam; but it's
-- a small divider.  In theory, a 64x64 Paravartya divider built in pure
-- combinational logic is something like XLEN^2 / 2 one-bit full adders,
-- the same number of AND gates to mask bits to their appropriate columns
-- (based on the dividend and divisor size), and then a subtractor at the
-- end.  It also needs a barrel shifter on the input.  That might be a
-- couple thousand gates, and LUT-hungry.  The iterative version is a
-- few hundred gates, or a hundred or so LUTs at XLEN=32.
--
-- Because dividers generally require shifters, it makes sense to specify
-- a divider-shifter.
--
-- I have no idea why this algorithm works, but it works.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";
use work.e_barrel_shifter;
use work.e_divider_shifter;

architecture paravartya_divider of e_divider_shifter is
    -- Operation flags
    alias opB   : std_ulogic is opFlags(0);
    alias opH   : std_ulogic is opFlags(1);
    alias opW   : std_ulogic is opFlags(2);
    alias opD   : std_ulogic is opFlags(3);
    alias opUnS : std_ulogic is opFlags(4);
    alias opAr  : std_ulogic is opFlags(5);
    alias opRSh : std_ulogic is opFlags(6);
    
    signal outReg : std_ulogic_vector((XLEN*2)-1 downto 0);
    
    signal barrelOut : std_ulogic_vector((XLEN*2)-1 downto 0);

    -- 2^x exponent look-up table
    type expLUT is array (natural range <>) of std_ulogic_vector(XLEN-1 downto 0);
    signal shiftLUT : explut(XLEN-1 downto 0); 
begin

    -- XLEN will be 32, 64, or 128, and will instantiate a shifter
    -- twice as wide.
    barrel_shifter: entity e_barrel_shifter(barrel_shifter)
    generic map (
        XLEN      => XLEN*2
    )
    port map (
        Din        => (XLEN-1 downto 0 => A, others => '0'),
        Shift      => B(integer(ceil(log2(real(XLEN))))-1 downto 0),
        opFlags    => (opRSh, opAr, opD, opW),
        Dout       => barrelOut
    );

    LookUpTable: for i in XLEN-1 downto 0 generate
        shiftLUT(i) <= std_logic_vector(to_unsigned(2**i, XLEN-1));
    end generate;

    Q <= outReg(XLEN-1 downto 0);
    R <= outReg((XLEN*2)-1 downto 0);

    -- TODO:  Implement
end paravartya_divider;