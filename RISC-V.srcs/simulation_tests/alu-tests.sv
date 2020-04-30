// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: ALU Tests
// Module Name: TALUTests
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: ALU component tests
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

module TALUTests
(
);
    logic Clk;
    realtime ClkDelay = 2.5; // 500MHz
    
    IBarrelShifter #(8) Ibs();
    BarrelShifter #(8) bs(.Shifter(Ibs.Shifter));

    // set the clock
    initial
    begin
        #ClkDelay Clk = ~Clk;
    end

    always_comb
    begin
        Ibs.ALU.Din = 8'b10110101;
        Ibs.ALU.Shift = 4'b0011;
        Ibs.ALU.opArithmetic = 1'b0;
        Ibs.ALU.opRightShift = 1'b0;
    end
    
    
//    always_ff@(posedge Clk)
//    begin
//
//    end
    
endmodule