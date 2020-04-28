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

    uwire Cin = '0;
    uwire Cout = '0;

    uwire Din[Width-1:0];
    uwire Dout[Width-1:0];

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
    uwire Carry[Width:0];    

    assign Carry[0] = Incrementer.Cin;
    assign Incrementer.Cout = Carry[Width];

    genvar stage;
    generate
        for (stage = 0; stage < Width; stage++) begin
            xor (Incrementer.Dout[stage], Incrementer.Din[stage], Carry[stage]);
            and (Carry[stage+1], Incrementer.Din[stage], Carry[stage]);            
        end
    endgenerate
endmodule

// Carry-Select incrementer
// In case RCIncrementer puts your component in the critical path.
// Useful when incrementing PC and other internal state
module CSIncrementer
#(
    parameter Width = 32
)
(
    IIncrementer.Inc Incrementer
);

    generate
        genvar i;
        logic Carry[Width/4:0];
        assign Carry[0] = Incrementer.Cin;
        RCIncrementer #(4) FirstGroup;

        assign FirstGroup.Din = Incrementer.Din[3:0];
        assign FirstGroup.Cin = Incrementer.Cin;
        assign Incrementer.Dout[3:0] = FirstGroup.Dout;
        assign Carry[0] = FirstGroup.Cout;

        for (i = 1; i*4 <= Width; i ++) begin
            RCIncrementer #(4) NoCarry;
            RCIncrementer #(4) WithCarry;

            assign NoCarry.Din = Incrementer.Din[(i+1)*4:i*4];
            assign NoCarry.Cin = '0;

            assign WithCarry.Din = Incrementer.Din[(i+1)*4:i*4];
            assign WithCarry.Cin = '1;

            assign Carry[i] = (Carry[i-1] == '0) ? NoCarry.Cout : WithCarry.Cout;

            assign Incrementer.Dout[(i+1)*4:i*4] = (Carry[i-1] == '0) ? NoCarry.Dout : WithCarry.Dout;
        end
        assign Incrementer.Cout = Carry[Width/4];
    endgenerate 
endmodule