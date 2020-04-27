-- vim: ts=4 sw=4 et
-- Barrel shifter
--
-- n-bit barrel shifter with arithmetic right-shift
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";

-- Barrel shifter
--
-- Select bit of '1' selects the left (input) bit.
--
-- bit  4   3   2   1
--      |  -|  -|  -|-   --Arithmetic Shift
--      | | | | | | | | |
--      | | | | | | | AND
--      | | | | | | |  |
--      | | | | | | |  Sx   Sign-extend bit
--      | | | | | | |
--      | | | | | | | Sx
--      | | | | | | | |
--      MUX MUX MUX MUX--Select bit 0 (To all stage-1 MUX)
--      |  -|---+   |
--      | | |  -|---+
--      | | | | |  -|-+---Sx
--      | | | | | | | |
--      MUX MUX MUX MUX--Select bit 1 (To all stage-2 MUX)
--      |   |   |   |
--      |  -|-+-|-+-|-+---Sx
--      | | | | | | | |
--      MUX MUX MUX MUX--Select bit 2 (To all stage-3 MUX)
--       |   |   |   |
--
-- Itput r2 only has to be log(xlen), e.g 5 for 32-bit,
-- 6 for 64-bit, 7 for 128-bit.
--
-- The decoder must sign-extend.
entity e_barrel_shifter is
-- Only feed this a power of 2!
    generic (
        XLEN      : natural
    );
    port(
        Din        : in  std_ulogic_vector(XLEN-1 downto 0);
        Shift      : in  std_ulogic_vector(integer(ceil(log2(real(XLEN)))) downto 0);
        opFlags    : in  std_ulogic_vector(1 downto 0);
        Dout       : out std_ulogic_vector(XLEN-1 downto 0)
    );
end e_barrel_shifter;

-- This barrel shifter is reversible by using n muxes on input and
-- output to reverse the bit order (reverse input, shift left,
-- reverse output).
--
--Arithmetic shift right has sign prepended as it shifts.
--
-- Input must be sign-extended if less than word size.
architecture barrel_shifter of e_barrel_shifter is
    type tree_array is array (Shift'HIGH downto -1) of std_ulogic_vector(XLEN-1 downto 0);
    signal tree : tree_array := (others => (others => '0'));
    signal SignEx : std_ulogic;
    
    -- Operation flags
    -- bit 0:  Arithmetic (and Adder-Subtractor subtract)
    -- bit 1:  Right shift
    alias opAr  : std_ulogic is opFlags(0);
    alias opRSh : std_ulogic is opFlags(1);
    
    function ShiftWidth (l: natural) return natural is
    begin
        if (l > XLEN-1) then
            return XLEN-1;
        end if;
        return l;
    end function;
        
begin
    -- This thing is inherently combinatorial
    barrel: process(all) is
    begin
        --  SignBit Arithmetic
        --        | |
        --        AND ShRight
        --          | |
        --          AND
        --           |
        --          All shifted-out MUXes
        SignEx          <= Din(Din'HIGH) AND opAr AND opRSh;
        
        -- Put Din into the top of the tree to avoid breaking out special
        -- handling for the first row.  The "top" is basically tree(-1).
        --
        -- Reverse if shifting right
        for i in (XLEN-1) downto 0 loop
            if (opRSh = '0') then
                tree(-1)(i) <= Din(i);
            else
                tree(-1)(i) <= Din((XLEN-1) - i);
            end if;
            -- Vivado 2019 says it doesn't support this syntax of if statement:
            --tree(-1)(i) <= Din(i) when opRSh = '0' else
            --               Din((highBit-1) - i);
        end loop;
 
        -- Computes all bits in parallel at each stage  
        for i in Shift'RANGE loop
            if (Shift(i) = '1') then
                tree(i)(XLEN-1 downto 2**i) <= tree(i-1)(XLEN-(1+2**i) downto 0);
                tree(i)(2**i-1 downto 0) <= (others => SignEx);
             else
                tree(i) <= tree(i-1);
            end if;
        end loop;

        -- Reverse back when shifting right
        for i in (XLEN-1) downto 0 loop
            if (opRSh = '0') then
                Dout(i) <= tree(Shift'HIGH)(i);
            else
                Dout(i) <= tree(Shift'HIGH)((XLEN-1) - i);
            end if;
            --Dout(i) <= tree(Shift'HIGH)(i) when opRSh = '0' else
            --           tree(Shift'HIGH)((highBit-1) - i);
        end loop;
    end process barrel;
end barrel_shifter;
