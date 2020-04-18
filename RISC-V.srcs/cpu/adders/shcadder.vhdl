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
    type pg is array ( integer range <> ) of std_ulogic_vector(XLEN downto 0);
    signal p_tree : pg;
    signal g_tree : pg;
    
    signal err : std_ulogic;

    signal SpeculateP : std_ulogic_vector(XLEN-1 downto 0);
    signal SpeculateG : std_ulogic_vector(XLEN-1 downto 0);
    signal SpeculateGin : std_ulogic_vector(XLEN-1 downto 0);
    signal Bs : std_ulogic_vector(XLEN-1 downto 0);

    -- Calculate both in parallel in case error stage kicks in.
    -- The lower HALF is always correct in the speculative stage,
    -- so we only correct the upper half.
    signal SSpeculative : std_ulogic_vector(XLEN-1 downto 0); 
    signal SAccurate : std_ulogic_vector(XLEN-1 downto (XLEN/2));
    
    constant LastStage : natural := integer(ceil(log2(real(XLEN))));
     
begin

    -- Sets the top of the tree
    adder_bits: for i in 0 downto XLEN-1 generate
    begin
        p_tree(i)(-1) <= A(i) XOR Bs(i);
           -- Carry in the Sub bit
        g_tree(i)(-1) <=  A(i) AND Bs(i) when i /= 0 else
                         (A(i) AND Bs(i)) OR (p_tree(i)(-1) AND Sub);
    end generate;

    -- All but the last stage
    adder_stages: for j in (LastStage-1) downto 0 generate    
    begin
        cells: for i in (XLEN-1) downto 0 generate
        begin
            -- Horrendous unreadable math please help
            black_cells: if (
                            -- These only go on even bits (1 3 5 7…starting from 0)
                             (i mod 2 = 1)
                             -- each successive stage reaches twice as far back
                              AND (integer(((i+1)/2)) > (j+1))
                              -- The MSB uses a grey cell
                              AND i < XLEN
                            ) generate
                cell: entity e_binary_adder_pg_black_cell(binary_adder_pg_black_cell)
                    port map(
                        P    => p_tree(i)(j-1),
                        G    => g_tree(i)(j-1),
                        Pin  => p_tree(i-2**j)(j-1),
                        Gin  => g_tree(i-2**j)(j-1),
                        Pout => p_tree(i)(j),
                        Gout => g_tree(i)(j)
                    );
                -- //Pout <= P and Pin and Gin
                -- p_tree(i)(j) <= p_tree(i)(j-1) AND p_tree(i-2**j)(j-1) AND g_tree(i-2**j)(j-1);
                -- //Gout <= (P and Gin) or G
                -- g_tree(i)(j) <= (p_tree(i)(j-1) AND g_tree(i-2**j)(j-1)) OR g_tree(i)(j-1);    
            end generate; -- black cells

            -- The last in each row is a gray cell.  j stops before the last row, so
            -- we don't get double grey cells.
            --
            -- Same as above, but all the furthest-LSB columns we skipped
            grey_cells: if (
                             (i mod 2 = 1)
                             AND ((integer(((i+1)/2)) = (j+1))
                                 OR (i = XLEN))
                           ) generate
                cell: entity e_binary_adder_pg_grey_cell(binary_adder_pg_grey_cell)
                    port map(
                        P    => p_tree(i)(j-1),
                        G    => g_tree(i)(j-1),
                        Gin  => g_tree(i-2**j)(j-1),
                        Gout => g_tree(i)(j)
                    );
            end generate; -- gray cells

            -- pass down
            no_cells: if ((i mod 2 = 0) OR (integer(((i+1)/2)) < (j+1))) generate
                p_tree(i)(j) <= p_tree(i)(j-1);
                g_tree(i)(j) <= g_tree(i)(j-1);
            end generate; -- no cells
        end generate; -- cells

    end generate; -- adder stages

    -- FIXME:  Implement speculation

    -- Speculative stage
    speculative_stage: for i in (XLEN-1) downto 0 generate
    begin
        gray_cells: if (i mod 2 = 0) generate
        begin
            -- Skip the second-to-last row
            cell: entity e_binary_adder_pg_grey_cell(binary_adder_pg_grey_cell)
                    port map(
                        P    => p_tree(i)(LastStage-2),
                        G    => g_tree(i)(LastStage-2),
                        Gin  => g_tree(i-2)(LastStage-2),
                        Gout => g_tree(i)(LastStage)
                    );
        end generate;
        -- XOR with next stage's propagated carry
        SSpeculative(i) <= g_tree(i)(LastStage) XOR p_tree(i+1)(-1);
    end generate;

    -- only the upper half can be wrong
    accurate_stage: for i in (XLEN-1) downto (XLEN/2) generate
    begin
        gray_cells: if (i mod 2 = 0) generate
        begin
            cell: entity e_binary_adder_pg_grey_cell(binary_adder_pg_grey_cell)
                    port map(
                        P    => p_tree(i)(LastStage-1),
                        G    => g_tree(i)(LastStage-1),
                        Gin  => g_tree(i-2)(LastStage-1),
                        Gout => g_tree(i)(LastStage)
                    );
        end generate;
        -- XOR with next stage's propagated carry
        SAccurate(i) <= g_tree(i)(LastStage) XOR p_tree(i+1)(-1);
    end generate;
    
    -- Invert B when subtracting
    Bs <= B XOR (others => Sub);
    -- Ensure the XOR for the MSB always just passes G
    p_tree(XLEN)(-1) <= '0';
    
    -- The half LSB always come out correct, so always pass to S
    S((XLEN/2)-1 downto 0) <= SSpeculative((XLEN/2)-1 downto 0);

    S(XLEN-1 downto XLEN/2) <= SSpeculative(XLEN-1 downto XLEN/2) when err = '0' else
                               SAccurate(XLEN-1 downto XLEN/2);
    
    -- Speculation:  Error check
    add: process(all) is
        variable errCalc : std_ulogic_vector((XLEN/4)-1 downto 0);
        variable delay   : natural := 0;
    begin
        -- Error calculation
        for i in (XLEN/4) to 1 loop
            errCalc(i) := g_tree((2*i)-1)(LastStage-2) AND p_tree((2*i)+(XLEN/2)-1)(LastStage-2);  
        end loop;
        -- If any of the above is wrong, we have error!
        err <= OR errCalc;

        if (rising_edge(clk)) then
            -- Reset the delay to completion
            if (Rst = '1') then
                delay := Cycles;
            end if;
            if (err = '1' and delay = 0) then
                -- When error, delay 1.25% of the normal cycle length
                --
                -- Most papers say delay one clock cycle; however, reddy et al
                -- show a delay of 13.540ns for speculative 64-bit calculations,
                -- and a delay of  16.032ns for the error detection and
                -- correction stage.  13.540*2 > 16.032 > 13.540, so
                -- the delay seems to be 118% of a clock cycle.
                -- 1.25 is a 6% margin of error.
                delay := integer(ceil(1.25 * Cycles));
                Complete <= '0';
            elsif (delay > 0) then
                delay := delay - 1;
                Complete <= '1' when delay = 0 else
                            '0';
            end if;
        end if;
    end process add;
    
end speculative_han_carlson_adder;