// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: RISC-V RVM Decoder
// Module Name: RVIDecoderTable
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A RISC-V RVM Decoder
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

// Semantics of addressing all these things directly would cause large human error
`define lopAdd DecoderPort.logicOp[0]
`define lopShift DecoderPort.logicOp[1]
`define lopCmp DecoderPort.logicOp[2]
`define lopAND DecoderPort.logicOp[3]
`define lopOR DecoderPort.logicOp[4]
`define lopXOR DecoderPort.logicOp[5]
`define lopMUL DecoderPort.logicOp[6]
`define lopDIV DecoderPort.logicOp[7]
`define lopIll DecoderPort.logicOp[8]
`define lopLoad DecoderPort.logicOp[9]
`define lopStore DecoderPort.logicOp[10]

`define opB DecoderPort.opFlags[0]
`define opH DecoderPort.opFlags[1]
`define opW DecoderPort.opFlags[2]
`define opD DecoderPort.opFlags[3]
`define opUnS DecoderPort.opFlags[4]
`define opAr DecoderPort.opFlags[5]
`define opRSh DecoderPort.opFlags[6]
`define opHSU DecoderPort.opFlags[7]
`define opRem DecoderPort.opFlags[8]

`define lrR DecoderPort.loadResource[0]
`define lrI DecoderPort.loadResource[1]
`define lrS DecoderPort.loadResource[2]
`define lrB DecoderPort.loadResource[3]
`define lrU DecoderPort.loadResource[4]
`define lrJ DecoderPort.loadResource[5]
`define lrUPC DecoderPort.loadResource[6]

module RVMDecoderTable
(
    IDecoder.DecoderTable DecoderPort
);
    // opcode
    let opcode = DecoderPort.insn[6:0];
    let funct3 = DecoderPort.insn[14:12];
    // I-type immediate value
    let imm = DecoderPort.insn[31:20];
    // R-type
    let funct7 = DecoderPort.insn[31:25];
    // misa flags
    let exA = misa[0];
    let exB = misa[1];
    let exC = misa[2];
    let exD = misa[3];
    let exE = misa[4];
    let exF = misa[5];

    let exH = misa[7];
    let exI = misa[8];

    let exM = misa[12];
    let exN = misa[13];

    let exQ = misa[16];

    let exS = misa[18];

    let exU = misa[20];

    let exX = misa[23];

    // ----------------------------
    //  -- RV32M/RV64M operations --
    // ----------------------------
    // W operations: 011w011
    // funct7   funct3  opcode      insn    opcode-w=1  Notes
    // 0000001  000     011w011     MUL     MULW
    // 0000001  001     011w011     MULH                Upper XLEN bits for 2*XLEN product
    // 0000001  010     011w011     MULHSU              Same, r1 signed * r2 unsigned
    // 0000001  011     011w011     MULHU               Same, r1 and r2 both unsigned
    // 0000001  100     011w011     DIV     DIVW
    // 0000001  101     011w011     DIVU    DIVUW
    // 0000001  110     011w011     REM     REMW
    // 0000001  111     011w011     REMU    REMUW
    always_comb
    begin
        // Not supported, so don't decode.
        if (exM == 1'b1)
        begin
            if (
                   ((opcode | "0001000") == 7'b0111011) // Only these bits on
                && (funct7 == 7'b0000001) // Mul/Div function
                // and not the invalid MULW signed/half instructions
                && !(opcode[3] == 1'b1 // 64-bit
                     && funct3[1:0] != 2'b00 // H/U/HSU
                     && funct3[2] == 1'b1) // MULW
               )
           begin
                // Essential mask 011_011
                // This covers everything so we're good
                DecoderPort.Sel = 1'b1;
                // extract W bit
                `opW = opcode[3];
                if ( !((`opW == 1'b1) && (funct3[2] == 1'b0) && (funct3 != 3'b000)) )
                begin
                    // funct3 = 0xx mul, 1xx div
                    `lopMUL <= ~funct3[2];
                    `lopDIV <= funct3[2];
                    // Half-word if MUL[H|HU|HSU]
                    `opH = (`lopMUL == 1'b0 && funct3[1:0] != 2'b00) ? 1'b1 : 1'b0;
                    // Unsigned
                    `opUnS = (
                                 (funct3[2] & funct3[0] == 1'b1) // DIVU/REMU
                              || (funct3[2] == 1'b0 && funct3[1] == 1'b1) // MULHU/HSU
                             ) ? 1'b1 : 1'b0;
                    // Remainder
                    //`opRem = (funct3[2:1] == 2'b11) ? 1'b1 : 1'b0;
                    `opRem = funct3[2] & funct3[1];
                    // MULHSU
                    `opHSU = (funct3 == 3'b010) ? 1'b1 : 1'b0;
                end
            end
        end
    end
endmodule
