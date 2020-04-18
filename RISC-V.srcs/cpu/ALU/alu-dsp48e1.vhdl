-- vim: sw=4 ts=4 et
-- Xilinx DSP48E1 ALU
--
-- This ALU specifically uses the Xilinx DSP48E1 to implement
-- all ALU operations, including the adder-subtractor, bit
-- shifts, multiplication, and division.
--
-- This work is based on Cheah Hui Yan's iDEA FPGA processor,
-- described in his 2016 Ph.D. thesis:
-- "The iDEA Architecture-Focused FPGA Soft Processor"
--
-- Chea Hui Yan is now an engineer at Xilinx, according to
-- LinkedIn.
library IEEE;
use IEEE.std_logic_1164.all;
use work.e_alu;

-- Approach:
--   - Instantiate two DSP48E1
architecture xilinx_dsp48e1_alu of e_alu is
    -- What operation
    -- ALU ops
    -- 0: add, sub: ADD, ADDI, SUB; 64 ADDW, ADDIW, SUBW
    -- 1: shift: SLL, SLLI, SRL, SRLI, SRA; 64 SLLIW, SRRIW, SRAIW
    -- 2: AND: AND, ANDI
    -- 3: OR: OR, ORI
    -- 4: XOR: XOR, XORI
    --
    -- Extension: M
    -- 5: Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
    -- 6: Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
    alias lopAdd   : std_ulogic is logicOp(0);
    alias lopSLL   : std_ulogic is logicOp(1);
    alias lopAND   : std_ulogic is logicOp(2);
    alias lopOR    : std_ulogic is logicOp(3);
    alias lopXOR   : std_ulogic is logicOp(4);
    alias lopMUL   : std_ulogic is logicOp(5);
    alias lopDIV   : std_ulogic is logicOp(6);
    
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
    alias opB   : std_ulogic is opFlags(0);
    alias opH   : std_ulogic is opFlags(1);
    alias opW   : std_ulogic is opFlags(2);
    alias opD   : std_ulogic is opFlags(3);
    alias opUnS : std_ulogic is opFlags(4);
    alias opAr  : std_ulogic is opFlags(5);
    alias opRSh : std_ulogic is opFlags(6);
    alias opHSU : std_ulogic is opFlags(7);
    alias opRem : std_ulogic is opFlags(8);
begin
        --XLEN : natural;
        --FmaxFactor : positive := 1

    -- Adder-Subtractor uses the DSP's adder and accumulator.
    -- 64-bit requires Two DSP48E1 slices and 128-bit requires
    -- three, as they are 48-bit adds with carry output.
    --
    -- Han-Carlson adder at 128-bits incurs 17 gate delays;
    -- 64-bits incurse 15; 32-bits incurs 13. At 140ps total
    -- delay per gate, this is 420MHz for 128-bit; 160ps
    -- for 420MHz at 64-bit; 180ps for 420MHz at 32-bit.
    --
    -- A speculative Han-Carlson adder can operate 10% faster
    -- in most cases, costing an extra clock cycle in rare
    -- cases of error.
    --
    -- Notably, a single DSP can provide carry input to a
    -- 16-bit adder for 64-bit computations, and two DSPs
    -- and a 32-bit adder can provide 128-bit addition.
    --
    -- These figures represent the maximum average delay per
    -- gate, including routing and gate delay, for a fabric
    -- adder to reach near-maximum speeds on a Spartan-7.
    -- DSP may reduce area, power consumption, and delay.



    -- 17-bit barrel shifter in the DSP.  Routing to multiple
    -- DSPs or multi-cycle shifting may slow down instructions
    -- per second. Parallel execution is necessary to work around
    -- this barrel shifter delay.
    --
    -- On the other hand, a 128-bit reversible barrel shifter
    -- produces 12 gate delays, but possibly large routing delay.
    -- A combined gate and routing delay of 0.2ns per gate
    -- produces a 415MHz fMax at 128-bit, 454MHz at 64-bit. 


    -- Bitwise operations are supported by the DSP up to 48 bits.
    -- fMax is unlikely to be bound by fabric bitwise operations.


    -- Multiplier uses partial product and accumulator feedback,
    -- acting as a high-frequency multi-cycle instruction.


    -- Divider obtains and caches the remainder and product to
    -- catch the RISC-V M specified sequence:
    --   DIV[U] rdq, rs1, rs2
    --   REM[U] rdq, rs1, rs2
    -- This sequence is fused together into a single divide.
    --
    -- Various divider components are possible, e.g. Paravartya.
    -- The ALU requires a divider implementation, as the DSP
    -- does not provide one.

end xilinx_dsp48e1_alu;


-- DSP wrapper to provide add/sub/mul/div with a simple interface 
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.e_binary_adder;

Library UNISIM;
use UNISIM.vcomponents.all;

entity e_dsp48e1_wrap is
    generic
    (
        XLEN : natural
    );
    port
    (
        -- Only needs to tell prior stage it's busy;
        -- internal signals connect to forward stages
        clk  : in  std_ulogic;
        stb  : in  std_ulogic; 
        busy : out std_ulogic;
        -- Reset signal propagates after CPU reset.
        -- All recipients must dump their buffers.
        rst  : in  std_ulogic;
        -- Inputs
        A    : in  std_ulogic_vector(XLEN-1 downto 0);
        B    : in  std_ulogic_vector(XLEN-1 downto 0);
        -- Function selector
        -- 0: add
        -- 1: subtract
        -- 2: Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
        -- 3: Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
        logicOp : in  std_ulogic_vector(3 downto 0);
        -- Operation flags
        -- bit 0:  *B
        -- bit 1:  *H
        -- bit 2:  *W
        -- bit 3:  *D
        -- bit 4:  Unsigned
        -- bit 5:  MULHSU
        opflags : in  std_ulogic_vector(8 downto 0);
        -- Multiplier output can be twice the XLEN
        result    : out std_ulogic_vector((XLEN*2)-1 downto 0);
        -- Remainder can be the size of divisor 
        remainder : out std_ulogic_vector(XLEN-1 downto 0)
    );
end e_dsp48e1_wrap;

architecture dsp48e1_wrap of e_dsp48e1_wrap is
begin

   --DSP: DSP48E1

end architecture;