-- vim: ts=4 sw=4 et
-- EPIC scheduler
--
-- The EPIC OOE scheduler does a few things:
--
--  - Identifies hints, notably RESET (SLL x0, x0, x0)
--  - Determines dependencies
--  - Schedules instructions
--
-- This scheduler uses EPIC hints, as a proof-of-concept.
-- These hints are neither standardized nor stabilized.
--
-- DO NOT TARGET THESE HINTS IN PRODUCTION CODE.
--
-- epicMode bits:
--
-- Bit 0: Independent - if 0, each set of n of blocks can execute in parallel,
--                      but must execute sequentially, and each set depends
--                      on the previous set.  If 1, each block depends on
--                      the previous block, but all instructions within the
--                      block are independent of one another.
-- Bit 1: Width       - Modifies the above:
--
--    00:  Each pair of blocks executes in parallel, but their instructions
--         execute sequentially; each pair depends on previous pair.
--    01:  Each block must execute sequentially, but each block is composed
--         exclusively of independent instructions.
--    10:  Sets of FOUR blocks execute in parallel, but their instructions
--         are sequential; each set of four depends on the previous set.
--    11:  Hybrid:  The first pair of blocks executes as one superblock of
--         independent instructions; the next pair must execute after the
--         first pair, may execute in parallel, and are each composed of
--         instructions which must execute in sequence.
--
-- Bits 2 and 3 reserved.
--
-- Mode 00 (non-independent) visual:
--
--   --------------------------
--     Block 1   |  Block 2     Blocks executed in parallel
--    Sequential | Sequential
--   --------------------------
--     Block 3   |  Block 4     Blocks executed AFTER 1 and 2
--    Sequential | Sequential
--   --------------------------
--
--
-- Mode 01 (independent) visual:
--
--   ------------
--     Block 1   
--     Parallel 
--   ------------
--     Block 2   
--     Parallel 
--   ------------
--
-- Mode 10 (wide-independent) visual:
--
--   ---------------------------------------------------
--     Block 1   |  Block 2   |  Block 3   |  Block 4
--    Sequential | Sequential | Sequential | Sequential
--   ---------------------------------------------------
--     Block 5   |  Block 6   |  Block 7   |  Block 8
--    Sequential | Sequential | Sequential | Sequential
--   ---------------------------------------------------
--
-- Mode 11 (Hybrid) visual:
--
--   --------------------------
--      Block 1   +  Block 2
--    Independent instructions
--   --------------------------
--     Block 3   |  Block 4
--    Sequential | Sequential
--   --------------------------
--
-- Independent instructions are defined as fitting the following
-- constraints:
--
--   - No instruction relies on the result of another instruction
--   - No instruction writes to the same register as another instruction
--
-- Independent instructions CAN clobber one another's registers, i.e.
-- in order an instruction may read from rdx, rdy and write to rdz,
-- while the next reads from rdw, rdx and writes to rdy.  Executing these
-- out of order clobbers rdy; register renaming is necessary to prevent
-- this clobbering, but is already necessary for parallel execution of
-- sequential blocks.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Fixme:  needs its own entity
architecture pipeline_scheduler of e_pipeline_load is
    alias lopAdd   : std_ulogic is logicOp(0);
    alias lopShift : std_ulogic is logicOp(1);
    alias lopCmp   : std_ulogic is logicOp(2);
    alias lopAND   : std_ulogic is logicOp(3);
    alias lopOR    : std_ulogic is logicOp(4);
    alias lopXOR   : std_ulogic is logicOp(5);
    alias lopMUL   : std_ulogic is logicOp(6);
    alias lopDIV   : std_ulogic is logicOp(7);
    alias lopIll   : std_ulogic is logicOp(8);
    alias lopLoad  : std_ulogic is logicOp(9);
    alias lopStore : std_ulogic is logicOp(10);

    alias opB   : std_ulogic is opFlags(0);
    alias opH   : std_ulogic is opFlags(1);
    alias opW   : std_ulogic is opFlags(2);
    alias opD   : std_ulogic is opFlags(3);
    alias opUnS : std_ulogic is opFlags(4);
    alias opAr  : std_ulogic is opFlags(5);
    alias opRSh : std_ulogic is opFlags(6);
    alias opHSU : std_ulogic is opFlags(7);
    alias opRem : std_ulogic is opFlags(8);

    alias lrR : std_ulogic is loadResource(0);
    alias lrI : std_ulogic is loadResource(1);
    alias lrS : std_ulogic is loadResource(2);
    alias lrB : std_ulogic is loadResource(3);
    alias lrU : std_ulogic is loadResource(4);
    alias lrJ : std_ulogic is loadResource(5);
    alias lrUPC : std_ulogic is loadResource(6);
    
    alias rdIdx  : std_ulogic_vector(5 downto 0) is insn(6 downto 0);
    alias rs1Idx : std_ulogic_vector(5 downto 0) is insn(19 downto 15);
    alias rs2Idx : std_ulogic_vector(5 downto 0) is insn(24 downto 15);
    -- FIXME:  Placeholder code
    signal LRout : std_ulogic_vector(LoadResource'RANGE);
    
    -- Up to 256 blocks of independent instructions
    signal epicDistance   : unsigned(7 downto 0);
    -- Block size:  shift four left this far to get independent block size,
    -- e.g. 00 = every group of 4 instructions are independent of one
    -- another, 01 = groups of 8, 10 = 16, 11 = 32
    signal epicMode       : std_ulogic_vector(3 downto 0);

begin
    
    decode_hints: process(clk) is
    begin
        if (LoadResource = "000011") then
            -- reset
        end if;
        -- POC EPIC hints, using SLTI x0
        if( (lopCmp = '1')
           AND (opUnS = '0')
           AND (opW = '0')
           AND (lrI = '1')
           AND (rd = "00000") -- x0:  hint
        ) then
            epicDistance <= unsigned(insn(27 downto 20));
            epicMode     <= insn(31 downto 28);
        end if;
        -- TODO:  
    end process decode_hints;
end architecture;