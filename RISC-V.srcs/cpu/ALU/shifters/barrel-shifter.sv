// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/26/2020
// Design Name: Barrel Shifter
// Module Name: BarrelShifter
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A barrel shifter
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.02
// Revision 0.02 - Used a nested module
// Revision 0.02 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

interface IBarrelShifter
#(
    parameter XLEN = 32
);

    uwire Clk;
    uwire Rst;
    
    bit Din[XLEN-1:0];
    bit Shift[$clog2(XLEN):0];
    bit Dout[XLEN-1:0];    
    // Operation flags
    // bit 0:  Arithmetic (and Adder-Subtractor subtract)
    // bit 1:  Right shift
    logic opFlags[1:0];

    let opArithmetic = opFlags(0);
    let opRightShift = opFlags(0);

    modport Shifter
    (
        input Din,
        input Shift,
        input opFlags,
        output Dout
    );
    
    modport ALU
    (
        output Din,
        output Shift,
        output opFlags,
        input Dout
    );
endinterface

module BarrelShifter
#(
    parameter XLEN = 32
)
(
    input logic Clk,
    BarrelShifter.Shifter Shifter
);

    module Mux
    (
        output uwire s,
        input uwire a,
        input uwire b,
        input uwire sel
    );
        uwire f1, f2, nsel;
        and (f1, a, nsel),
            (f2, b, sel);
        or  (s, f1, f2);
        not (nsel, sel);
    endmodule
    
    logic SignEx;

    let opArithmetic = Shifter.opFlags[0];
    let opRightShift = Shifter.opFlags[0];

    and (SignEx, Shifter.Din[XLEN-1], opArithmetic, opRightShift);

    genvar row;
    genvar col;
    generate
        // Barrel shifter tree
        logic [$clog2(XLEN)+1:0][XLEN-1:0] tree;

        // input reversed?
        for (col = 0; col <= XLEN-1; col++) begin
            // Reverse if right shift
            // A bunch of 2-to-1 mux to reverse on arithmetic
            Mux m(tree[0][col], Shifter.Din[col], Shifter.Din[(XLEN-1)-col], opRightShift);
        end

        for (row = 0; row <= $clog2(XLEN); row++) begin
            // Row by row shift left
            for (col = 0; col <= XLEN-1; col++) begin
                if (col <= 2**row) begin
                    // Set the bits being shifted in if shifting this row.
                    // if right-shift arithmetic, extend sign
                    Mux m(tree[row+1][col], tree[row][col], SignEx, Shifter.Shift[row]);
                end
                else begin
                    Mux m(tree[row+1][col], tree[row][col], tree[row][col-2**row], Shifter.Shift[row]);
                end
            end
        end

        for (col = 0; col <= XLEN-1; col++) begin
            // Reverse back for right shift
            Mux m(
                  Shifter.Dout[col],
                  tree[$clog2(XLEN)+1][col],
                  tree[$clog2(XLEN)+1][(XLEN-1)-col],
                  opRightShift
                 );
        end
     endgenerate
endmodule