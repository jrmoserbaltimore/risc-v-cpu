-- vim: sw=4 ts=4 et
library IEEE;
use IEEE.std_logic_1164.all;

-- rs1, rs2, and imm:  S-type (Store), B-type (branch)
entity e_riscv_insn_3in is
    generic ( XLEN      : natural;
              Cycles    : natural := 1
    );
    port (
        clk  : in  std_ulogic;
        -- Reset when giving new data, for multi-cycle
        -- instructions
        rst  : in  std_ulogic;
        -- rs1 and rs2, 
        rs1  : in  std_ulogic_vector(XLEN-1 downto 0);
        rs2  : in  std_ulogic_vector(XLEN-1 downto 0);
        -- Immediate value gets sign-extended if necessary
        imm  : in  std_ulogic_vector(XLEN-1 downto 0);
        insn : in  std_ulogic_vector(31 downto 0);
        rd   : out std_ulogic_vector(XLEN-1 downto 0);
        Complete : out std_ulogic
    );
end e_riscv_insn_3in;

library IEEE;
use IEEE.std_logic_1164.all;
-- rs1 and rs2:  R-type (register)
-- rs1 and imm:  I-type (imm passed as rs2)
entity e_riscv_insn_2in is
    generic ( XLEN      : natural;
              Cycles    : natural := 1
    );
    port (
        clk  : in  std_ulogic;
        -- Reset when giving new data, for multi-cycle
        -- instructions
        rst  : in  std_ulogic;
        -- rs1 and rs2
        rs1  : in  std_ulogic_vector(XLEN-1 downto 0);
        rs2  : in  std_ulogic_vector(XLEN-1 downto 0);
        insn : in  std_ulogic_vector(31 downto 0);
        rd   : out std_ulogic_vector(XLEN-1 downto 0);
        Complete : out std_ulogic
    );
end e_riscv_insn_2in;

-- I-type (immediate)
library IEEE;
use IEEE.std_logic_1164.all;

-- U-type (upper-immediate), J-type (Jump)
entity e_riscv_insn_1in is
    generic ( XLEN      : natural;
              Cycles    : natural := 1
    );
    port (
        clk  : in  std_ulogic;
        -- Reset when giving new data, for multi-cycle
        -- instructions
        rst  : in  std_ulogic;
        -- Immediate value
        imm  : in  std_ulogic_vector(XLEN-1 downto 0);
        insn : in  std_ulogic_vector(31 downto 0);
        rd   : out std_ulogic_vector(XLEN-1 downto 0);
        Complete : out std_ulogic
    );
end e_riscv_insn_1in;
