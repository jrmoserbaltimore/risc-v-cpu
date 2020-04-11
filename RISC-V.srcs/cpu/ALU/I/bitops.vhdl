-- vim: sw=4 ts=4 et
-- Bit operation instructions:
--  AND[I]
--  OR[I]
--  XOR[I]

library IEEE;
use IEEE.std_logic_1164.all;
use work.e_riscv_insn_2in;

architecture riscv_i_bitmask of e_riscv_insn_2in is 
    alias funct3 : std_ulogic_vector(2 downto 0)  is insn(14 downto 12);
begin
    bitmask : process(clk) is
    begin
        -- For immediates, the value is passed as rs2.
        -- The decoder sign-extends the values as appropriate.
        if (rising_edge(clk)) then
            if (funct3 = "111") then
                -- funct3 = 111 is AND
                rd <= rs1 AND rs2;
            elsif (funct3 = "110") then
                -- funct3 = 110 = or
                rd <= rs1 OR rs2;
            elsif (funct3 = "100") then
                -- funct3 = 100 = xor
                rd <= rs1 XOR rs2;
            end if;
        end if;
    end process bitmask;
end riscv_i_bitmask;
