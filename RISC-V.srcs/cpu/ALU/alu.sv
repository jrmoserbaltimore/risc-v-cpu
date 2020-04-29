// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: Arithmetic Logic Unit
// Module Name: BasicALU
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A basic ALU relying on synthesis
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:
// 
// The ALU pointedly does not complain about invalid input.  Don't send invalid input.
//
// ALU operations like MUL and DIV may use the ALU's other resources, such as bit
// shifts and masks, addition, or even the multiplier.  MUL and DIV consume adder
// resources for several cycles; additional ALUs are valuable in OOE and superscalar
// applications. 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

module BasicALU
#(
    XLEN = 32
)
(
    input logic Clk,
    IPipelineData.ALU ALUPort
);

    always_ff@(posedge Clk)
    begin
        if (ALUPort.lopAdd == 1'b1 && ALUPort.opArithmetic == 1'b0)
            assign ALUPort.rd = ALUPort.rs1 + ALUPort.rs2;
        else if (ALUPort.lopAdd == 1'b1 && ALUPort.opArithmetic == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 - ALUPort.rs2;
        // FIXME:  Shift, Comparator
        else if (ALUPort.lopAND == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 & ALUPort.rs2;
        else if (ALUPort.lopOR == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 | ALUPort.rs2;
        else if (ALUPort.lopXOR == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 ^ ALUPort.rs2;
        // FIXME:  MUL, DIV
        // paravartya or quick-div
        
        // Divider obtains and caches the remainder and product to
        // catch the RISC-V M specified sequence:
        //   DIV[U] rdq, rs1, rs2
        //   REM[U] rdq, rs1, rs2
        // This sequence is fused together into a single divide.
        //
        // Various divider components are possible, e.g. Paravartya.
        // The ALU requires a divider implementation, as the DSP
        // does not provide one.
    end;
endmodule