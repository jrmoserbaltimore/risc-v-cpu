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
    -- working set, either from input or buffered storage
    signal insnWk : std_ulogic_vector(insn'RANGE);
    signal misaWk : std_ulogic_vector(misa'RANGE);
    signal mstatusWk : std_ulogic_vector(mstatus'RANGE);
    signal ringWk : std_ulogic_vector(ring'RANGE);
    -- opcode
    alias opcode : std_ulogic_vector(6 downto 0)  is insnWk(6 downto 0);
    alias funct3 : std_ulogic_vector(2 downto 0)  is insnWk(14 downto 12);
    -- I-type immediate value
    alias imm    : std_ulogic_vector(11 downto 0) is insnWk(31 downto 20);
    -- R-type
    alias funct7 : std_ulogic_vector(6 downto 0)  is insnWk(31 downto 25);
    alias Sub    : std_ulogic is insn(30);
    alias mxl    : std_ulogic_vector(1 downto 0)  is misaWk(31 downto 30);
    -- Breaks if you try to build RV32-only.
    alias sxl    : std_ulogic_vector(1 downto 0)  is mstatusWk(35 downto 34);
    alias uxl    : std_ulogic_vector(1 downto 0)  is mstatusWk(35 downto 34);

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
    
    
    
    -- BIG FIXME --
    -- Rearchitect decoded information:
    --   - logicOp: operation type (ALU, flow control, mem, system)
    --   - operation flags (ALU flags that pass DIRECTLY to the ALU, etc.)
    --   - loadResource: data prep directions (whether to interpret r1 and
    --     r2 as registers, which type of immediate, whether to sign-extend,
    --     operation width, etc.)
    --
    -- Need to figure out how to pass H (e.g. MULH), signed, and unsigned
    -- attributes; as well as where I want to pass W (ADDW, MULW).
    -- 
    -- Theory:
    --   The loadResource flags tell the Load stage when to get rs1 (as
    --   argument 1), rs2 (as argument 2), or some particular immediate (as
    --   argument 1, 2, or 3).  The Load stage understands the fixed
    --   locations of rs1 and rs2; as well as various immediate value
    --   formats.
    --
    --   The Load stage must be instructed to sign extension as appropriate.
    --
    --   The Load stage passes the parameters here to the Execute stage,
    --   which will interpret logicOp and the operation flags to determine
    --   what exactyl to execute.  An ALU operation will generally pass
    --   logicOp(9 downto 0) directly to the ALU, along with the relevant
    --   information about how to operate on the arguments given.
    -- END BIG FIXME --
    
    -- What data to load by reading the insn
    -- bit 0:  rs1
    -- bit 1:  rs2
    -- bit 2:  I-Type imm
    -- bit 3+2:  I-type + rs1 (LD)
    -- bit 4:  S-type imm
    -- bit 5:  sign-extend (????)
    -- bit 6:  Unsigned
    -- bit 7:  64-bit W instruction (non-W is determined by context XLEN)
    -- bit 8:  Arithmetic
    signal loadResource : std_ulogic_vector(10 downto 0);
    alias lrU : std_ulogic is loadResource(6);
    alias lrW : std_ulogic is loadResource(7);
    alias lrA : std_ulogic is loadResource(8);
    -- What operation
    -- ALU ops
    -- 0: add: ADD, ADDI; 64 ADDW, ADDIW 
    -- 1: sub: SUB; 64 SUBW
    -- 2: shift left: SLL, SLLI; 64 SLLIW
    -- 3: shift right: SRL, SRLI; 64 SRRIW
    -- 4: shift right arithmetic: SRA, SRAI; 64 SRAIW
    -- 5: AND: AND, ANDI
    -- 6: OR: OR, ORI
    -- 7: XOR: XOR, XORI
    -- Extension: M
    -- 8: Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
    -- 9: Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
    --  
    -- Non-ALU ops
    -- 10: illegal instruction
    -- 11: Comparison: SLTI, SLTIU
    signal logicOp : std_ulogic_vector(11 downto 0);
    alias lopAdd : std_ulogic is logicOp(0);
    alias lopSub : std_ulogic is logicOp(1);
    alias lopSLL : std_ulogic is logicOp(2);
    alias lopSRL : std_ulogic is logicOp(3);
    alias lopSRA : std_ulogic is logicOp(4);
    alias lopAND : std_ulogic is logicOp(5);
    alias lopOR  : std_ulogic is logicOp(6);
    alias lopXOR : std_ulogic is logicOp(7);
    alias lopMUL : std_ulogic is logicOp(8);
    alias lopDIV : std_ulogic is logicOp(9);
    alias lopIll : std_ulogic is logicOp(10);
    alias lopSLT : std_ulogic is logicOp(11);
begin
    add : process(clk) is
        variable Iflg : std_ulogic := '0';
        variable Aflg : std_ulogic := '0';
    begin
        if (rising_edge(clk)) then
            -- FIXME:  Wipe logicOp under some condition...or any condition?
            logicOp <= (others => '0');
            -- FIXME:  put the buffer on the output?
            if (rst = '1') then
                -- Reset, completely.  Don't care about anything.
                busy       <= '0';
                stbOut     <= '0';
                stbR       <= '0';
            -- FIXME:  must move the decoding stage to interact properly
            -- with the handshaking stage below
            -- TODO:  All opcode analysis up here
            elsif (    ((opcode AND "0010011") = "0010011") -- These bits on
                   AND ((opcode AND "1000100") = "0000000")) then -- These bits off
                     -- Essential mask 0_1_011
                    if ((funct7 AND "1011111") = "0000000") then
                        -- RV32I/RV64I Arithmetic operations
                        -- W operations: 0i1w011
                        -- funct7   funct3  opcode      insn    opcode-w=1  opcode-i=0  opcode-i=0,w=1
                        -- 0000000  000     0i1w011     ADD     ADDW        ADDI        ADDIW
                        -- 0100000  000     0i1w011     SUB     SUBW
                        -- 0000000  001     0i1w011     SLL     SLLW        SLLI        SLLIW
                        -- 0000000  010     0i1w011     SLT                 SLTI
                        -- 0000000  011     0i1w011     SLTU                SLTIU
                        -- 0000000  100     0i1w011     XOR                 XORI
                        -- 0000000  101     0i1w011     SRL     SRLW        SRLI        SRLIW
                        -- 0100000  101     0i1w011     SRA     SRAW        SRAI        SRAIW
                        -- 0000000  110     0i1w011     OR                  ORI
                        -- 0000000  111     0i1w011     AND                 ANDI
                        -- extract W and I bits
                        lrW <= opcode(3);
                        -- Arithmetic bit doesn't go to output for SUB
                        Aflg := funct7(5);
                        Iflg := NOT opcode(5);
                        -- Check for illegal instruction
                        if (
                               ( (Aflg = '1') AND (OR (logicOp AND NOT "10001") /= '0') ) -- not SUB or SRA
                            OR ( (Iflg = '1') AND (logicOp(1) = '1') ) -- SUBI isn't an opcode
                            OR ( (lrW = '1') AND (OR (logicOp AND "100011100000") /= '0') ) ) then -- Bitops, SLT
                            -- illegal instruction
                            lopIll <= '1';
                        else
                            -- Decode funct3
                            case funct3 is
                            when "000" =>
                                -- lrA determins add or subtract as per table above
                                lopSub <= lrA;
                                lopAdd <= NOT lrA;
                            when "001" =>
                                lopSLL <= '1';
                            when "010" =>
                                lopSLT <= '1';
                            when "011" =>
                                lopSLT <= '1';
                                lrU    <= '1';
                            when "100" =>
                                lopXOR <= '1';
                            when "101" =>
                                -- SRL when not arithmetic.
                                -- Put the Arithmetic bit into the output
                                lrA    <= Aflg;
                                lopSRL <= NOT lrA;
                                lopSRA <= lrA;
                            when "110" =>
                                lopOR <= '1';
                            when "111" =>
                                lopAND <= '1';
                            end case;
                        end if;
                        -- We now know:
                        --   - the instruction is valid/invalid
                        --   - What valid operation it is
                        --   - Whether it's an *I, *W, or arithmetic shift 
                        -- END RV32I/64I Arithmetic operations
                    elsif ( ((opcode OR "0001000") = "0111011") -- Only these bits on
                         AND (funct7 = "0000001")) then
                        -- Essential mask 011_011
                        -- RV32M/RV64M operations
                        -- W operations: 011w011
                        -- funct7   funct3  opcode      insn    opcode-w=1  Notes
                        -- 0000001  000     011w011     MUL     MULW
                        -- 0000001  001     011w011     MULH                Upper XLEN bits for 2*XLEN product
                        -- 0000001  010     011w011     MULHSU              Same, r1 signed * r2 unsigned
                        -- 0000001  011     011w011     MULHU               Same, r1 and r2 both unsigned
                        -- 0000001  100     011w011     DIV     DIVW
                        -- 0000001  101     011w011     DIVU    DIVUW
                        -- 0000001  110     011w011     REM     REMW
                        -- 0000001  111     011w011     REMU    REMUW
                        -- extract W bit
                        lrW <= opcode(3);
                        if ( (lrW = '1') AND (funct3(2) = '0') AND (funct3 /= "000") ) then
                            -- illegal instruction
                            lopIll <= '1';
                        else
                            -- funct3 = 0xx mul, 1xx div
                            lopMUL <= NOT funct3(2);
                            lopDIV <= funct3(2);
                            -- FIXME:  MUL[HSU], DIV[U], REM[U]
                            -- pass r1/r2 signed/unsigned and an H bit flag
                        end if;
                    end if;
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