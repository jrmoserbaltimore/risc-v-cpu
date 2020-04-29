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
    parameter XLEN = 32
);
    logic insn[31:0];
    logic misa[31:0];
    logic mstatus[XLEN-1:0];
    bit ring[1:0];

    logic rs1[XLEN-1:0];
    logic rs2[XLEN-1:0];
    logic rd[XLEN-1:0];
    // Exec stage cannot Strobe if Ready = 0
    logic Ready;

    // XLEN can only increment/decrement by 2 (4 without RVC)
    logic pc[XLEN-2:0];
    
    // ----------------------
    // -- Logic Operations --
    // ----------------------
    // What operation

    // ALU ops
    // add, sub: ADD, ADDI, SUB; 64 ADDW, ADDIW, SUBW
    logic lopAdd;
    // shift: SLL, SLLI, SRL, SRLI, SRA; 64 SLLIW, SRRIW, SRAIW
    logic lopShift;
    // Comparator (SLT, SLTU, SLTI, SLTIU)
    logic lopCmp;
    // AND: AND, ANDI
    logic lopAND;
    // OR: OR, ORI
    logic lopOR;
    // XOR: XOR, XORI
    logic lopXOR;
    
    // Extension: M
    // Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
    logic lopMUL;
    // Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
    logic lopDIV;
    
    // Non-ALU ops
    // Load/Store
    logic lopLoad;
    logic lopStore;
    // illegal instruction
    logic lopIllegal;

    // --------------------
    // -- Operation Flags--
    // --------------------
    // Word sizes: Byte, Half, Word, Double
    logic opB;
    logic opH;
    logic opW;
    logic opD;
    // Unsigned
    logic opUnsigned;
    // Arithmetic is also Adder-Subtractor subtract
    logic opArithmetic;
    logic opRightShift;
    // MULHSU and DIV Remainder REM
    logic opHSU;
    logic opRemainder;

    // Load resource:   Type        what to load
    // bit 0:  R-type   Register    (rs1, rs2)
    logic lrR;
    // bit 1:  I-type   Immediate   (rs1, insn[31:20] sign-extend)
    logic lrI;
    // bit 2:  S-Type   Store       (rs1, insn[31:25] insn[11:7] sign-extended)
    logic lrS;
    // bit 3:  B-type   Branch      (rs1, rs2, insn[31] insn[7] insn[30:25] insn[11:8] sign-extend)
    logic lrB;
    // bit 4:  U-type   Upper-Imm   (insn[31:12])
    logic lrU;
    // bit 5:  J-type   Jump        (insn[31] insn[19:12] insn[20] insn[30:21] sign-extend)
    logic lrJ;

    // misa flags
    logic misaA;
    logic misaB;
    logic misaC;
    logic misaD;
    logic misaE;
    logic misaF;
    // Unassigned
    logic misaG;
    
    logic misaH;
    logic misaI;
    // Unassigned
    logic misaJ;
    logic misaK;
    logic misaL;
    
    logic misaM;
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

    modport Decoder
    (
        input insn,
        input mstatus,
        input ring,
        
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
        input misaZ,
        
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

    modport ALU
    (
        input insn,
        input rs1,
        input rs2,
        
        input lopAdd,
        input lopShift,
        input lopCmp,
        input lopAND,
        input lopOR,
        input lopXOR,
        input lopMUL,
        input lopDIV,
        
        input opB,
        input opH,
        input opW,
        input opD,
        input opUnsigned,
        input opArithmetic,
        input opRightShift,
        input opHSU,
        input opRemainder,
    
        output rd,
        output Ready
    );    
endinterface