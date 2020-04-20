-- vim: ts=4 sw=4 et
-- Divider-shifter
--
-- Full-width divider and shifter using a look-up table
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";

entity e_divider_shifter is
    generic
    (
        XLEN : natural
    );
    port
    (
        A,B     : in std_ulogic_vector(XLEN-1 downto 0);
        -- if 1, shifter
        Shift : in std_ulogic_vector;
        -- Operation flags
        -- bit 0:  *B
        -- bit 1:  *H
        -- bit 2:  *W
        -- bit 3:  *D
        -- bit 4:  Unsigned (DIVU)
        -- bit 5:  Arithmetic
        -- bit 6:  Right-shift
        opflags : in std_ulogic_vector(8 downto 0);
        -- Division:
        --   Q = quotient, R = remainder
        -- Shifter:
        --   Q = result, R = overflow
        Q    : out std_ulogic_vector(XLEN-1 downto 0);
        R    : out std_ulogic_vector(XLEN-1 downto 0);
        -- Multiplier interface.  Requires Busy-STB interface too.
        MulA, MulB : out std_ulogic_vector(XLEN-1 downto 0);
        MulL, MulH : in  std_ulogic_vector(XLEN-1 downto 0)
    );
end e_divider_shifter;
