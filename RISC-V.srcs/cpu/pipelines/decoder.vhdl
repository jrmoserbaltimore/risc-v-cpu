-- vim: sw=4 ts=4 et
-- Decoder to do sign extension and such

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.e_riscv_insn_2in;
use work.e_binary_adder;

entity e_decoder is
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
        -- Instruction to decode
        insn : in  std_ulogic_vector(31 downto 0);
        -- Context
        misa : in  std_ulogic_vector(31 downto 0);
        mstatus : in  std_ulogic_vector(XLEN-1 downto 0);
        ring : in  std_ulogic_vector(1 downto 0)
    );
end e_decoder;

-- Stage 1:  Fetch
-- Stage 2:  Decode
--   - identify what to load
--   - identify the instruction
--   - pass on to load stage
--    Pre-Stage:  Stage 1.5 can be a RVC decoder to convert
--                compressed instructions to their expanded form
-- Stage 3:  identify forward dependencies
--   OOE:  add current insn to forward dependencies, put in buffer,
--         start on next instruction; not meaningfully different
-- Stage 4:  load registers and sign-extend
-- Stage 5:  execute instruction
-- Stage 6:  memory fetch or write (for LOAD/STORE)
-- Stage 7:  retire (write all registers)
architecture riscv_decoder of e_decoder is 
    -- opcode is 0010011 if I-type, 0110011 if R-type
    alias opcode : std_ulogic_vector(6 downto 0)  is insn(6 downto 0);
    -- FIXME:  only valid for ADD; rewrite to generic
    alias rtype  : std_ulogic is opcode(5);
    -- This indicates ADD[I]W etc.
    alias W      : std_ulogic is opcode(3);
    alias funct3 : std_ulogic_vector(2 downto 0)  is insn(14 downto 12);
    -- I-type immediate value
    alias imm    : std_ulogic_vector(11 downto 0) is insn(31 downto 20);
    -- R-type
    alias funct7 : std_ulogic_vector(6 downto 0)  is insn(31 downto 25);
    alias Sub    : std_ulogic is insn(30);
    alias mxl    : std_ulogic_vector(1 downto 0)  is misa(31 downto 30);
    -- Breaks if you try to build RV32-only.
    alias sxl    : std_ulogic_vector(1 downto 0)  is mstatus(35 downto 34);
    alias uxl    : std_ulogic_vector(1 downto 0)  is mstatus(35 downto 34);

    -- Output to next stage
    signal stbOut : std_ulogic := '0';
    signal busyIn : std_ulogic := '0';

    signal insnOut : std_ulogic_vector(insn'LENGTH downto 0);
    signal misaOut : std_ulogic_vector(misa'LENGTH downto 0);
    signal mstatusOut : std_ulogic_vector(mstatus'LENGTH downto 0);
    signal ringOut : std_ulogic_vector(ring'LENGTH downto 0);

    -- Buffer
    signal stbR   : std_ulogic := '0';

    signal insnBuf : std_ulogic_vector(insn'LENGTH downto 0);
    signal misaBuf : std_ulogic_vector(misa'LENGTH downto 0);
    signal mstatusBuf : std_ulogic_vector(mstatus'LENGTH downto 0);
    signal ringBuf : std_ulogic_vector(ring'LENGTH downto 0);
    
    -- What data to load by reading the insn
    -- bit 0:  rs1
    -- bit 1:  rs2
    -- bit 2:  I-Type imm
    -- bit 3+2:  I-type + rs1 (LD)
    -- bit 4:  S-type imm
    -- bit 5:  sign-extend (????)
    -- bit 6:  64-bit W instruction (non-W is determined by context XLEN)
    signal loadResource : std_ulogic_vector(5 downto 0);
    -- What operation
    -- bit 0:  adder-subtractor (ADD, SUB, etc) (inst(30) indicates sub)
    -- bit 1:  shifter (funct(3) indicates operation; inst(30) indicates arithmetic)
    -- bit 2:  bitmasks (funct(3) indicates mask)
    -- bit 3:  multiplier-divider (funct3+inst(3) indicates operation)  
    signal logicOp : std_ulogic_vector(5 downto 0);
begin
    add : process(clk) is
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                -- Reset, completely.  Don't care about anything.
                busy       <= '0';
                stbOut     <= '0';
                stbR       <= '0';
            -- FIXME:  must move the decoding stage to interact properly
            -- with the handshaking stage below
            elsif (    (opcode = "0110011" OR opcode = "0110011") 
                   AND (funct7 = "0000000" OR funct7 = "0100000")) then
                -- R-type RV32I/RV64I
                -- W operations: 011w011
                -- funct7   funct3  opcode      insn    opcode-mod
                -- 0000000  000     0110011     ADD     ANDW
                -- 0100000  000     0110011     SUB     SUBW
                -- 0000000  001     0110011     SLL     SLLW
                -- 0000000  010     0110011     SLT
                -- 0000000  011     0110011     SLTU
                -- 0000000  100     0110011     XOR
                -- 0000000  101     0110011     SRL     SRLW
                -- 0100000  101     0110011     SRA     SRAW
                -- 0000000  110     0110011     OR
                -- 0000000  111     0110011     AND
                case funct3 is
                    when "000" =>
                        if (funct7 = "0100000") then
                            -- SUB
                        end if;
                end case;

            -- todo:  handle handshake and data passing            
            elsif (busyIn = '0') then
                -- The next stage is not busy, so send it data
                if (stbR = '0') then -- FIXME:  AND ready to send data
                    -- Nothing in the strobe buffer, send output when ready
                    -- signal data strobe
                    stbOut <= stb;
                    -- compute and attach output 
                    -- insnOut;
                    -- misaOut;
                    -- mstatusOut;
                    -- ringOut;
                else
                    stbOut <= '1';
                    -- Flush buffer 
                    -- insnOut;
                    -- misaOut;
                    -- mstatusOut;
                    -- ringOut;
                end if;
                -- we're not busy because input isn't busy
                busy <= '0';
                -- Register has just been flushed
                stbR <= '0';
            end if;
        end if;
    end process add;
end riscv_decoder;