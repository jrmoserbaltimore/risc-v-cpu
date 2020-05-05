// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: RISC-V Pipeline Data
// Module Name: IPipelineData
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: An interface to carry pipeline data
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.1
// Revision 0.1 - Changed to IPipelineData interface
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire


interface IPipelineData
#(
    parameter XLEN = 32,
    FetchSize = 32
);
    logic [31:0] insn = '0;
    // Extra data from Fetch, if wide bus.  Append to insn.
    logic [FetchSize-32:0] FetchData = '0;
    
    // virtually extend misa on access: [XLEN-1:XLEN-2] is [31:30]
    logic[31:0] misa = '0;
    logic[XLEN-1:0] mstatus = '0;
    bit[1:0] ring = '0;

    let sxl = mstatus[35:34];
    let uxl = mstatus[33:32];
    let mxl = misa[31:30];
    logic[1:0] xlen;
    
    always_comb
    begin
        case (ring)
            0: assign xlen = uxl;
            1: assign xlen = sxl;
            3: assign xlen = mxl;
        endcase
    end
    
    logic[XLEN-1:0] rs1 = '0;
    logic[XLEN-1:0] rs2 = '0;
    logic[XLEN-1:0] rd = '0;
    // Exec stage cannot Strobe if Ready = 0
    logic Ready = '0;

    // XLEN can only increment/decrement by 2 (4 without RVC)
    logic[XLEN-2:0] pc = '0;
    
    // ----------------------
    // -- Logic Operations --
    // ----------------------
    // What operation

    // ALU ops
    // add, sub: ADD, ADDI, SUB; 64 ADDW, ADDIW, SUBW
    logic lopAdd = '0;
    // shift: SLL, SLLI, SRL, SRLI, SRA; 64 SLLIW, SRRIW, SRAIW
    logic lopShift = '0;
    // Comparator (SLT, SLTU, SLTI, SLTIU)
    logic lopCmp = '0;
    // AND: AND, ANDI
    logic lopAND = '0;
    // OR: OR, ORI
    logic lopOR = '0;
    // XOR: XOR, XORI
    logic lopXOR = '0;
    
    // Extension: M
    // Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
    logic lopMUL = '0;
    // Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
    logic lopDIV = '0;
    
    // Non-ALU ops
    // Load/Store
    logic lopLoad = '0;
    logic lopStore = '0;
    // illegal instruction
    logic lopIllegal = '0;

    // --------------------
    // -- Operation Flags--
    // --------------------
    // Word sizes: Byte, Half, Word, Double
    logic opB = '0;
    logic opH = '0;
    logic opW = '0;
    logic opD = '0;
    // Unsigned
    logic opUnsigned = '0;
    // Arithmetic is also Adder-Subtractor subtract
    logic opArithmetic = '0;
    logic opRightShift = '0;
    // MULHSU and DIV Remainder REM
    logic opHSU = '0;
    logic opRemainder = '0;

    // Load resource:   Type        what to load
    // bit 0:  R-type   Register    (rs1, rs2)
    logic lrR = '0;
    // bit 1:  I-type   Immediate   (rs1, insn[31:20] sign-extend)
    logic lrI = '0;
    // bit 2:  S-Type   Store       (rs1, insn[31:25] insn[11:7] sign-extended)
    logic lrS = '0;
    // bit 3:  B-type   Branch      (rs1, rs2, insn[31] insn[7] insn[30:25] insn[11:8] sign-extend)
    logic lrB = '0;
    // bit 4:  U-type   Upper-Imm   (insn[31:12])
    logic lrU = '0;
    // bit 5:  J-type   Jump        (insn[31] insn[19:12] insn[20] insn[30:21] sign-extend)
    logic lrJ = '0;

    // misa flags
    logic misaA = '0;
    logic misaB;
    logic misaC = '0;
    logic misaD;
    logic misaE;
    logic misaF;
    // Unassigned
    logic misaG;
    
    logic misaH = '0;
    logic misaI = '0;
    // Unassigned
    logic misaJ;
    logic misaK;
    logic misaL;
    
    logic misaM = '0;
    logic misaN;
    // Unassigned
    logic misaO;
    logic misaP;
    
    logic misaQ;
    // Unassigned
    logic misaR;
    
    logic misaS;
    // Unassigned
    logic misaT;
    
    logic misaU;
    // Unassigned
    logic misaV;
    logic misaW;

    logic misaX;
    // Unassigned
    logic misaY;
    logic misaZ;

    modport FetchOut
    (
        output FetchData
    );
    
    modport FetchIn
    (
        input FetchData
    );

    // Used in most stages.  Sends context information forward.
    modport ContextOut
    (
        output insn,
        output mstatus,
        output ring,
        output xlen,
        output pc,

        output misaA,
        output misaB,
        output misaC,
        output misaD,
        output misaE,
        output misaF,
        output misaG,
        output misaH,
        output misaI,
        output misaJ,
        output misaK,
        output misaL,
        output misaM,
        output misaN,
        output misaO,
        output misaP,
        output misaQ,
        output misaR,
        output misaS,
        output misaT,
        output misaU,
        output misaV,
        output misaW,
        output misaX,
        output misaY,
        output misaZ
    );

    // Provides inputs used for most stages
    // A translation layer (e.g. RVC) is a context in (from Fetch) and a context out
    // (to Decode).
    modport ContextIn
    (
        input insn,
        input mstatus,
        input ring,
        input xlen,
        input pc,

        input misaA,
        input misaB,
        input misaC,
        input misaD,
        input misaE,
        input misaF,
        input misaG,
        input misaH,
        input misaI,
        input misaJ,
        input misaK,
        input misaL,
        input misaM,
        input misaN,
        input misaO,
        input misaP,
        input misaQ,
        input misaR,
        input misaS,
        input misaT,
        input misaU,
        input misaV,
        input misaW,
        input misaX,
        input misaY,
        input misaZ
    );

    // Decode:  take fetched data, analyze, mark up single-bits signaling what kind
    // of operation to carry out.
    //
    // These are the results
    modport DecodedOut
    (
        output lopAdd,
        output lopShift,
        output lopCmp,
        output lopAND,
        output lopOR,
        output lopXOR,
        output lopMUL,
        output lopDIV,
        output lopLoad,
        output lopStore,
        output lopIllegal,
        
        output opB,
        output opH,
        output opW,
        output opD,
        output opUnsigned,
        output opArithmetic,
        output opRightShift,
        output opHSU,
        output opRemainder,

        output lrR,
        output lrI,
        output lrS,
        output lrB,
        output lrU,
        output lrJ
    );

    modport DecodedIn
    (
        input lopAdd,
        input lopShift,
        input lopCmp,
        input lopAND,
        input lopOR,
        input lopXOR,
        input lopMUL,
        input lopDIV,
        input lopLoad,
        input lopStore,
        input lopIllegal,
        
        input opB,
        input opH,
        input opW,
        input opD,
        input opUnsigned,
        input opArithmetic,
        input opRightShift,
        input opHSU,
        input opRemainder,

        input lrR,
        input lrI,
        input lrS,
        input lrB,
        input lrU,
        input lrJ
    );

    // Loaded data
    // B and S type instructions use two registers and an immediate, but those instructions
    // are also rigid in their data sources (always two registers and the immediate) and so
    // don't benefit from having these parsed out
    modport LoadedOut
    (
        output rs1,
        output rs2
    );
    
    modport LoadedIn
    (
        input rs1,
        input rs2
    );
endinterface