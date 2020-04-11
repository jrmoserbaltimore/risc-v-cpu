-- vim: sw=4 ts=4 et
-- Shift instructions, including:
--
-- RV32I
--   SLLI   Shift Left Logical Immediate (32)
--   SRLI   Shift Right Logical Immediate (32)
--   SRAI   Shift Right Arithmetic Immediate (32)
--   SLL    Shift Left Logical (32)
--   SRL    Shift Right Logical (32)
--   SRA    Shift Right Arithmetic (32)
--
-- RV64I
--   SLLI   Shift Left Logical Immediate (64)
--   SRLI   Shift Right Logical Immediate (64)
--   SRAI   Shift Right Arithmetic Immediate (64)
--   SLL    Shift Left Logical (64)
--   SRL    Shift Right Logical (64)
--   SRA    Shift Right Arithmetic (64)
--   SLLIW  SLLI (32)
--   SRLIW  SRLI (32)
--   SRAIW  SRAI (32)
--   SLLW   SLL (32)
--   SRLW   SRL (32)
--   SRAW   SRA (32)
--
-- RV128I
--   TBA

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";
use work.e_riscv_insn_2in;
use work.e_barrel_shifter;

architecture riscv_i_shift of e_riscv_insn_2in is
    alias ShRight    : std_ulogic is insn(14);
    alias Arithmetic : std_ulogic is insn(30);
begin
    -- XLEN will be 32, 64, or 128, and will instantiate a shifter
    -- that many bits wide.
    --
    -- Inputs are properly sign-extended by the decoder, so are
    -- used as-is and the barrel shifter does the right thing.
    barrel_shifter: entity e_barrel_shifter(barrel_shifter)
    generic map (XLEN      => XLEN)
    port map (
        Din        => rs1,
        Shift      => rs2(integer(ceil(log2(real(XLEN))))-1 downto 0),
        ShRight    => ShRight,
        Arithmetic => Arithmetic,
        Dout       => rd
    );
end riscv_i_shift;
