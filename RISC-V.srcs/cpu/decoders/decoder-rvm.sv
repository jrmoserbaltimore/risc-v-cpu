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
// Revision: 0.2
// Revision 0.2 - Reworked around new data unions
// Revision 0.1 - Changed to IPipelineData interface
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

module RVMDecoderTable
(
    input instruction_t Insn,
    IPipelineData.ContextIn ContextIn,
    output decode_data_t DecodedOut,
    output uwire Sel
);
    // Don't decode if not supported
    assign Sel =  ContextIn.misa.misa.M
         & (DecodedOut.ops.ops.MUL | DecodedOut.ops.ops.DIV);
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
        // Clear state
        DecodedOut.bitfield = '0;
        if (
               ((Insn.r.opcode | "0001000") == 7'b0111011) // Only these bits on
            && (Insn.r.funct7 == 7'b0000001) // Mul/Div function
            // and not the invalid MULW signed/half instructions
            && !(Insn.r.opcode[3] == 1'b1 // 64-bit
                 && Insn.r.funct3[1:0] != 2'b00 // H/U/HSU
                 && Insn.r.funct3[2] == 1'b1) // MULW
           )
       begin
            // Essential mask 011_011
            // This covers everything so we're good
            // extract W bit
            DecodedOut.ops.flags.W = Insn.r.opcode[3];
            if ( !((DecodedOut.ops.flags.W) && (Insn.r.funct3[2] == 1'b0) && (Insn.r.funct3 != 3'b000)) )
            begin
                // funct3 = 0xx mul, 1xx div
                DecodedOut.ops.ops.MUL = ~Insn.r.funct3[2];
                DecodedOut.ops.ops.DIV = Insn.r.funct3[2];
                // Half-word if MUL[H|HU|HSU]
                DecodedOut.ops.flags.H = (DecodedOut.ops.ops.MUL == 1'b0 && Insn.r.funct3[1:0] != 2'b00) ? 1'b1 : 1'b0;
                // Unsigned
                DecodedOut.ops.flags.Unsigned = (
                             (Insn.r.funct3[2] & Insn.r.funct3[0] == 1'b1) // DIVU/REMU
                          || (Insn.r.funct3[2:1] == 2'b01) // MULHU/HSU
                         ) ? 1'b1 : 1'b0;
                // Remainder
                //DecodedOut.opRemainder = (funct3[2:1] == 2'b11) ? 1'b1 : 1'b0;
                DecodedOut.ops.flags.Remainder = Insn.r.funct3[2] & Insn.r.funct3[1];
                // MULHSU
                DecodedOut.ops.flags.HSU = (Insn.r.funct3 == 3'b010) ? 1'b1 : 1'b0;
            end
        end
    end
endmodule