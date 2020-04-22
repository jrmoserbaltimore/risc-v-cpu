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
use IEEE.numeric_std.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";
use work.e_alu;
use work.e_barrel_shifter;

--   A          B
--   |          |
--   |          *
--   |      _________
--   |     |         |
--   |     |    *    |
--   |     |  __|    |
--   |     | |  |    |
--   |     | |  |    |
--   |___  | |  |    |
--   |   | | |  |    |
--   |   | | |  |    |
--   |   DIVSH  |    |
--   |  _| |    |    |
--   | |   |  __|    |
--   | |   | |       |
--   MUX   MUX       |
--   |     |         |
--   DSP48E1         |
--      |____________|
--      |
--    OUTPUT
--     ***
--
-- Approach:
--   - Instantiate cascading DSP48E1 units
--   - Instantiate divider-shifter DIVSH.
--   - Fan out input data to a mux on the DSP and to DIVSH.
--   - Fan DSP output out to both output and DIVSH.
--   - DIVSH uses internal MUX to select inputs.
--   - DIVSH controls ALU circuit to leverage DSP48E1.
--   - DIVSH contains look-up table for bit shifting, uses the
--     DSP multiplier to perform bit shifts.
--
-- DSP operations face only a single input mux on the critical path,
-- and that mux idles favoring the input.  DSP handles addition,
-- subtraction, and bitwise AND, OR, and XOR.  All other circuits
-- pass output through the DSP set to OR with zero.
--
-- The Divider-Shifter contains a look-up table to select a power
-- of 2 for multiplication of the data to be shifted.  It also
-- contains reversal circuitry to turn the input backwards for a
-- right shift, and sign-extension for arithmetic shift right.
--
-- DIV is a multi-cycle instruction and uses the DSP48E1 to
-- compute bit-shifts, multiplications, additions, and comparisons
-- to implement complex division algorithms.
--
-- The INPUT and OUTPUT fan-out are both two.
--
-- The DSP provides the adder, bitwise operations, comparator, and
-- multiplier, and gets the shortest critical path.  Comparatively
-- rare divison gets a long, multi-cycle operation.  Bit shift is a
-- look-up table and a multiplication. 
architecture xilinx_dsp48e1_alu of e_alu is
    -- What operation
    -- ALU ops
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
    
    signal barrelOut : std_ulogic_vector(XLEN-1 downto 0);
    
    -- Force DSP48
    attribute use_dsp48 : string;
    attribute use_dsp48 of rs1 : signal is "yes";
    attribute use_dsp48 of rs2 : signal is "yes";
    attribute use_dsp48 of rd : signal is "yes";
begin
        --XLEN : natural;
        --FmaxFactor : positive := 1

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
        opFlags    => (opRSh, opAr),
        Dout       => barrelOut
    );
    -- FIXME:  take current XLEN into account and sign-extend?  Should 
    -- do that in a prior stage.
    --
    -- The barrel shifter routes around the DSP and into a muxer,
    -- so the input fans out to either the DSP or the shifter.
    -- Fabric logic would require additional fan-out and three
    -- more rows of muxers on the output, adding delay. 

    -- TODO:  

    -- Multiplier uses partial product and accumulator feedback,
    -- acting as a high-frequency multi-cycle instruction.

    compute: process(clk) is
    begin
        if (rising_edge(clk)) then
            if (lopAdd = '1') then
                -- Adder-Subtractor uses the DSP's adder.
                -- Arithmetic = SUB
                case opAr is
                    when '0' => rd <= std_logic_vector(signed(rs1) + signed(rs2));
                    when '1' => rd <= std_logic_vector(signed(rs1) - signed(rs2));
                end case;
            elsif (lopShift = '1') then
                -- No shift operation in DSP48
                rd <= barrelOut;
            elsif (lopCmp = '1') then
                -- Normal approach is to 
                case opUnS is
                    when '0' =>
                        if (unsigned(rs1) < unsigned(rs2)) then
                            rd <= (0 => '1', others => '0');
                        else
                            rd <= (0 => '0', others => '0');
                        end if;
                    when '1' =>
                        if (signed(rs1) < signed(rs2)) then
                            rd <= (0 => '1', others => '0');
                        else
                            rd <= (0 => '0', others => '0');
                        end if;
                end case;
            elsif (lopAND = '1') then
                -- fMax is unlikely to be bound by fabric bitwise operations,
                -- but the inputs will already be tied to the DSP and so only
                -- a change of DSP ALU operation is necessary.
                rd <= rs1 AND rs2;
            elsif (lopOR = '1') then
                rd <= rs1 OR rs2;
            elsif (lopXOR = '1') then
                rd <= rs1 OR rs2;
            elsif (lopMUL = '1') then
                -- FIXME:  How can I tell when this is finished?
                if (opH = '0') then
                    -- Uper half only
                    -- FIXME:  actually return the upper half
                    if (opUnS = '1') then
                        rd <= std_logic_vector(unsigned(rs1) * unsigned(rs2));
                    elsif (opHSU = '1') then
                        -- Invalid
                        --rd <= std_logic_vector(signed(rs1) * unsigned(rs2));
                    else
                        rd <= std_logic_vector(signed(rs1) * signed(rs2));
                    end if;
                else
                    rd <= std_logic_vector(unsigned(rs1) * unsigned(rs2));
                end if;
            elsif (lopDIV = '1') then
                -- FIXME:  paravartya or quick-div
                
                -- Divider obtains and caches the remainder and product to
                -- catch the RISC-V M specified sequence:
                --   DIV[U] rdq, rs1, rs2
                --   REM[U] rdq, rs1, rs2
                -- This sequence is fused together into a single divide.
                --
                -- Various divider components are possible, e.g. Paravartya.
                -- The ALU requires a divider implementation, as the DSP
                -- does not provide one.
                if (opRem = '1') then
                    -- Remainder
                else
                    -- Quotient
                end if;
            end if;
        end if;
    end process;
end xilinx_dsp48e1_alu;
