-- vim: ts=4 sw=4 et
-- CPU
library IEEE;
use IEEE.std_logic_1164.all;

entity e_riscv_cpu is
    port (
        clk : std_ulogic;
        ram : std_ulogic_vector(71 downto 0)
    );
end e_riscv_cpu;