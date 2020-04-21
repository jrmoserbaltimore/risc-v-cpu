-- vim: sw=4 ts=4 et
-- Han-Carlson adder

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.math_real."ceil";
use ieee.math_real."log2";

use work.e_binary_adder;
use work.e_binary_adder_pg_black_cell;
use work.e_binary_adder_pg_grey_cell;

-- Subtraction is A - B
architecture han_carlson_adder of e_binary_adder is
    type pg is array ( integer range <> ) of std_ulogic_vector(XLEN downto 0);
    signal p_tree : pg;
    signal g_tree : pg;
    
    signal Bs : std_ulogic_vector(XLEN-1 downto 0);

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
            black_cells: if ((i mod 2 = 1) AND (integer(((i+1)/2)) > (j+1)) AND i < XLEN) generate
                cell: entity e_binary_adder_pg_black_cell(binary_adder_pg_black_cell)
                    port map(
                        P    => p_tree(i)(j-1),
                        G    => g_tree(i)(j-1),
                        Pin  => p_tree(i-2**j)(j-1),
                        Gin  => g_tree(i-2**j)(j-1),
                        Pout => p_tree(i)(j),
                        Gout => g_tree(i)(j)
                    );
            end generate; -- black cells

           
            -- The last in each row is a gray cell.  j stops before the last row, so
            -- we don't get double grey cells.
            grey_cells: if ((i mod 2 = 1) AND ((integer(((i+1)/2)) = (j+1)) OR (i = XLEN)) ) generate
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

    -- Final stage
    accurate_stage: for i in (XLEN-1) downto 0 generate
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
        S(i) <= g_tree(i)(LastStage) XOR p_tree(i+1)(-1);
    end generate;
    
    -- Invert B when subtracting
    Bs <= B XOR (others => Sub);
    -- Ensure the XOR for the MSB always just passes G
    p_tree(XLEN)(-1) <= '0';

    add: process(all) is
        variable delay   : natural := 0;
    begin
        if (rising_edge(clk)) then
            -- Reset the delay to completion
            if (Rst = '1') then
                delay := Cycles;
            end if;
            if (delay > 0) then
                delay := delay - 1;
                Complete <= '1' when delay = 0 else
                            '0';
            end if;
        end if;
    end process add;
end han_carlson_adder;