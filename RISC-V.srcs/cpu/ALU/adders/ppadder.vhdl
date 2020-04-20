-- vim: sw=4 ts=4 et
--parallel prefix mux

library IEEE;
use IEEE.std_logic_1164.all;
-- There are two forms of this.  All but the last for a given
-- bit are as follows:
--
--  G Gin P Pin
--  | |   | |
--  | AND-| |
--  | |   AND
--  OR     |
--   |     |
--  Gout  Pout
--
entity e_binary_adder_pg_black_cell is
port (
    P     : in  std_ulogic;
    G     : in  std_ulogic;
    Pin   : in  std_ulogic;
    Gin   : in  std_ulogic;
    Pout  : out std_ulogic;
    Gout  : out std_ulogic
    );
end e_binary_adder_pg_black_cell;

architecture binary_adder_pg_black_cell of e_binary_adder_pg_black_cell is
begin
    Pout <= P AND Gin AND Pin;
    Gout <= (P AND Gin) OR G;
end binary_adder_pg_black_cell;

-- The last stage is as follows:
--
--  G Gin P
--  | |   |
--  | AND-
--  | |
--  OR
--   |
--  Gout
library IEEE;
use IEEE.std_logic_1164.all;

entity e_binary_adder_pg_grey_cell is
port (
    P     : in  std_ulogic;
    G     : in  std_ulogic;
    Gin   : in  std_ulogic;
    Gout  : out std_ulogic
    );
end e_binary_adder_pg_grey_cell;

architecture binary_adder_pg_grey_cell of e_binary_adder_pg_grey_cell is
begin
    Gout <= (P AND Gin) OR G;
end binary_adder_pg_grey_cell;