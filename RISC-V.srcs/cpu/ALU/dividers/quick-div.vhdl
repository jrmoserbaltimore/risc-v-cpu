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

begin

    Q <= outReg(XLEN-1 downto 0);
    R <= outReg((XLEN*2)-1 downto 0);

    -- TODO:  Implement Quick-Div CLZ
    -- XXX:  Is the CLZ-and-shift viable versus using a shifter
    --       AS a zero counter?  e.g.:
    --
    --       aaaa bbbb
    --         |   |    sel: shift left 4 if (aaaa = 0000)
    --       aabb
    --         |        sel: shift left 2 if (aa = 00)
    --        ab
    --         |        sel: shift left 1 if (a = 0)
    --         a
    --         |        sel: if (a = 0) switch to div-by-zero logic
    --
    --      Note that SEL can be banked into a register and give you the shamt 
end quickdiv_divider;