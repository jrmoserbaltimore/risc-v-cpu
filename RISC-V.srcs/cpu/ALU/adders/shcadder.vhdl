-- vim: sw=4 ts=4 et
-- Speculative Han-Carlson adder
--
-- As per International Journal of Innovations in Engineering and Technology,
-- "Design of Efficient Han-Carlson-Adder
-- Katyayani, Reddy, et al.
--
-- This adder skips the last layer most of the time; if it detects error, it
-- performs further computation, making it a two-clock adder. 
-- A one-bit full adder looks as below:
--
--   S    <= A XOR B XOR Cin
--   Cout <= (A AND B) OR (B AND Cin) OR (Cin AND A)
--
-- A different adder uses three circuits.
--
-- Adder:
--
--   A     : (in)
--   B     : (in)
--   G     : (out)
--   P     : (out)
--   G     <= A AND B
--   P     <= A XOR B
--
-- Propagate:
--
--   Gin   : (in)
--   Pin   : (in)
--   Cin   : (in)
--   PCin  : (in)
--   Gout  <= (Pin AND Cin) XOR Gin
--   Pout  <= Pin AND PCin
--
-- Sum bit:
--
--   Pin   : (in)
--   Cin   : (in)
--   S     : (out)
--   S     <= Pin XOR Cin
--
-- P from the Adder goes to the Sum bit.  Gout from the Adder goes to
-- Cin on the NEXT Propagator.  The final propagated Gout goes to Cin on
-- the NEXT Sum bit.
--
-- These propagate forward a bunch, creating a complex mess.  Han-Carlson
-- simply shortcuts some of this:
--
-- For every even bit, Gout and Pout from the final Propagate cycle begin
-- forwarding to PCin in the next stage at each power of two.  That is:
-- Bit 0 sends its (G,P) from Input to Stage 1 of bit 1, which sends its
-- (G,P) from Stage 1 to Stage 2 of Bit 3, which sends its (G,P) from 
-- Stage 2 to Stage 3 of Bit 7, and so forth.  In the final stage, the
-- odd bits propagate their (P,G) to the outputs.
--
-- Each bit has to propagate to each other bit.  At Stage 1, Bit 1
-- propagates to Stage 2 of Bit 3; at Stage 2, Bit 1 propagates to Stage
-- 3 of Bit 5.  This is because Stage 3 of Bit 3 propagates to Stage 4 of
-- Bit 7, and so Bit 5 carries no information about Bit 1!  Notably, Bit 2
-- propagates to 3, then 5, but this propagation does not bring any
-- information about Bit 1.  The final stage propagates Bit 1 to Bit 2,
-- which is the first time Bit 2 receives information about Bit 1.
--
-- Speculative Han-Carlson skips the propagation stage before the last.
-- For a 16-bit adder, Bit 7 Stage 3 never propagates to Bit 15 Stage 4;
-- rather it directly propagates to Bit 8 output.
--
-- Just before the output stage, speculative Han-Carlson tests all the
-- odd-numbered bits:
--
--   D     : (in) [15 downto 0]
--   Error : (out)
--   Error <= ((D[1] AND D[9]) XOR (D[3] AND D[11])) XOR
--            ((D[5] AND D[13]) XOR (D[7] AND [D15]))
--
-- When an error is detected, the last stage is computed.  Errors are
-- fairly infrequent, so the fast path usually occurs.  The adder also
-- reduces the amount of space needed.
--
-- Each component can also use a two-way state signal rather than the
-- adder running on a clock.  This essentially propagates a "done"
-- signal.  Such an adder can begin computing new addition before prior
-- signals have fully propagated and effectively pipeline additions.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";

use work.e_binary_adder;
use work.e_binary_adder_pg_black_cell;
use work.e_binary_adder_pg_grey_cell;

-- Subtraction is A - B
architecture speculative_han_carlson_adder of e_binary_adder is
    constant LastStage : natural := integer(ceil(log2(real(XLEN))));
    type pg is array (LastStage downto -1) of std_ulogic_vector(XLEN-1 downto 0);
    signal p_tree : pg := (others => (others => '0'));
    signal g_tree : pg := (others => (others => '0'));
    
    signal err : std_ulogic := '0';
    signal errDelay : std_ulogic := '0';
    signal DoCalc : std_ulogic := '0';

    signal SpeculateG : std_ulogic_vector(XLEN-1 downto 0) := (others => '0');
    signal Bs : std_ulogic_vector(XLEN-1 downto 0) := (others => '0');

    -- Calculate both in parallel in case error stage kicks in.
    -- The lower HALF is always correct in the speculative stage,
    -- so we only correct the upper half.
    signal SSpeculative : std_ulogic_vector(XLEN-1 downto 0) := (others => '0'); 
    signal SAccurate : std_ulogic_vector(XLEN-1 downto XLEN/2) := (others => '0');
    
    -- Busy signal
    signal iBusy : std_ulogic := '0';
    signal oStb  : std_ulogic := '0';
    alias oBusy is BusyOut;
    -- Register
    signal AReg : std_ulogic_vector(XLEN-1 downto 0) := (others => '0');
    signal BReg : std_ulogic_vector(XLEN-1 downto 0) := (others => '0');
    signal SubReg : std_ulogic := '0';
    signal SpecReg : std_ulogic := '0';
    signal R    : std_ulogic := '0';
    
    -- Working set
    signal AWk : std_ulogic_vector(XLEN-1 downto 0);
    signal BWk : std_ulogic_vector(XLEN-1 downto 0);
    signal SubWk : std_ulogic;
    signal specWk : std_ulogic;
begin

    ----------------
    -- Adder Tree --
    ----------------
    -- Sets the top of the tree
    adder_bits: for i in XLEN-1 downto 1 generate
    begin
        p_tree(-1)(i) <= AWk(i) XOR Bs(i);
           -- Carry in the Sub bit
        g_tree(-1)(i) <= AWk(i) AND Bs(i);
    end generate;
    
    -- Carry the Sub bit in by propagating 
    p_tree(-1)(0) <= (AWk(0) XOR Bs(0)) XOR SubWk;
    g_tree(-1)(0) <= (AWk(0) AND Bs(0)) OR ((AWk(0) XOR Bs(0)) AND SubWk); 

    -- All stages
    adder_stages: for j in LastStage downto 0 generate
    begin
        -- The G tree for the MSB generates the carry bit, but we don't care in RISC-V
        cells: for i in (XLEN-1) downto 0 generate 
        begin
            -- Horrendous unreadable math please help
            black_cells: if (
                            -- These only go on even bits (1 3 5 7…starting from 0)
                             (i mod 2 = 1)
                             -- each successive stage reaches twice as far back
                              AND (integer(((i+1)/2)) > (2**j))
                            ) generate
                cell: entity e_binary_adder_pg_black_cell(binary_adder_pg_black_cell)
                    port map(
                        P    => p_tree(j-1)(i),
                        G    => g_tree(j-1)(i),
                        Pin  => p_tree(j-1)(i-2**j),
                        Gin  => g_tree(j-1)(i-2**j),
                        Pout => p_tree(j)(i),
                        Gout => g_tree(j)(i)
                    );
                -- //Pout <= P and Pin and Gin
                --p_tree(j)(i) <= p_tree(j-1)(i) AND g_tree(j-1)(i-2**j) AND p_tree(j-1)(i-2**j);
                -- //Gout <= (P and Gin) or G
                --g_tree(j)(i) <= (p_tree(j-1)(i) AND g_tree(j-1)(i-2**j)) OR g_tree(j-1)(i);    
            end generate; -- black cells

            -- The last in each row is a gray cell.  j stops before the last row, so
            -- we don't get double grey cells.
            --
            -- Same as above, but all the furthest-LSB columns we skipped
            grey_cells: if (
                             (i mod 2 = 1)
                             AND ((integer(((i+1)/2)) <= (2**j)))
                             AND (i >= 2**j)
                           ) generate
                cell: entity e_binary_adder_pg_grey_cell(binary_adder_pg_grey_cell)
                    port map(
                        P    => p_tree(j-1)(i),
                        G    => g_tree(j-1)(i),
                        Gin  => g_tree(j-1)(i-2**j),
                        Gout => g_tree(j)(i)
                    );
                    -- Pass down the propagate carry
                    p_tree(j)(i) <= p_tree(j-1)(i);
            end generate; -- gray cells
            
            grey_cells_end: if (
                             (i mod 2 = 0)
                             AND (j = LastStage)
                             AND (i > 0)
                           ) generate
                cell: entity e_binary_adder_pg_grey_cell(binary_adder_pg_grey_cell)
                    port map(
                        P    => p_tree(j-1)(i),
                        G    => g_tree(j-1)(i),
                        Gin  => g_tree(j-1)(i-1),
                        Gout => g_tree(j)(i)
                    );
                    -- Pass down the propagate carry
                    p_tree(j)(i) <= p_tree(j-1)(i);
            end generate; -- gray cells

            -- pass down
            no_cells: if (
                          ( ((i < 2**j) OR (i mod 2 = 0)) AND (j < LastStage))
                          OR ( ((i mod 2 = 1) OR (i = 0)) AND (j = LastStage))
                      ) generate
                p_tree(j)(i) <= p_tree(j-1)(i);
                g_tree(j)(i) <= g_tree(j-1)(i);
            end generate; -- no cells
        end generate; -- cells
    end generate; -- adder stages
    
    -- e.g. for [63:32]
    acc_sum: for i in XLEN-1 downto XLEN/2 generate
        -- XOR prior bit's generated with current bit's original propagated carry
        SAccurate(i) <= g_tree(LastStage)(i-1) XOR p_tree(-1)(i);
    end generate;

    ------------------------
    -- Speculative Result --
    ------------------------

    -- Speculative stage is the whole thing
    speculative_stage: for i in (XLEN-1) downto 0 generate
        
    begin
        gray_cells: if ((i mod 2 = 0) AND i > 0) generate
        begin
            -- Skip the second-to-last row
            cell: entity e_binary_adder_pg_grey_cell(binary_adder_pg_grey_cell)
                    port map(
                        P    => p_tree(LastStage-2)(i),
                        G    => g_tree(LastStage-2)(i),
                        Gin  => g_tree(LastStage-2)(i-1),
                        Gout => SpeculateG(i)
                    );
                    -- Pass down the propagate carry
        end generate;
        -- Bring the other bits down
        pass: if ((i mod 2 = 1) OR i = 0) generate
            SpeculateG(i) <= g_tree(LastStage-2)(i);
        end generate;
        -- XOR prior bit's generated with current bit's propagated carry
        gen_speculative_sum: if (i > 0) generate
            SSpeculative(i) <= SpeculateG(i-1) XOR p_tree(-1)(i);
        end generate;

    end generate;
    -- Bit zero is just the propagated carry from A0+B0
    SSpeculative(0) <= p_tree(-1)(0);

    ---------------------
    -- Error Detection --
    ---------------------
    error_test : for i in (XLEN/4) downto 1 generate
        signal errCalc : std_ulogic_vector(XLEN/4-1 downto 0);
    begin
        errCalc(i-1) <= g_tree(LastStage-2)((2*i)-1) AND p_tree(LastStage-2)((2*i)+(XLEN/2)-1);
        error_calc: if (i = 1) generate
            err <= OR errCalc;
        end generate;        
    end generate;
    
    ------------
    -- Setup ---
    ------------
    
    Busy <= iBusy;
    StbOut <= oStb;
    -- Invert B when subtracting
    Bs <= BWk XOR SubWk;

     -- The half LSB always come out correct, so always pass to S
    S((XLEN/2)-1 downto 0) <= SSpeculative((XLEN/2)-1 downto 0);
    
    pipeline: process(clk) is
        variable errCalc : std_ulogic_vector((XLEN/4)-1 downto 0);
    begin
        if (rising_edge(clk)) then
            -- Whenever we are not waiting for an error correction,
            -- check if we're performing addition 
            if (DoCalc = '1' AND errDelay = '0') then
                if (err = '1' OR Speculate = '0') then
                    -- Delay to get accurate output
                    -- if speculation is disabled, we still need the extra
                    -- delay (unless running at slower clock rates)
                    S(XLEN-1 downto XLEN/2) <= SAccurate;
                    errDelay <= '1';
                    iBusy <= '1'; -- We're busy so we need to wait.
                else
                    -- Strobe immediately if speculating and no error
                    S(XLEN-1 downto XLEN/2) <= SSpeculative(XLEN-1 downto XLEN/2);
                    oStb <= '1';
                end if;
            end if;
            -- If we had a one-cycle delay, set all this for the next cycle
            -- and strobe it out. 
            if (errDelay = '1' AND Rst = '0') then
                -- We're on the second cycle, take the accurate output
                --S(XLEN-1 downto XLEN/2) <= SAccurate;
                -- Delay is 1, so set it to 0 and strobe.
                -- Not done in the oBusy stage because we need to strobe
                -- immediately when ready.
                errDelay <= '0';
                oStb <= '1';
            end if;
            -- Regardless of all that, handle the handshake.
            if (Rst = '1') then
                -- Reset signal, clear everything
                R <= '0';
                iBusy <= '0';
                oStb <= '0';
                errDelay <= '0';
                AWk <= A;
                BWk <= B;
                SubWk <= Sub;
                SpecWk <= Speculate; 
            elsif (oBusy = '0') then
                -- Next stage is not busy
                if (errDelay = '1' OR (DoCalc = '0' OR err = '0')) then
                    -- We need to not be delaying AND not have discovered an error THIS cycle
                    -- while performing a calculation.
                    -- If errDelay is 1, we're ON the cyle that sends output, so we can do the
                    -- computation next cycle (when the receiver receives it) 
                    if (R = '0') then
                        -- Copy from input
                        AWk <= A;
                        BWk <= B;
                        SubWk <= Sub;
                        SpecWk <= Speculate;
                        -- Do calculation if we're getting strobe
                        -- DoCalc <= Stb; 
                    else
                        -- Pull from buffer
                        AWk <= AReg;
                        BWk <= BReg;
                        SubWk <= SubReg;
                        SpecWk <= SpecReg;
                        -- Need to do work on next cycle
                        -- DoCalc <= '1';
                    end if;
                    -- ...if something was registered or we got Stb
                    DoCalc <= R OR Stb;
                    -- Clear stall (output isn't busy, register is free) and register.
                    -- Again: stall doesn't clear if we're correcting an error.
                    --
                    -- Note that if we hit an error on the next operation, we will
                    -- BECOME busy in the next cycle, and will have to refill the
                    -- buffer on strobe
                    iBusy <= '0';
                    R <= '0';
                end if;
            elsif (oStb = '0') then
                -- We're not resetting and the next stage IS busy,
                -- AND we're not sending output, so clear busy
                if (errDelay = '1' OR (DoCalc = '0' OR err = '0')) then
                    -- We're not waiting to fix an error, so we're not busy
                    iBusy <= '0';
                    -- Keep the buffer empty
                    -- XXX: https://zipcpu.com/blog/2017/08/14/strategies-for-pipelining.html
                    --      Is this really valid?  Register should already be empty if we do
                    --      this; or else we need to check if it's not empty before we take
                    --      data.
                    R <= '0';
                end if;
            elsif (Stb = '1' AND iBusy = '0') then
                -- We're not resetting and the next stage IS busy, AND
                -- we've got output awaiting for sending, AND
                -- data is coming in and we've claimed to be ready for data.

                -- Bank into register
                AReg <= A;
                Breg <= B;
                SubReg <= Sub;
                SpecReg <= Speculate;
                R <= '1';
                -- Stall the pipeline
                iBusy <= '1';
            end if;
        end if;
    end process pipeline;
    
end speculative_han_carlson_adder;