-- vim: sw=4 ts=4 et
-- Decoder to do sign extension and such

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.e_riscv_insn_2in;
use work.e_binary_adder;

entity e_riscv_decoder is
    generic ( XLEN      : natural;
              Cycles    : natural := 1
    );
    port (
        clk  : in  std_ulogic;
        rst  : in  std_ulogic;
        rs1  : in  std_ulogic_vector(XLEN-1 downto 0);
        rs2  : in  std_ulogic_vector(XLEN-1 downto 0);
        insn : in  std_ulogic_vector(31 downto 0);
        Dout : out std_ulogic_vector(XLEN-1 downto 0);
        Complete : out std_ulogic;
        -- Machine information
        misa : in  std_ulogic_vector(31 downto 0);
        mstatus : in  std_ulogic_vector(XLEN-1 downto 0);
        ring : in  std_ulogic_vector(1 downto 0)
    );
end e_riscv_decoder;

-- Sign-extension decoder
-- TODO:  decode instruction type in a separate architecture?
architecture riscv_decoder_signex of e_riscv_decoder is 
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
    
    signal term1 : std_ulogic_vector(rs1'RANGE);
    signal term2 : std_ulogic_vector(rs2'RANGE);
begin

    -- FIXME:  move all the sign-extension and privilege mode
    -- stuff into the decoder phase.  
    add : process(clk) is
        variable size    : natural;
        variable SignEx1 : std_ulogic;
        variable SignEx2 : std_ulogic;
        variable SignExi : std_ulogic;
    begin
        if (rising_edge(clk)) then
            -- Get current privilege mode XLEN
            if (ring = "00") then -- User
                size := 2**(to_integer(unsigned(uxl))+4);
            elsif (ring = "01") then -- Supervisor
                size := 2**(to_integer(unsigned(sxl))+4);
            elsif (ring = "11") then -- Machine
                size := 2**(to_integer(unsigned(mxl))+4);
            end if;

            SignEx1 := rs1(size-1);
            term1(size-2 downto 0)      <= rs1(size-2 downto 0);
            term1(XLEN-1 downto size-1) <= (others => SignEx1);
            if ( rtype = '1' ) then
                -- R-type opcode
                SignEx2 := rs2(size-1);
                term2(size-2 downto 0)      <= rs2(size-2 downto 0);
                term2(XLEN-1 downto size-1) <= (others => SignEx2);
            elsif ( rtype = '0' ) then
                -- I-type opcode
                SignExi := imm(11);
                term2(rs2'HIGH downto 12) <= (others => SignExi);
                term2(11 downto 0) <= imm;
            end if;
        end if;
    end process add;
end riscv_decoder_signex;