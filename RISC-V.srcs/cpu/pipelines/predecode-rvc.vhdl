-- Pre-decoder
--
-- Recognizes some set of other instructions and sends the decoder
-- equivalent RISC-V instructions.
--
-- This one recognizes RVC instructions.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity e_predecoder is
    generic
    (
        XLEN : natural;
        RVM  : boolean := true
    );
    port
    (
        -- Control port
        Clk      : in  std_ulogic;
        Rst      : in  std_ulogic;
        Stb      : in  std_ulogic;
        Busy     : out std_ulogic;
        -- Reset signal propagates after CPU reset.
        -- All recipients must dump their buffers.
        -- Output handshake
        StbOut   : out std_ulogic;
        BusyOut  : in std_ulogic;
        -- Instruction to decode
        insn : in  std_ulogic_vector(31 downto 0);
        -- Context
        misa : in  std_ulogic_vector(31 downto 0);
        mstatus : in  std_ulogic_vector(XLEN-1 downto 0);
        ring : in  std_ulogic_vector(1 downto 0);
        -- program counter
        pc : in std_ulogic_vector(XLEN-2 downto 0);
        ------------
        -- Output --
        ------------
        -- Just the same as the input, usually
        insnOut    : out std_ulogic_vector(31 downto 0);
        -- Context
        misaOut    : out std_ulogic_vector(31 downto 0);
        mstatusOut : out std_ulogic_vector(XLEN-1 downto 0);
        ringOut    : out std_ulogic_vector(1 downto 0);
        -- program counter
        pcOut      : out std_ulogic_vector(XLEN-2 downto 0)
    );
end e_predecoder;

architecture riscv_c_decoder of e_predecoder is
    signal insnWk    : std_ulogic_vector(insn'RANGE);
    signal misaWk    : std_ulogic_vector(misa'RANGE);
    signal mstatusWk : std_ulogic_vector(mstatus'RANGE);
    signal ringWk    : std_ulogic_vector(ring'RANGE);
    signal pcWk      : std_ulogic_vector(pc'RANGE);
    
    -- Instruction info mapping
    alias opcode : std_ulogic_vector(1 downto 0) is insnWk(1 downto 0);
    
begin

    c_decode:  process(clk) is
        -- These decode functions do not check for an all-zeroes illegal instruction.  The
        -- caller must check for 00, 01, or 10 and call the appropriate decoder; the decoder
        -- will reply with 32x'0' for illegal instruction.
        --
        -- This decodes ALL RVC instructions.  The decode stage will figure out what it wants
        -- to do with the instruction
        
        ----------------
        -- Quadrant 0 --
        ----------------
        function decodeQ0 (
                           decode: std_ulogic_vector(15 downto 0);
                           exlen: std_ulogic_vector(1 downto 0)
                          )
                          return std_ulogic_vector is
            alias opcode : std_ulogic_vector(1 downto 0) is decode(1 downto 0);
            -- CI, CSS, CIW, CL, CS, CB, CJ
            alias funct3 : std_ulogic_vector(2 downto 0) is decode(15 downto 13);
            -- CR
            alias funct4 : std_ulogic_vector(3 downto 0) is decode(15 downto 12);
            -- CA
            alias funct2 : std_ulogic_vector(1 downto 0) is decode(6 downto 5);
            alias funct6 : std_ulogic_vector(5 downto 0) is decode(15 downto 10);

            -- CIW, CL
            alias rd : std_ulogic_vector(2 downto 0) is decode(4 downto 2);
            -- CL, CS, CB
            alias rs1 : std_ulogic_vector(2 downto 0) is decode(9 downto 7);
            -- CS, CA
            alias rs2 : std_ulogic_vector (2 downto 0) is rd;
            
            -- CR, CI
            alias rs1W : std_ulogic_vector(4 downto 0) is decode(11 downto 7);
            -- CR, CSS
            alias rs2W : std_ulogic_vector(4 downto 0) is decode(6 downto 2);
            
            variable outInsn : std_ulogic_vector(31 downto 0) := (others => '0');
        begin
            assert decode'HIGH = 31 AND decode'LOW = 0
            report "Wrong input size (must be 31 downto 0)"
            severity failure;
            
            if (
                funct3 = "000"
                OR funct3 = "010"
                OR funct3 = "100"
                OR funct3 = "110"
               )
                then
                -- XLEN-insensitive
                case funct3 is
                when "000" =>
                    -- ADDI4SPN: addi rd, x2, nzuimm
                    if ((OR decode(12 downto 5)) = '0') then
                        -- Canonical illegal instruction when rd=0
                        return (others => '0');
                    else
                        outInsn := (
                                    31 downto 30 => '0',
                                    29 downto 26 => decode(10 downto 7),
                                    25 downto 24 => decode(12 downto 11),
                                    23 => decode(5),
                                    22 => decode(4),
                                    21 downto 20 => '0',
                                    19 downto 15 => "00010", -- x2
                                    14 downto 12 => "000", -- ADDI funct3
                                    11 downto 10 => "01",  -- x8
                                    9 downto 7 => decode(4 downto 2), -- plus rd
                                    6 downto 0 => "0010011"
                                   );
                    end if;
                when "010" =>
                    -- C.LW: lw rd, offset(rs1)
                    outInsn := (
                                31 downto 27 => '0',
                                26 => opcode(5),
                                25 downto 23 => decode(12 downto 10),
                                22 => decode(6),
                                21 downto 20 => '0',
                                19 downto 18 => "01", -- x8
                                17 downto 15 => decode(9 downto 7), -- plus rs1
                                14 downto 12 => "010", -- LW funct3
                                11 downto 10 => "01",  -- x8
                                9 downto 7 => decode(4 downto 2), -- plus rd
                                6 downto 0 => "0000011"
                               );
                when "100" =>
                    -- reserved, so illegal instruction.
                    return (others => '0');
                when "110" =>
                    -- C.SW:
                end case;
            else
                -- XLEN-sensitive
                case funct3 is
                    when "001" =>
                        if (exlen /= "11") then
                            -- C.FLD (RV32/64): flw rd, offset(rs1)
                        else
                            -- C.LQ (RV128): lq rd, offset(rs1)
                        end if;
                    when "011" =>
                        if (exlen = "01") then
                            -- C.FLW (RV32): flw flw rd, offset(rs1)
                        else
                            -- C.LD (RV64/128): ld rd, offset(rs1)
                            outInsn := (
                                        31 downto 26 => '0',
                                        27 downto 26 => opcode(6 downto 5),
                                        25 downto 23 => decode(12 downto 10),
                                        22 downto 20 => '0',
                                        19 downto 18 => "01", -- x8
                                        17 downto 15 => decode(9 downto 7), -- plus rs1
                                        14 downto 12 => "011", -- LD funct3
                                        11 downto 10 => "01",  -- x8
                                        9 downto 7 => decode(4 downto 2), -- plus rd
                                        6 downto 0 => "0000011"
                                       );
                        end if;
                    when "101" =>
                        if (exlen /= "11") then
                            -- RV32/64
                        else
                            -- RV128
                        end if;
                    when "111" =>
                        if (exlen = "01") then
                            -- RV32
                        else
                            -- RV64/128
                        end if;
                end case;
            end if;
            return outInsn;
        end function;

        ----------------
        -- Quadrant 1 --
        ----------------
    begin
        if (rising_edge(clk)) then
            if (opcode = "11") then
                -- Not an RVC instruction
                insnOut    <= insnWk;
            else
                -- Need to:
                --  - bank the second instruction
                --  - accept the next 32-bit chunk
                --  - determine if the second instruction is RVC
                --    - If so, stall, deploy decoded RVC, and pick
                --      back up on 32-bit alignment
                --    - if not, deploy 32-bit instruction and get
                --      the next 32 bits fetched
                --
                -- If we end up with unaligned 32-bit instructions,
                -- we'll need the current and following instruction
                -- to decode:
                --
                --   32-bit| 32-bit | 32-bit | 32-bit | 32-bit
                -- [C ][C ] [C ][I  |   ][I  |   ][C ]|[I      ]
                --
                -- Instructions 4 and 5 are split across 32-bit
                -- boundaries.
            end if;
            -- These always get sent as-is.
            misaOut    <= misaWk;
            mstatusOut <= mstatusWk;
            ringOut    <= ringWk;
            pcOut      <= pcWk;
        end if;
    end process c_decode;
end riscv_c_decoder;