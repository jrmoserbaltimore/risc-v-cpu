-- vim: ts=4 sw=4 et
-- Post-decode
--
-- Fetch->Decode->Load->PostDecode->...
--
-- Performs variant and environment decoding (e.g. determining correct
-- XLEN context, sign extension, processor feature settings)
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity e_pipeline_load is
    generic
    (
        XLEN : natural := 64;
        FmaxFactor : positive := 1
    );
    port
    (
        -- Control port
        Clk      : in  std_ulogic;
        Rst      : in  std_ulogic;
        Stb      : in  std_ulogic;
        Busy     : out std_ulogic;
        -- Reset signal propagates after CPU reset.
        -- All recipients must dump their buffers.
        -- Output handshake
        StbOut   : out std_ulogic;
        BusyOut  : in std_ulogic;
        -- Instruction to decode
        insn : in  std_ulogic_vector(31 downto 0);
        -- Context
        misa : in  std_ulogic_vector(31 downto 0);
        mstatus : in  std_ulogic_vector(XLEN-1 downto 0);
        ring : in  std_ulogic_vector(1 downto 0);
        ------------
        -- Output --
        ------------
        -- program counter
        pc : in std_ulogic_vector(XLEN-2 downto 0);
        -- term 1 and term 2
        -- immediates are passed in sign-extended if necessary
        rs1  : in  std_ulogic_vector(XLEN-1 downto 0);
        rs2  : in  std_ulogic_vector(XLEN-1 downto 0);
        -- Function selector
        -- 0: add, sub: ADD, ADDI, SUB; 64 ADDW, ADDIW, SUBW
        -- 1: shift: SLL, SLLI, SRL, SRLI, SRA; 64 SLLIW, SRRIW, SRAIW
        -- 2: Comparator (SLT, SLTU, SLTI, SLTIU)
        -- 3: AND: AND, ANDI
        -- 4: OR: OR, ORI
        -- 5: XOR: XOR, XORI
        --
        -- Extension: M
        -- 6: Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
        -- 7: Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
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
end e_pipeline_load;