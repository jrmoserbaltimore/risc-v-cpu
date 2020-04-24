-- vim: sw=4 ts=4 et
--
-- Arithmetic logic unit (Fabric/ASIC)
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
use IEEE.math_real."ceil";
use ieee.math_real."log2";
use work.e_binary_adder;
use work.e_barrel_shifter;

entity e_alu is
    generic
    (
        XLEN : natural := 64;
        FmaxFactor : positive := 1;
        Adder : string := "Han-Carlson"; -- or Ladner-Fischer
        Multiplier : string := "Dadda";
        Divider : string := "Quick-Div"
    );
    port
    (
        clk   : in  std_ulogic;
        clkEn : in  std_ulogic;
        -- Reset when giving new data, for multi-cycle
        -- instructions (Replace with STB-BUSY)
        rst  : in  std_ulogic;
        -- Context
        misa : in  std_ulogic_vector(31 downto 0);
        mstatus : in  std_ulogic_vector(XLEN-1 downto 0);
        ring : in  std_ulogic_vector(1 downto 0);
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
end e_alu;

architecture alu of e_alu is
    -- What operation
    alias lopAdd   : std_ulogic is logicOp(0);
    alias lopShift : std_ulogic is logicOp(1);
    alias lopCmp   : std_ulogic is logicOp(2);
    alias lopAND   : std_ulogic is logicOp(3);
    alias lopOR    : std_ulogic is logicOp(4);
    alias lopXOR   : std_ulogic is logicOp(5);
    alias lopMUL   : std_ulogic is logicOp(6);
    alias lopDIV   : std_ulogic is logicOp(7);
    
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

    signal addsubOut  : std_ulogic_vector(XLEN-1 downto 0);
    signal barrelOut  : std_ulogic_vector(XLEN-1 downto 0);
    signal bitwiseOut : std_ulogic_vector(XLEN-1 downto 0);
    
    -- Various information
    alias mxl    : std_ulogic_vector(1 downto 0)  is misa(31 downto 30);
    -- Breaks if you try to build RV32-only.
    alias sxl    : std_ulogic_vector(1 downto 0)  is mstatus(35 downto 34);
    alias uxl    : std_ulogic_vector(1 downto 0)  is mstatus(35 downto 34);
    signal xlenC : std_ulogic_vector(1 downto 0);
    
    -- In from adder
    signal adderBusy   : std_ulogic;
    signal adderStbOut : std_ulogic; -- Adder has data ready
    -- Out to Adder
    signal adderStb    : std_ulogic := '0';
    signal adderBusyOut : std_ulogic := '0'; -- Can't take data from adder right now
    
    -- Pipeline
    -- Subcomponent
    signal CmpStb   : std_ulogic; -- ALU sends this
    signal CmpBusy  : std_ulogic; -- ALU listens for this
    signal CmpOStb  : std_ulogic; -- ALU listens for this
    signal CmpOBusy : std_ulogic; -- ALU sends this 
begin

    sch_adder: if (Adder = "Han-Carlson") generate
        -- FIXME:  Attach A, B, and Sub to internal signals for multiplier-divider use 
        adder_component: entity e_binary_adder(speculative_han_carlson_adder)
            generic map
            (
                XLEN => XLEN
            )
            port map
            (
                -- Control
                Clk      => Clk,
                Rst      => Rst,
                Speculate => '1',
                Stb      => adderStb,
                Busy     => adderBusy,
                -- Input
                A        => rs1,
                B        => rs2,
                Sub      => opAr,
                -- Output
                StbOut   => adderStbOut,
                BusyOut  => adderBusyOut,
                S        => addsubOut
                -- Control
            );
    end generate;
    -- XLEN will be 32, 64, or 128, and will instantiate a shifter
    -- that many bits wide.
    -- FIXME:  attach Din, Shift, and opFlags to internal signals
    -- for multiplier-divider use
    barrel_shifter: entity e_barrel_shifter(barrel_shifter)
    generic map (
        XLEN      => XLEN
    )
    port map (
        Din        => rs1,
        Shift      => rs2(integer(ceil(log2(real(XLEN)))) downto 0),
        opFlags    => (opRSh, opAr),
        Dout       => barrelOut
    );

    -- TODO:  Instantiate multiplier and divider based on generic 
    alu_p : process(clk) is
    begin
        if (rising_edge(clk) and clkEn = '1') then
            bitwiseOut <= (rs1 AND rs2) when lopAND = '1' else
                          (rs1 OR rs2) when lopOR = '1' else
                          (rs1 XOR rs2) when lopXOR = '1' else
                          (others => '0');
        end if;
        
        -- Direct the output
        if (lopAdd = '1') then
            rd <= addsubOut;
        elsif (lopShift = '1') then
            rd <= barrelOut;
        elsif ((lopAND OR lopOR OR lopXOR) = '1') then
            rd <= bitwiseOut;
        elsif (lopMUL = '1') then
            -- Need a multi-cycle Dadda multiplier
        elsif (lopDIV = '1') then
            -- Paravartya or Quick-Div
            rd <= (others => '0');
        end if;
    end process alu_p;
end alu;