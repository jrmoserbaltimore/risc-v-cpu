-- vim: ts=4 sw=4 et
-- Skid-buffer handshake
--
-- Much thanks to ZipCPU:
-- https://zipcpu.com/blog/2017/08/14/strategies-for-pipelining.html
library IEEE;
use IEEE.std_logic_1164.all;

entity e_skid_handshake is
    generic
    (
        DataSize : Natural := 64;
        Buffers  : Natural := 1
    );
    port
    (
        -- Control port
        Clk      : in  std_ulogic;
        Rst      : in  std_ulogic;
        -- Connect to incoming handshake
        Stb      : in  std_ulogic;
        Busy     : out std_ulogic;
        -- Data service for integrating component
        -- Din connects to the data input directly
        -- DReg is the available data, whether from a buffer or from immediate input
        -- Reg tells the component data is ready to process
        -- oReady is set on the cycle data is ready, and must trigger oStb
        -- oData is the data to send
        Din      : in  std_ulogic_vector(DataSize-1 downto 0);
        DReg     : out std_ulogic_vector(DataSize-1 downto 0);
        Reg      : out std_ulogic;
        oReady   : in  std_ulogic;
        oData    : in  std_ulogic_vector(DataSize-1 downto 0);
        -- Handshake out
        -- outReg is the data output.  Skid buffer will buffer this so the
        -- integrating component doesn't need to track oBusy
        outReg   : out  std_ulogic_vector(DataSize-1 downto 0);
        oStb     : out std_ulogic;
        oBusy    : in std_ulogic
    );
end e_skid_handshake;

architecture skid_handshake of e_skid_handshake is
    signal DataBuffer : std_ulogic_vector(DataSize-1 downto 0);
    signal R : std_ulogic := '0';
    signal iBusy : std_ulogic := '0';
begin

    Busy <= iBusy;
    
    --Fixme:  'Reg' should be set only when we're ready to take data for pipelining
    --        out AND in such condition it should ALWAYS be set.  oReady signals
    --        that data has been processed and the new data has been captured on
    --        that cycle.
    --
    --        When idle, Stb should be directly attached to Reg, and Din directly
    --        to DReg.  The logic circuit should begin processing on the clock this
    --        handshake circuit receives data.    
    process(clk) is
    begin
        if (rising_edge(clk)) then
            if (Rst = '1') then
                -- Reset signal, clear everything
                R <= '0';
                iBusy <= '0';
                oStb <= '0';
            elsif (oBusy = '0') then
                -- Next stage is not busy
                if (R = '0') then
                    -- Copy from input
                    DReg <= Din;
                else
                    -- Pull from buffer
                    DReg <= DataBuffer;
                end if;
                -- ...if something was registered or we got Stb
                Reg <= R OR Stb;
                -- Clear stall (output isn't busy, register is free) and register.
                -- Again: stall doesn't clear if we're correcting an error.
                --
                -- Note that if we hit an error on the next operation, we will
                -- BECOME busy in the next cycle, and will have to refill the
                -- buffer on strobe
                iBusy <= '0';
                R <= '0';
            elsif (oStb = '0') then
                -- We're not resetting and the next stage IS busy,
                -- AND we're not sending output, so clear busy
                iBusy <= '0';
                -- Keep the buffer empty
                -- XXX: https://zipcpu.com/blog/2017/08/14/strategies-for-pipelining.html
                --      Is this really valid?  Register should already be empty if we do
                --      this; or else we need to check if it's not empty before we take
                --      data.
                R <= '0';
            elsif (Stb = '1' AND iBusy = '0') then
                -- We're not resetting and the next stage IS busy, AND
                -- we've got output awaiting for sending, AND
                -- data is coming in and we've claimed to be ready for data.

                -- Bank into register
                DataBuffer <= Din;
                R <= '1';
                -- Stall the pipeline
                iBusy <= '1';
            end if;
        end if;
    end process;
end skid_handshake;