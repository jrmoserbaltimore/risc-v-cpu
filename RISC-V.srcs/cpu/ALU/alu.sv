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
// MUL may use the ALU's other resources, including bi shifters and the adder.  MUL
// ties up the ALU for several cycles.
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

interface IALU
#(
    parameter XLEN = 32
);
    logic [XLEN-1:0] A, B;
    logic Equal, LessThan, LessThanUnsigned;
    
    modport Comparator
    (
        output A,
        output B,
        input Equal,
        input LessThan,
        input LessThanUnsigned
    );
    
    modport ALU
    (
        input A,
        input B,
        output Equal,
        output LessThan,
        output LessThanUnsigned
    );
endinterface

module BasicALU
#(
    XLEN = 32
)
(
    input logic Clk,
    IPipelineData.LoadedIn DataPort,
    IPipelineData.ALU ALUPort,
    IALU.ALU CmpPort
);

    IBarrelShifter #(XLEN) Ibs();
    BarrelShifter #(XLEN) bs(.Shifter(Ibs.Shifter));

    // one-cycle operations
    always_comb
    begin
        CmpPort.Equal = (CmpPort.A == CmpPort.B) ? 1'b1 : 1'b0;
        CmpPort.LessThan = (signed'(CmpPort.A) < signed'(CmpPort.B)) ? 1'b1 : 1'b0;
        CmpPort.LessThanUnsigned = (unsigned'(CmpPort.A) < unsigned'(CmpPort.B)) ? 1'b1 : 1'b0;

        if (ALUPort.lopAND == 1'b1)
            assign ALUPort.rd = DataPort.rs1 & DataPort.rs2;
        else if (ALUPort.lopOR == 1'b1)
            assign ALUPort.rd = DataPort.rs1 | DataPort.rs2;
        else if (ALUPort.lopXOR == 1'b1)
            assign ALUPort.rd = DataPort.rs1 ^ DataPort.rs2;
    end

    always_ff@(posedge Clk)
    begin
        if (ALUPort.lopAdd == 1'b1 && ALUPort.opArithmetic == 1'b0)
            assign ALUPort.rd = DataPort.rs1 + DataPort.rs2;
        else if (ALUPort.lopAdd == 1'b1 && ALUPort.opArithmetic == 1'b1)
            assign ALUPort.rd = DataPort.rs1 - DataPort.rs2;
        else if (ALUPort.lopShift == 1'b1)
        begin
            assign Ibs.Shifter.Din = DataPort.rs1;
            assign Ibs.Shifter.Shift = DataPort.rs2[$clog2(XLEN):0];
            assign Ibs.Shifter.opArithmetic = ALUPort.opArithmetic;
            assign Ibs.Shifter.opRightShift = ALUPort.opRightShift;
            assign ALUPort.rd = Ibs.Shifter.Dout;
        end
        // FIXME:  MUL

    end;
endmodule

// Supports only add, sub, cmp, and shift, plus bitmasks because they're cheap
// Basically omits MUL.
module SubsetALU
#(
    XLEN = 32
)
(
    input logic Clk,
    IPipelineData.LoadedIn DataPort,
    IPipelineData.ALU ALUPort,
    IALU.ALU CmpPort
);

    IBarrelShifter #(XLEN) Ibs();
    BarrelShifter #(XLEN) bs(.Shifter(Ibs.Shifter));

    // one-cycle operations
    always_comb
    begin
        CmpPort.Equal = (CmpPort.A == CmpPort.B) ? 1'b1 : 1'b0;
        CmpPort.LessThan = (signed'(CmpPort.A) < signed'(CmpPort.B)) ? 1'b1 : 1'b0;
        CmpPort.LessThanUnsigned = (unsigned'(CmpPort.A) < unsigned'(CmpPort.B)) ? 1'b1 : 1'b0;
        
        assign Ibs.Shifter.Din = DataPort.rs1;
        assign Ibs.Shifter.Shift = DataPort.rs2[$clog2(XLEN):0];
        assign Ibs.Shifter.opArithmetic = ALUPort.opArithmetic;
        assign Ibs.Shifter.opRightShift = ALUPort.opRightShift;

        if (ALUPort.lopAdd == 1'b1)
            assign ALUPort.rd = DataPort.rs1 + (ALUPort.opArithmetic == 1'b0) ? DataPort.rs2 : - DataPort.rs2;
        else if (ALUPort.lopAND == 1'b1)
            assign ALUPort.rd = DataPort.rs1 & DataPort.rs2;
        else if (ALUPort.lopOR == 1'b1)
            assign ALUPort.rd = DataPort.rs1 | DataPort.rs2;
        else if (ALUPort.lopXOR == 1'b1)
            assign ALUPort.rd = DataPort.rs1 ^ DataPort.rs2;
        else if (ALUPort.lopShift == 1'b1)
            assign ALUPort.rd = Ibs.Shifter.Dout;
    end

    always_ff@(posedge Clk)
    begin

    end;
endmodule