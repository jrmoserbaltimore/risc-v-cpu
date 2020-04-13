-- vim: sw=4 ts=4 et
--
-- Arithmetic logic unit
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

entity e_alu is
    generic
    (
        XLEN : natural;
        FmaxFactor : positive := 1
    );
    port
    (
        clk  : in  std_ulogic;
        -- Reset when giving new data, for multi-cycle
        -- instructions
        rst  : in  std_ulogic;
        -- term 1 and term 2
        -- immediates are passed in sign-extended if necessary
        rs1  : in  std_ulogic_vector(XLEN-1 downto 0);
        rs2  : in  std_ulogic_vector(XLEN-1 downto 0);
        -- data out
        -- Function selector
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
        func : in  std_ulogic_vector(9 downto 0);
        rd   : out std_ulogic_vector(XLEN-1 downto 0);
        Complete : out std_ulogic
    );
end e_alu;

library IEEE;
use IEEE.std_logic_1164.all;

entity e_alu_multiplier is
    generic
    (
        XLEN : natural;
        FmaxFactor : positive := 1
    );
    port
    (
        clk   : in  std_ulogic;
        -- reset to begin operation
        rst       : in  std_ulogic;
        rs1       : in  std_ulogic_vector(XLEN-1 downto 0);
        rs2       : in  std_ulogic_vector(XLEN-1 downto 0);
        -- Calls to other ALU units
        call      : out std_ulogic;
        -- function to call
        cfunc     : out std_ulogic_vector(7 downto 0);
        -- Data to send. cdata = rs1, rd = rs2
        cdata     : out std_ulogic_vector(XLEN-1 downto 0);
        -- Called function is complete.  Data is returned
        -- on rs1.
        cret      : in  std_ulogic;
        rd        : out std_ulogic_vector(XLEN-1 downto 0);
        Complete  : out std_ulogic
    );
end e_alu_multiplier;

library IEEE;
use IEEE.std_logic_1164.all;

entity e_alu_divider is
    generic
    (
        XLEN : natural;
        FmaxFactor : positive := 1
    );
    port
    (
        clk   : in  std_ulogic;
        -- reset to begin operation
        rst       : in  std_ulogic;
        rs1       : in  std_ulogic_vector(XLEN-1 downto 0);
        rs2       : in  std_ulogic_vector(XLEN-1 downto 0);
        -- Calls to other ALU units
        call      : out std_ulogic;
        -- function to call
        cfunc     : out std_ulogic_vector(8 downto 0);
        -- Data to send. cdata = rs1, rd = rs2
        cdata     : out std_ulogic_vector(XLEN-1 downto 0);
        -- Called function is complete
        cret      : in  std_ulogic;
        -- Returns both the quotient and the remainder
        rd        : out std_ulogic_vector(XLEN-1 downto 0);
        rrm       : out std_ulogic_vector(XLEN-1 downto 0);
        Complete  : out std_ulogic
    );
end e_alu_divider;