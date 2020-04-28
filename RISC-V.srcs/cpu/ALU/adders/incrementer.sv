// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/27/2020
// Design Name: Carry Incrementer
// Module Name: Incrementer
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: An incrementer taking Cin=1 (increment) or 0 (don't)
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:  Combinatorial for use in larger circuit
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

interface IIncrementer
#(
    parameter Width = 32
);

    logic Cin = '0;
    logic Cout = '0;

    logic Din[Width-1:0];
    logic Dout[Width-1:0];

    modport Inc
    (
        input Din,
        input Cin,
        output Dout,
        output Cout
    );
endinterface

module RCIncrementer
#(
    parameter Width = 32
)
(
    IIncrementer.Inc Incrementer
);
    logic Carry[Width:0];    

    assign Carry[0] = Incrementer.Cin;
    assign Incrementer.Cout = Carry[Width];

/*
    // Gate logic, just half-adders with carry rippling through as one of the addends 
    generate
        genvar stage;
        for (stage = 0; stage < Width; stage++)
        begin
            xor (Incrementer.Dout[stage], Incrementer.Din[stage], Carry[stage]);
            and (Carry[stage+1], Incrementer.Din[stage], Carry[stage]);            
        end
    endgenerate
*/
    // Behavioral, hopefuly easier on the LUTs
    always_comb
    begin
        int c;
        assign c = 1;
        for (int stage = 0; stage < Width; stage++)
        begin
            if (Incrementer.Din[stage] == 1 && c == 1)
                Incrementer.Dout[stage] = '0;
            else
            begin
                Incrementer.Dout[stage] = Incrementer.Din[stage] | c;
                assign c = '0;
            end
        end
    end
endmodule

// Carry-Select incrementer
// In case RCIncrementer puts your component in the critical path.
// Useful when incrementing PC and other internal state
module CSIncrementer
#(
    parameter Width = 32,
    // Increment is one gate depth, versus full-adder with three gate depth to get each carry
    Bundle = 16
)
(
    IIncrementer.Inc Incrementer
);

    generate
        genvar i;
        logic Carry[Width/Bundle:0];
        assign Carry[0] = Incrementer.Cin;
        RCIncrementer #(Bundle) FirstGroup;

        assign FirstGroup.Din = Incrementer.Din[Bundle-1:0];
        assign FirstGroup.Cin = Incrementer.Cin;
        assign Incrementer.Dout[Bundle-1:0] = FirstGroup.Dout;
        assign Carry[0] = FirstGroup.Cout;

        for (i = 1; i*4 <= Width; i ++)
        begin
            RCIncrementer #(Bundle) NoCarry;
            RCIncrementer #(Bundle) WithCarry;

            // Assign Din as a slice of the full Din
            assign NoCarry.Din = Incrementer.Din[(i+1)*Bundle:i*Bundle];
            assign NoCarry.Cin = '0;

            assign WithCarry.Din = Incrementer.Din[(i+1)*Bundle:i*Bundle];
            assign WithCarry.Cin = '1;

            assign Carry[i] = (Carry[i-1] == '0) ? NoCarry.Cout : WithCarry.Cout;

            // Select based on the previous carry outcome
            assign Incrementer.Dout[(i+1)*Bundle:i*Bundle] = (Carry[i-1] == '0) ? NoCarry.Dout : WithCarry.Dout;
        end
        assign Incrementer.Cout = Carry[Width/Bundle-1];
    endgenerate 
endmodule