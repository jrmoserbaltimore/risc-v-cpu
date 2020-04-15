-- pipeline
--
-- A pipeline component carries out a particular stage in a pipeline.
-- The component provides stage-to-stage synchronization using a skid
-- buffer busy-handshake style pipeline.
--
-- Special thanks to ZipCPU for documenting and explaining how a
-- buffered handshake pipeline works.
--
-- https://zipcpu.com/blog/2017/08/14/strategies-for-pipelining.html
library IEEE;
use IEEE.std_logic_1164.all;

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