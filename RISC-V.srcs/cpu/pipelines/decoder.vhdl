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
    
    -- Decoded information:
    --   - logicOp: operation type (ALU, flow control, mem, system)
    --   - operation flags (ALU flags that pass DIRECTLY to the ALU, etc.)
    --   - loadResource: data prep directions (whether to interpret r1 and
    --     r2 as registers, which type of immediate, whether to sign-extend,
    --     operation width, etc.)
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
    --  
    -- Non-ALU ops
    -- 7: illegal instruction
    -- 8: Comparison: SLTI, SLTIU
    --
    -- Load/Store
    -- 9: Load
    -- 10: Store
    signal logicOp : std_ulogic_vector(10 downto 0);
    alias lopAdd   : std_ulogic is logicOp(0); -- Adder-Subtractor
    alias lopSLL   : std_ulogic is logicOp(1);
    alias lopAND   : std_ulogic is logicOp(2);
    alias lopOR    : std_ulogic is logicOp(3);
    alias lopXOR   : std_ulogic is logicOp(4);
    alias lopMUL   : std_ulogic is logicOp(5);
    alias lopDIV   : std_ulogic is logicOp(6);
    alias lopIll   : std_ulogic is logicOp(7);
    alias lopSLT   : std_ulogic is logicOp(8);
    alias lopLoad  : std_ulogic is logicOp(9);
    alias lopStore : std_ulogic is logicOp(10);
    
    -- Operation flags
    -- bit 0:  *B
    -- bit 1:  *H
    -- bit 2:  *W
    -- bit 3:  *D? (128-bit)
    -- bit 4:  Unsigned
    -- bit 5:  Arithmetic (and Adder-Subtractor subtract)
    -- bit 6:  Right-shift
    -- bit 7:  MULHSU
    -- bit 8:  DIV Remainder
    signal opFlags : std_ulogic_vector(8 downto 0);
    alias opB   : std_ulogic is opFlags(0);
    alias opH   : std_ulogic is opFlags(1);
    alias opW   : std_ulogic is opFlags(2);
    --alias opD   : std_ulogic is opFlags(3);
    alias opUnS : std_ulogic is opFlags(4);
    alias opAr  : std_ulogic is opFlags(5);
    alias opRSh : std_ulogic is opFlags(6);
    alias opHSU : std_ulogic is opFlags(7);
    alias opRem : std_ulogic is opFlags(8);
    
    -- Load resource:  what to load
    -- bit 0:  R-type (rs1, rs2)
    -- bit 1:  I-type (rs1, insn[31:20] sign-extend)
    -- bit 2:  S-Type (rs1, insn[31:25] & insn[11:7] sign-extended)
    -- bit 3:  B-type (rs1, rs2, insn[31] & insn[7] & insn[30:25] & insn[11:8] sign-extend)
    -- bit 4:  U-type (insn[31:12])
    -- bit 5:  J-type (insn[31] & insn[19:12] & insn[20] & insn[30:25] & insn[24:21] sign-extend)
    signal loadResource : std_ulogic_vector(5 downto 0);
    alias lrR : std_ulogic is loadResource(0);
    alias lrI : std_ulogic is loadResource(1);
    alias lrS : std_ulogic is loadResource(2);
    alias lrB : std_ulogic is loadResource(3);
begin
    add : process(clk) is
        variable Iflg : std_ulogic := '0';
        variable Aflg : std_ulogic := '0';
    begin
        if (rising_edge(clk)) then
            -- FIXME:  Wipe these under some condition...or any condition?
            logicOp      <= (others => '0');
            opFlags      <= (others => '0');
            loadResource <= (others => '0');
            -- FIXME:  put the buffer on the output?
            if (rst = '1') then
                -- Reset, completely.  Don't care about anything.
                busy       <= '0';
                stbOut     <= '0';
                stbR       <= '0';
            -- FIXME:  must move the decoding stage to interact properly
            -- with the handshaking stage below
            -- TODO:  All opcode analysis up here
            -- 32-bit opcodes: aaa11 where aaa != 111
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
                        opW  <= opcode(3);
                        opAr <= funct7(5);
                        -- Arithmetic bit doesn't go to output for SUB
                        Aflg := funct7(5);
                        Iflg := NOT opcode(5); -- immediate
                        -- Check for illegal instruction
                        if (
                               ( (opAr = '1') AND (funct3 /= "000") AND (funct3 /= "101") ) -- not SUB or SRA
                            OR ( (Iflg = '1') AND (funct3 = "000") ) -- SUBI isn't an opcode
                            OR ( (opW = '1') AND (
                                                     (funct3 = "010") -- SLT
                                                  OR (funct3 = "011") -- SLTU
                                                  OR (funct3 = "100") -- XOR
                                                  OR (funct3 = "110") -- OR
                                                  OR (funct3 = "111") -- AND
                                                  )
                                )
                           ) then
                            -- illegal instruction
                            lopIll <= '1';
                        else
                            -- Determine instruction type for loadResource.
                            -- Load stage MUST check (lrI AND  
                            lrR <= NOT Iflg;
                            lrI <= Iflg;
                            -- Decode funct3
                            case funct3 is
                            when "000" =>
                                -- lrA determins add or subtract as per table above
                                lopAdd <= '1';
                            when "001"|"101" =>
                                lopSLL <= '1';
                                opAr  <= funct7(5);
                                --Right shift
                                opRSh <= '1' when funct3 = "101" else
                                         '0';
                            when "010"|"011" =>
                                lopSLT <= '1';
                                opUnS  <= '1' when funct3 = "011" else
                                          '0';
                            when "100" =>
                                lopXOR <= '1';
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
                        opW <= opcode(3);
                        if ( (opW = '1') AND (funct3(2) = '0') AND (funct3 /= "000") ) then
                            -- illegal instruction
                            lopIll <= '1';
                        else
                            -- funct3 = 0xx mul, 1xx div
                            lopMUL <= NOT funct3(2);
                            lopDIV <= funct3(2);
                            -- Much more compact than if statements
                            -- Half-word
                            case funct3 is
                            when "001"|"010"|"011" =>
                                opH <= '1';
                            end case;
                            case funct3 is
                            -- Unsigned
                            when "010"|"011"|"101"|"111" =>
                                opUnS <= '1';
                            end case;
                            -- Remainder
                            case funct3 is
                            when "110"|"111" =>
                                opRem <= '1';
                            end case;
                            -- MULHSU
                            opHSU <= '1' when funct3 = "010" else
                                     '0';
                        end if;
                        -- END RV32M/64M
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