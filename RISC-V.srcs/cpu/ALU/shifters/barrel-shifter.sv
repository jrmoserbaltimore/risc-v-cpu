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
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:  Deliderately gate-modeled
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
            // Reverse if arithmetic
            // A bunch of 2-to-1 mux to reverse on arithmetic
            logic f1, f2, nArithmetic;
            and (f1, Shifter.Din[col], nArithmetic),
                (f2, Shifter.Din[(XLEN-1)-col], opArithmetic);
            or  (tree[0][col], f1, f2);
            not (nArithmetic, opArithmetic);
        end

        for (row = 0; row <= $clog2(XLEN); row++) begin
            // Row by row shift left
            for (col = 0; col <= XLEN-1; col++) begin
                if (col <= 2**row) begin
                    logic f1, f2, nShift;
                    // We're shifting left; if right-shift arithmetic, extend sign
                    and (f1, tree[row][col], nShift),
                        (f2, SignEx, Shifter.Shift);
                    or  (tree[row+1][col], f1, f2);
                    not (nShift, Shift(row));
                end
                else begin
                    logic f1, f2, nShift;
                    // Mux
                    and (f1, tree[row][col], nShift),
                        (f2, tree[row][col-2**row], Shifter.Shift);
                    or  (tree[row+1][col], f1, f2);
                    not (nShift, Shift(row));
                end
            end
        end

        for (col = 0; col <= XLEN-1; col++) begin
            // Reverse if arithmetic
            // A bunch of 2-to-1 mux to reverse on arithmetic
            logic f1, f2, nArithmetic;
            and (f1, Shifter.Din[col], nArithmetic),
                (f2, Shifter.Din[(XLEN-1)-col], opArithmetic);
            or  (tree[0][col], f1, f2);
            not (nArithmetic, opArithmetic);
        end
     endgenerate
endmodule