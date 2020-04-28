// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: Fabric Arithmetic Logic Unit
// Module Name: FullALU
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: An ALU using defined fabric components
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:
// 
// This ALU uses fabric components rather than relying on inferrence.
//
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

// Semantics of addressing all these things directly would cause large human error
`define lopAdd ALUPort.logicOp[0]
`define lopShift ALUPort.logicOp[1]
`define lopCmp ALUPort.logicOp[2]
`define lopAND ALUPort.logicOp[3]
`define lopOR ALUPort.logicOp[4]
`define lopXOR ALUPort.logicOp[5]
`define lopMUL ALUPort.logicOp[6]
`define lopDIV ALUPort.logicOp[7]

`define opB ALUPort.opFlags[0]
`define opH ALUPort.opFlags[1]
`define opW ALUPort.opFlags[2]
`define opD ALUPort.opFlags[3]
`define opUnS ALUPort.opFlags[4]
`define opAr ALUPort.opFlags[5]
`define opRSh ALUPort.opFlags[6]
`define opHSU ALUPort.opFlags[7]
`define opRem ALUPort.opFlags[8]

module FullALU
#(
    XLEN = 32
)
(
    IALU.ALU ALUPort
);

    always_ff@(posedge ALUPort.Clk)
    begin
        if (`lopAdd == 1'b1 && `opAr == 1'b0)
            // FIXME:  han-carlson, ladner-fischer, or carry-select module.
            // Pass opAr as the sub flag to the module
            assign ALUPort.rd = ALUPort.rs1 + ALUPort.rs2;
        else if (`lopAdd == 1'b1 && `opAr == 1'b1)
            // FIXME:  Remove in favor of adder-subtractor
            assign ALUPort.rd = ALUPort.rs1 - ALUPort.rs2;
        // FIXME:  Shift, Comparator
        // There are basic gates
        else if (`lopAND == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 & ALUPort.rs2;
        else if (`lopOR == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 | ALUPort.rs2;
        else if (`lopXOR == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 ^ ALUPort.rs2;
        // FIXME:  MUL, DIV
    end;
endmodule

`undef lopAdd
`undef lopShift
`undef lopCmp
`undef lopAND
`undef lopOR
`undef lopXOR
`undef lopMUL
`undef lopDIV

`undef opB
`undef opH
`undef opW
`undef opD
`undef opUnS
`undef opAr
`undef opRSh
`undef opHSU
`undef opRem