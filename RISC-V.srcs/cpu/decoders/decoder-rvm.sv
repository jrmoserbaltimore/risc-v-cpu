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
    IPipelineData.DecodedOut DecodedOut,
    output logic Sel
);
    logic_ops_group_t ops;
    assign ops = DecodedOut.ops;

    logic [6:0] opcode;
    assign opcode = Insn.r.opcode;
    logic[2:0] funct3;
    assign funct3 = Insn.r.funct3;
    logic[6:0] funct7;
    assign funct7 = Insn.r.funct7;
    
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
            ops.flags.W = opcode[3];
            if ( !((ops.flags.W) && (funct3[2] == 1'b0) && (funct3 != 3'b000)) )
            begin
                // funct3 = 0xx mul, 1xx div
                ops.ops.MUL = ~funct3[2];
                ops.ops.DIV = funct3[2];
                // Half-word if MUL[H|HU|HSU]
                ops.flags.H = (ops.ops.MUL == 1'b0 && funct3[1:0] != 2'b00) ? 1'b1 : 1'b0;
                // Unsigned
                ops.flags.Unsigned = (
                             (funct3[2] & funct3[0] == 1'b1) // DIVU/REMU
                          || (funct3[2] == 1'b0 && funct3[1] == 1'b1) // MULHU/HSU
                         ) ? 1'b1 : 1'b0;
                // Remainder
                //DecodedOut.opRemainder = (funct3[2:1] == 2'b11) ? 1'b1 : 1'b0;
                ops.flags.Remainder = funct3[2] & funct3[1];
                // MULHSU
                ops.flags.HSU = (funct3 == 3'b010) ? 1'b1 : 1'b0;
            end
        end
        // Don't decode if not supported
        Sel = ContextIn.misa.M & (ops.ops.MUL | ops.ops.DIV); // | something;
    end
endmodule