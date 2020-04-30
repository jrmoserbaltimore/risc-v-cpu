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
// Revision: 0.1
// Revision 0.1 - Changed to IPipelineData interface
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

module RVMDecoderTable
(
    IPipelineData.ContextIn ContextIn,
    IPipelineData.DecodedOut DecodedOut,
    output logic Sel 
);
    // opcode
    let opcode = ContextIn.insn[6:0];
    let funct3 = ContextIn.insn[14:12];
    // I-type immediate value
    let imm = ContextIn.insn[31:20];
    // R-type
    let funct7 = ContextIn.insn[31:25];

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
        if (ContextIn.misaM == 1'b1)
        begin
            // Clear state
            DecodedOut.lopAdd = 1'b0;
            DecodedOut.lopShift = 1'b0;
            DecodedOut.lopCmp = 1'b0;
            DecodedOut.lopAND = 1'b0;
            DecodedOut.lopOR = 1'b0;
            DecodedOut.lopXOR = 1'b0;
            DecodedOut.lopMUL = 1'b0;
            DecodedOut.lopDIV = 1'b0;
            DecodedOut.lopLoad = 1'b0;
            DecodedOut.lopStore = 1'b0;
            DecodedOut.lopIllegal = 1'b0;
            
            DecodedOut.opB = 1'b0;
            DecodedOut.opH = 1'b0;
            DecodedOut.opW = 1'b0;
            DecodedOut.opD = 1'b0;
            DecodedOut.opUnsigned = 1'b0;
            DecodedOut.opArithmetic = 1'b0;
            DecodedOut.opRightShift = 1'b0;
            DecodedOut.opHSU = 1'b0;
            DecodedOut.opRemainder = 1'b0;
    
            DecodedOut.lrR = 1'b0;
            DecodedOut.lrI = 1'b0;
            DecodedOut.lrS = 1'b0;
            DecodedOut.lrB = 1'b0;
            DecodedOut.lrU = 1'b0;
            DecodedOut.lrJ = 1'b0;
            
            Sel = 1'b0;
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
                Sel = 1'b1;
                // extract W bit
                DecodedOut.opW = opcode[3];
                if ( !((DecodedOut.opW == 1'b1) && (funct3[2] == 1'b0) && (funct3 != 3'b000)) )
                begin
                    // funct3 = 0xx mul, 1xx div
                    DecodedOut.lopMUL = ~funct3[2];
                    DecodedOut.lopDIV = funct3[2];
                    // Half-word if MUL[H|HU|HSU]
                    DecodedOut.opH = (DecodedOut.lopMUL == 1'b0 && funct3[1:0] != 2'b00) ? 1'b1 : 1'b0;
                    // Unsigned
                    DecodedOut.opUnsigned = (
                                 (funct3[2] & funct3[0] == 1'b1) // DIVU/REMU
                              || (funct3[2] == 1'b0 && funct3[1] == 1'b1) // MULHU/HSU
                             ) ? 1'b1 : 1'b0;
                    // Remainder
                    //DecodedOut.opRemainder = (funct3[2:1] == 2'b11) ? 1'b1 : 1'b0;
                    DecodedOut.opRemainder = funct3[2] & funct3[1];
                    // MULHSU
                    DecodedOut.opHSU = (funct3 == 3'b010) ? 1'b1 : 1'b0;
                end
            end
        end
    end
endmodule