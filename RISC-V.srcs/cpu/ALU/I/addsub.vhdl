-- vim: sw=4 ts=4 et
-- Addition/subtraction:
--  ADD[I]
--  SUB

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.e_riscv_insn_2in;
use work.e_binary_adder;

architecture riscv_i_addsub of e_riscv_insn_2in is 
    -- Subtract bit
    alias Sub    : std_ulogic is insn(30);
begin

    -- FIXME:  make the adder type configurable
    adder: entity e_binary_adder(han_carlson_adder)
        generic map (XLEN => XLEN,
                     Cycles => Cycles
        )
        port map (
            A        => rs1,
            B        => rs2,
            Sub      => Sub,
            Clk      => Clk,
            Rst      => Rst,
            S        => rd,
            Complete => Complete
        );
end riscv_i_addsub;
