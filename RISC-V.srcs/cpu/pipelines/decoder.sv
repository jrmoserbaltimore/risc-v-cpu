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
endinterface
