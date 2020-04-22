-- vim: set ts=4 sw=4 et

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";
use work.e_barrel_shifter;
use work.e_binary_adder;

entity et_barrel_shift is
    generic (
        XLEN      : natural := 8
    );
    port(
        Dout       : out std_ulogic_vector(XLEN-1 downto 0)
    ); 
end et_barrel_shift;

architecture t_barrel_shift of et_barrel_shift is
    signal Clk : std_ulogic := '0';
    constant ClockFrequency : integer := 100e6;
    constant ClockPeriod : time := 1000ms / (ClockFrequency*2);
    signal hcAddSubOut : std_ulogic_vector(7 downto 0);
    signal hcSpeculativeAddSubOut : std_ulogic_vector(7 downto 0);
begin
    barrel_shifter: entity e_barrel_shifter(barrel_shifter)
    generic map (
        XLEN      => XLEN
    )
    port map (
--        Clk        => Clk,
        Din        => "10110101",  -- output should be 10101000
        Shift      => "0011", -- 3
        opFlags    => ('0', '0'), -- rsh, ar
        Dout       => DOut
    );

    speculative_han_carlson_adder: entity e_binary_adder(speculative_han_carlson_adder)
        generic map
        (
            XLEN => 8,
            Speculative => true
        )
        port map (
        -- This generates an error when speculation fails
            A        => "01001010",
            B        => "01110110",
            Sub      => '0',
            Clk      => Clk,
            Rst      => '0',
            S        => hcSpeculativeAddSubOut
        );

    han_carlson_adder: entity e_binary_adder(speculative_han_carlson_adder)
        generic map
        (
            XLEN => 8,
            Speculative => false
        )
        port map (
            A        => "01001010",
            B        => "01110110",
            Sub      => '0',
            Clk      => Clk,
            Rst      => '0',
            S        => hcAddSubOut
        );
    Clk <= not Clk after ClockPeriod;
end t_barrel_shift;