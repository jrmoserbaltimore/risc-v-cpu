// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 05/02/2020
// Design Name: Branch Control
// Module Name: ControlBranch
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A branching and control transfer function
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:
// 
// This relies on an ALU providing add and compare.  Full ALUs provide compare as
// a separate function in parallel, so a single ALU execution unit can implement
// branching.
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

module ControlBranch
#(
    XLEN = 32
)
(
    IPipelineData.ContextIn ContextIn,
    IPipelineData.LoadedOut DataPort,
    IALU.Client ALU,
    output logic Sel
);

        module Branch
        #(
            XLEN = 32
        )
        (
            IPipelineData.ContextIn ContextIn,
            IPipelineData.LoadedOut DataPort,
            IALU.Client ALU,
            output logic Sel
        );
        let funct3 = ContextIn.insn[14:12];
        // Have to add a 0 onto the end because the offset is in half-words (2 bytes)
        let imm = {
                   {(XLEN-12){ContextIn.insn[31]}},
                   ContextIn.insn[7],
                   ContextIn.insn[30:25],
                   ContextIn.insn[11:8],
                   1'b0
                  };
        always_comb
        begin
            // add the branch offset to the immediate.
            // PC is always aligned to 16 bits, so we don't pass the LSB, just like RISC-V
            // excludes the LSB from the branchp JAL, and JALR immediates
            assign ALU.rs1 = {ContextIn.pc, 1'b0};
            assign ALU.rs2 = imm;
            assign ALU.lopAd = 1'b1;
            assign ALU.A = DataPort.rs1;
            assign ALU.B = DataPort.rs2;
            assign Sel = (
                ~ALU.Equals == funct3[2] ^ funct3[0]  // BEQ, BNE, BGEU optimization
                || (ALU.LessThan == 1'b1 && funct3 == 3'b100) // BLT
                || (ALU.LessThanUnsigned == 3'b110) // BLTU
                || (ALU.LessThan == 1'b0 && funct3 == 3'b101) // BGE
                || (ALU.LessThanUnsigned == 1'b0 && funct3 == 3'b111) // BGEU
               ) ? 1'b1 : 1'b0;
        end
    endmodule
endmodule
