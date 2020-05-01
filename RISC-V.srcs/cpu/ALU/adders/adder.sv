// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: Adder
// Module Name: IAdder
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: Adder interface
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

interface IAdder
#(
    XLEN = 32
);
    logic [XLEN-1:0] A;
    logic [XLEN-1:0] B;
    logic Sub;
    logic Speculate;
    logic Error;
    logic [XLEN-1:0] S;

    modport Adder
    (
        input A,
        input B,
        input Sub,
        input Speculate,
        output Error,
        output S
    );
    modport ALU
    (
        output A,
        output B,
        output Sub,
        output Speculate,
        input Error,
        input S
    );
endinterface