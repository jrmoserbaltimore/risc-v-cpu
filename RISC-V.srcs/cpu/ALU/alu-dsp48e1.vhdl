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
use IEEE.math_real."ceil";
use ieee.math_real."log2";
use work.e_alu;
use work.e_barrel_shifter;

--   _____________
--  |        |    |
--  |       DIV SHIFT
--  |         | |
--  |-----MUL OR    enDiv enShift
--  |  ***  | /         | /
--  | INPUT OR    EnMul OR
--  |  |  ___|        | /
--  |  | |            OR
--  |  | |            |
--  |  MUX------------
--  |   |
--  |  DSP
--  |___|
--      |
--    OUTPUT
--     ***
--
-- Approach:
--   - Instantiate cascading DSP48E1 units
--   - Fan out input data to a mux on the DSP and a separate mux
--     fanning out to SHIFT, MUL, and DIV.
--   - Fan DSP output out to both output and the muxes on MUL and
--     DIV complex multiplier and divider circuits
--   - Input data to MUL, DIV, and SHIFT are attached to AND gates
--     for enMul, enDiv, and enShift, so these circuits naturally
--     receive all zero for input
--   - The MUL and DIV circuits control the Mux to select DSP output
--     as their respective input

-- DSP operations face only a single input mux on the critical path,
-- and that mux idles favoring the input.  DSP handles addition,
-- subtraction, and bitwise AND, OR, and XOR.  All other circuits
-- pass output through the DSP set to OR with zero to avoid muxes
-- in the output path.
--
-- SHIFT is relatively-fast and has to pass through two OR gates
-- and a mux to reach the DSP input.
--
-- MUL and DIV are multi-cycle instructions.  MUL gets the fastest
-- path to the DSP, being more-common than DIV.
--
-- SHIFT, MUL, and DIV are disabled and cannot affect the DSP
-- unless signals to use the respective operations are raised.
-- The enDiv and enMul signals enable their output so the three
-- don't collide.
--
-- The INPUT fan-out is two (DSP MUX and other ops MUX); the
-- OUTPUT fan-out is two (output and other ops input MUX).
--
-- The DSP provides the adder and effectively gets the shortest
-- critical path.  The DSP becomes a tool used by MUL and DIV.
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
    alias lopShift : std_ulogic is logicOp(1);
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
    
    signal barrelOut : std_ulogic_vector(XLEN-1 downto 0);
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
    -- These figures represent the maximum average delay per
    -- gate, including routing and gate delay, for a fabric
    -- adder to reach near-maximum speeds on a Spartan-7.
    -- DSP may reduce area, power consumption, and delay.

    --  TODO: dsp48e1_op <= ADD

    -- The DSP contains no large barrel shifter.  A 128-bit
    -- reversible barrel shifter produces 12 gate delays, but
    -- possibly large routing delay.  A combined gate and
    -- routing delay of 0.2ns per gate produces a 415MHz fMax
    -- at 128-bit, 454MHz at 64-bit.  Longer delay requires
    -- a delay when shifting.
    --
    -- XLEN will be 32, 64, or 128, and will instantiate a shifter
    -- that many bits wide.
    barrel_shifter: entity e_barrel_shifter(barrel_shifter)
    generic map (XLEN      => XLEN)
    port map (
        Din        => rs1,
        Shift      => rs2(integer(ceil(log2(real(XLEN))))-1 downto 0),
        ShRight    => opRSh,
        Arithmetic => opAr,
        Dout       => barrelOut
    );
    -- TODO:  take current XLEN into account and sign-extend
    --rd <= barrelOut when lopShift = '1';
    
    -- Bitwise operations are supported by the DSP up to 48 bits.
    -- fMax is unlikely to be bound by fabric bitwise operations,
    -- but the inputs will already be tied to the DSP and so only
    -- a change of DSP ALU operation is necessary.
    --
    -- The barrel shifter routes around the DSP and into a muxer,
    -- so the input fans out to either the DSP or the shifter.
    -- Fabric logic would require additional fan-out and three
    -- more rows of muxers on the output, adding delay. 

    -- TODO:  

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
        -- 2: AND: AND, ANDI
        -- 3: OR: OR, ORI
        -- 4: XOR: XOR, XORI
        -- 5: Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
        -- 6: Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
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
    -- Rearranging the functions doesn't bother the architecture
    alias lopAdd   : std_ulogic is logicOp(0);
    alias lopSub   : std_ulogic is logicOp(1);
    alias lopAND   : std_ulogic is logicOp(2);
    alias lopOR    : std_ulogic is logicOp(3);
    alias lopXOR   : std_ulogic is logicOp(4);
    alias lopMUL   : std_ulogic is logicOp(5);
    alias lopDIV   : std_ulogic is logicOp(6);
    
    alias opB   : std_ulogic is opFlags(0);
    alias opH   : std_ulogic is opFlags(1);
    alias opW   : std_ulogic is opFlags(2);
    alias opD   : std_ulogic is opFlags(3);
    alias opUnS : std_ulogic is opFlags(4);
    alias opHSU : std_ulogic is opFlags(5);
begin

   --DSP: DSP48E1

end architecture;