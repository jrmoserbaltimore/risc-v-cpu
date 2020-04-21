-- vim: set ts=4 sw=4 et

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";
use work.e_barrel_shifter;

entity et_barrel_shift is
    generic (
        XLEN      : natural := 8
    );
    port(
        Dout       : out std_ulogic_vector(XLEN-1 downto 0)
    ); 
end et_barrel_shift;

architecture t_barrel_shift of et_barrel_shift is
begin
    barrel_shifter: entity e_barrel_shifter(barrel_shifter)
    generic map (
        XLEN      => XLEN
    )
    port map (
        Din        => "10110101",  -- output should be 10101000
        Shift      => "011", -- 3
        opFlags    => ('0', '0', '0', '0'), -- rsh, ar
        Dout       => DOut
    );
end t_barrel_shift;