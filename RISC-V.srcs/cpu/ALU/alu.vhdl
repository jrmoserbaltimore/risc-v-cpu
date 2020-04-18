-- vim: sw=4 ts=4 et
--
-- Arithmetic logic unit
--
-- The ALU pointedly does not complain about invalid input.
-- Don't send invalid input.
--
-- ALU operations like MUL and DIV may use the ALU's other
-- resources, such as bit shifts and masks, addition, or
-- even the multiplier.  MUL and DIV consume adder resources
-- for several cycles; additional ALUs are valuable in OOE
-- and superscalar applications. 
library IEEE;
use IEEE.std_logic_1164.all;

entity e_alu is
    generic
    (
        XLEN : natural;
        FmaxFactor : positive := 1
    );
    port
    (
        clk  : in  std_ulogic;
        -- Reset when giving new data, for multi-cycle
        -- instructions (Replace with STB-BUSY)
        rst  : in  std_ulogic;
        -- term 1 and term 2
        -- immediates are passed in sign-extended if necessary
        rs1  : in  std_ulogic_vector(XLEN-1 downto 0);
        rs2  : in  std_ulogic_vector(XLEN-1 downto 0);
        -- Function selector
        -- 0: add, sub: ADD, ADDI, SUB; 64 ADDW, ADDIW, SUBW
        -- 1: shift: SLL, SLLI, SRL, SRLI, SRA; 64 SLLIW, SRRIW, SRAIW
        -- 2: AND: AND, ANDI
        -- 3: OR: OR, ORI
        -- 4: XOR: XOR, XORI
        --
        -- Extension: M
        -- 5: Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
        -- 6: Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
        logicOp : in  std_ulogic_vector(6 downto 0);
        -- Operation flags
        -- bit 0:  *B
        -- bit 1:  *H
        -- bit 2:  *W
        -- bit 3:  *D
        -- bit 4:  Unsigned
        -- bit 5:  Arithmetic (and Adder-Subtractor subtract)
        -- bit 6:  Right-shift
        -- bit 7:  MULHSU
        -- bit 8:  DIV Remainder
        opflags : in std_ulogic_vector(8 downto 0);
        -- Data out
        rd   : out std_ulogic_vector(XLEN-1 downto 0);
        -- FIXME:  STB-Busy handshake
        Complete : out std_ulogic
    );
end e_alu;