// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/27/2020
// Design Name: RISC-V Decoder
// Module Name: Decoder
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A RISC-V Decoder
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

interface IDecoder
#(
    parameter XLEN = 32
);
    logic insn[31:0];
    logic misa[31:0];
    logic mstatus[XLEN-1:0];
    bit ring[1:0];
    
    // ------------
    // -- Output --
    // ------------
    // What operation
    // ALU ops
    // 0: add, sub: ADD, ADDI, SUB; 64 ADDW, ADDIW, SUBW
    // 1: shift: SLL, SLLI, SRL, SRLI, SRA; 64 SLLIW, SRRIW, SRAIW
    // 2: Comparator (SLT, SLTU, SLTI, SLTIU)
    // 3: AND: AND, ANDI
    // 4: OR: OR, ORI
    // 5: XOR: XOR, XORI
    //
    // Extension: M
    // 6: Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
    // 7: Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
    //  
    // Non-ALU ops
    // 8: illegal instruction
    //
    // Load/Store
    // 9: Load
    // 10: Store
    uwire logicOp[10:0];
    
    // Operation flags
    // bit 0:  *B
    // bit 1:  *H
    // bit 2:  *W
    // bit 3:  *D
    // bit 4:  Unsigned
    // bit 5:  Arithmetic (and Adder-Subtractor subtract)
    // bit 6:  Right-shift
    // bit 7:  MULHSU
    // bit 8:  DIV Remainder
    uwire opFlags[8:0];
    
    // Load resource:   Type        what to load
    // bit 0:  R-type   Register    (rs1, rs2)
    // bit 1:  I-type   Immediate   (rs1, insn[31:20] sign-extend)
    // bit 2:  S-Type   Store       (rs1, insn[31:25] & insn[11:7] sign-extended)
    // bit 3:  B-type   Branch      (rs1, rs2, insn[31] & insn[7] & insn[30:25] & insn[11:8] sign-extend)
    // bit 4:  U-type   Upper-Imm   (insn[31:12])
    // bit 5:  J-type   Jump        (insn[31] & insn[19:12] & insn[20] & insn[30:25] & insn[24:21] sign-extend)
    // bit 6:  U-type               AUIPC, LUI
    uwire loadResource[5:0];
    // When we've selected something
    uwire Sel;

    modport DecodeStage
    (
        input insn,
        input misa,
        input mstatus,
        input ring,
        output logicOp,
        output opFlags,
        output loadResource
    );

    modport DecoderTable
    (
        input insn,
        output logicOp,
        output opFlags,
        output loadResource,
        output Sel
    );
endinterface
