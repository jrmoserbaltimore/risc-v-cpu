-- vim: sw=4 ts=4 et
-- adder components
--
-- These are parts of adders
library IEEE;
use IEEE.std_logic_1164.all;

-- Binary adder
--
--  Ripple-Carry:
--
--        A   B
--        |   |
--       -------
-- Cout-| Adder |-Cin
--       -------
--          |
--          S
--
-- Parallel prefix:
--
--            A   B
--            |   |
--           -------
-- Cout (G)-| Adder |-Cin (G[n-1])
--           -------
--              |
--              S (P)
--
-- Parallel prefix adder sends P to an XOR gate along with Cin
-- (final output from last stage, so it has the same interface.
-- In architecture, G would be sent to Cout, P sent to MUX.
--
-- Adder-subtractor:
--
--          ---------+-------+-----SUB
--      A1 |      A0 |       |
--       | |       | |       |
--       XOR  B1   XOR  B1   |
--        |   |     |   |    |
--       -------   -------   |
-- Cout-| Adder |-| Adder |--
--       -------   -------
--          |
--          S
--
-- SUB is xor'd with the subtrahend, and is Cin for the bit-0
-- full adder.
entity e_binary_adder is
    generic ( XLEN      : natural;
              Cycles    : natural
    );
    port(
        A        : in  std_ulogic_vector(XLEN-1 downto 0);
        B        : in  std_ulogic_vector(XLEN-1 downto 0);
        Sub      : in  std_ulogic;
        Clk      : in  std_ulogic;
        -- Reset cycle count.  First cycle for a new computation.
        Rst      : in  std_ulogic;
        --Cout     : out std_ulogic;
        S        : out std_ulogic_vector(XLEN-1 downto 0);
        Complete : out std_ulogic
    );
end e_binary_adder;