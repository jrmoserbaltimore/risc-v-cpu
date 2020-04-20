-- vim: ts=4 sw=4 et
-- Quick-Div
--
-- Based on Matthews, Lu, Fang, and Shannon,
-- "Rethinking Integer Dividerd Design for FPGA Soft-Processors"
--
-- they used this for the Taiga RISC-V soft processor.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";
use work.e_barrel_shifter;
use work.e_divider_shifter;


architecture quickdiv_divider of e_divider_shifter is
    -- Operation flags
    alias opB   : std_ulogic is opFlags(0);
    alias opH   : std_ulogic is opFlags(1);
    alias opW   : std_ulogic is opFlags(2);
    alias opD   : std_ulogic is opFlags(3);
    alias opUnS : std_ulogic is opFlags(4);
    alias opAr  : std_ulogic is opFlags(5);
    alias opRSh : std_ulogic is opFlags(6);
    
    signal outReg : std_ulogic_vector((XLEN*2)-1 downto 0);
    -- 2^x exponent look-up table
    type expLUT is array (natural range <>) of std_ulogic_vector(XLEN-1 downto 0);
    signal shiftLUT : explut(XLEN-1 downto 0); 
begin

    LookUpTable: for i in XLEN-1 downto 0 generate
        shiftLUT(i) <= std_logic_vector(to_unsigned(2**i, XLEN-1));
    end generate;

    -- Shift multiplies by a power of 2, so is a shift left.
    -- The overflow goes into R and can be OR'd with the result
    -- of a non-arithmetic shift to produce a rotation.
    --
    -- A right-shift needs to reverse A into Q, perform the
    -- multiplication, and then reverse Q and R separately.
    Q <= outReg(XLEN-1 downto 0);
    R <= outReg((XLEN*2)-1 downto 0);

    -- TODO:  Implement
end quickdiv_divider;