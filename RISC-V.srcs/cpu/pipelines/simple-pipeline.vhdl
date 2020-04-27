-- pipeline
--
-- This assembles the pipeline from its stages.
library IEEE;
use IEEE.std_logic_1164.all;
use work.e_pipeline_fetch;

entity e_pipeline is
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
        -- Data
        rs1  : in  std_ulogic_vector(XLEN-1 downto 0);
        rs2  : in  std_ulogic_vector(XLEN-1 downto 0);
        insn : in  std_ulogic_vector(31 downto 0);
        -- Context
        misa : in  std_ulogic_vector(31 downto 0);
        mstatus : in  std_ulogic_vector(XLEN-1 downto 0);
        ring : in  std_ulogic_vector(1 downto 0)
    );
end e_pipeline;

architecture pipeline of e_pipeline is
    signal Flush   : std_ulogic := '0';
    signal Reset   : std_ulogic := '0'; 
    
    constant pipelineStages : natural := 10;
    -- Should be pipeline stages
    signal Strobes     : std_ulogic_vector(pipelineStages-1 downto 0);
    signal BusySignals : std_ulogic_vector(pipelineStages-1 downto 0);
begin

    fetch:  entity e_pipeline_fetch(riscv_fetch)
        generic map (
                     XLEN      => XLEN,
                     DBusWidth => 64,
                     AddrWidth => XLEN
                    )
        port map
        (
            clk => clk;
            -- FIXME:  mechanism to pass PC in a branch,
            -- but needs to iterate PC by 4 itself each fetch
            
            --
        );
    
    pipeline: process(clk) is
    begin
        if (rising_edge(clk)) then
            -- Pipeline flush on reset
            Reset <= Flush OR Rst;
        end if;
    end process;
end pipeline;