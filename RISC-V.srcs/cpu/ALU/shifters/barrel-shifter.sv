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
// Revision: 1.0
// Revision 1.0 - Behavioral modeling
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
    logic [XLEN-1:0] Din;
    logic [$clog2(XLEN):0] Shift;
    logic [XLEN-1:0] Dout;    
    // Operation flags
    // bit 0:  Arithmetic (and Adder-Subtractor subtract)
    // bit 1:  Right shift
    logic opArithmetic;
    logic opRightShift;

    modport Shifter
    (
        input Din,
        input Shift,
        input opArithmetic,
        input opRightShift,
        output Dout
    );
    
    modport ALU
    (
        output Din,
        output Shift,
        output opArithmetic,
        output opRightShift,
        input Dout
    );
endinterface

module BarrelShifter
#(
    parameter XLEN = 32
)
(
    IBarrelShifter.Shifter Shifter
);

    logic SignEx;

    always_comb
    begin
        // Sign-extend using the MSB of DN if both shifting right and arithmetic
        SignEx = Shifter.Din[XLEN-1] & Shifter.opArithmetic & Shifter.opRightShift;
    end

    generate
        genvar row;
        genvar col;
        // Barrel shifter tree
        logic [$clog2(XLEN)+1:0][XLEN-1:0] tree;

        // input reversed?
        for (col = 0; col <= XLEN-1; col++) begin
            // Reverse if right shift
            // A bunch of 2-to-1 mux to reverse on arithmetic
            assign tree[0][col] = (Shifter.opRightShift == 0)
              ? Shifter.Din[col]
              : Shifter.Din[(XLEN-1)-col];
        end

        for (row = 0; row <= $clog2(XLEN); row++) begin
            // Row by row shift left
            for (col = 0; col <= XLEN-1; col++) begin
                if (col < 2**row) begin
                    // Set the bits being shifted in if shifting this row.
                    // if right-shift arithmetic, extend sign
                    assign tree[row+1][col] = (Shifter.Shift[row] == 0) ? tree[row][col] : SignEx;
                end
                else begin
                    assign tree[row+1][col] = (Shifter.Shift[row] == 0)
                      ? tree[row][col]
                      : tree[row][col-(2**row)];
                end
            end
        end

        for (col = 0; col <= XLEN-1; col++) begin
            // Reverse back for right shift
            assign Shifter.Dout[col] = (Shifter.opRightShift == 0)
              ? tree[$clog2(XLEN)+1][col]
              : tree[$clog2(XLEN)+1][(XLEN-1)-col];
        end
     endgenerate
endmodule