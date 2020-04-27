-- vim: ts=4 sw=4 et
-- EPIC scheduler
--
-- The EPIC OOE scheduler does a few things:
--
--  - Determines dependencies
--  - Schedules instructions
--
-- This scheduler uses EPIC hints, as a proof-of-concept.
-- These hints are neither standardized nor stabilized.
--
-- DO NOT TARGET THESE HINTS IN PRODUCTION CODE.
--
-- EPIC Hint layout:  SLTI x0, x0, [hint]
--
--   imm[11:10] - EPIC mode
--   imm[9:8]   - EPIC block size
--   imm[7:0]   - EPIC interpretation distance
--
-- EPIC Hint layout:  C.SLLI x0, [hint]
--
--   imm[4:3]   - EPIC mode
--   imm[2:1]   - EPIC block size
--   imm[0]     - EPIC interpretation distance (0 = 8, 1 = 16)
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
--
-- Block size indicates the size of blocks:  shift 8 left this far to
-- get independent block size in bytes, i.e. two left to get independent
-- block size in 32-bit instruction words.  Blocks are aligned to this,
-- and the EPIC hint occurs as the first instruction in the first block.
--
-- 00 = Blocks of 2 32-bit instructions (8 bytes)
-- 01 = Blocks of 4 32-bit instructions (16 bytes)
-- 10 = Blocks of 8 32-bit instructions (32 bytes)
-- 11 = Blocks of 16 32-bit instructions (64 bytes)
--
-- RVC instructions can pack more into these blocks; VLIW instructions can
-- pack in fewer.  An instruction extending past the end of a block is a
-- misaligned instruction error; RVC NOP must pad the end of such blocks.
--
-- Branch instructions are never executed out of order and represent an
-- implicit FENCE both in memory operations and in execution.  Tight
-- loops may reorder instructions within the loop, but will not reorder
-- them beyond the branch instruction.
--
-- Branching into an EPIC stream carries interesting implications:  the
-- processor may cache EPIC information, or it may assume all instructions
-- are sequential after any branch, or after any branch leaving the
-- current EPIC context.
--
-- Compilers should explicitly assume implementations will retain EPIC
-- information for intra-context branches, and will not cache EPIC
-- informaiton outside the current context.  When branching outside the
-- current context, an instruction immediately preceding the branch
-- should provide an EPIC hint indicating where to locate the
-- corresponding EPIC hint:
--
--   SLT x0, [hint], [hint]
--
-- The [24:15] space encodes a value between 0 and 1024 indicating
-- how many 8-byte blocks to retrace for the EPIC hint.  If jumping
-- to an instruction in the middle of the first block, 0 indicates
-- a hint at the top of the current 8-byte-aligned block; 1
-- indicates the top of the current 16-byte-aligned block
-- (interpreted as the top of the PREVIOUS 8-byte-aligned block);
-- and so forth.
--
-- These hints allow extreme mass parallelization by specialized
-- implementations while foregoing complex superscalar resource
-- resolution.  Any block of independent instructions can use
-- transactional register and memory operations to implement
-- EPIC parallelism:  because an instruction doesn't use data
-- from a prior or later instruction BUT a later instruction
-- may write to a source register or store to RAM, we can
-- assume any writes are not and must not be visible to any
-- independent instruction, and so can simply cache the
-- contents of any register or memory address to be written
-- (writing them out as normal) and use those cached values
-- for any reads by any instructions.  Instructions must
-- NOT write to the same register or memory address.
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
    signal epicMode       : std_ulogic_vector(1 downto 0);
    signal epicLength     : std_ulogic_vector(1 downto 0);

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
            epicMode     <= insn(31 downto 30);
            epicLength   <= insn(29 downto 28);
            epicDistance <= unsigned(insn(27 downto 20));
        end if;
        -- TODO:  
    end process decode_hints;
end architecture;