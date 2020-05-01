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

module FullALU
#(
    XLEN = 32
)
(
    input logic Clk,
    IPipelineData.LoadedIn DataPort,
    IPipelineData.ALU ALUPort
);

    IBarrelShifter #(XLEN) Ibs();
    BarrelShifter #(XLEN) bs(.Shifter(Ibs.Shifter));

    IAdder #(XLEN) IAdd();
    HanCarlsonAdder #(XLEN) HCAdder(.DataPort(IAdd.Adder));
    
    always_ff@(posedge Clk)
    begin
        if (ALUPort.lopAdd == 1'b1)
        begin
            IAdd.A = DataPort.rs1;
            IAdd.B = DataPort.rs2;
            IAdd.Sub = ALUPort.opArithmetic;
            IAdd.Speculate = 1'b1;
            // Ready = (ReadySig & ~IAdd.Error) | Delay;
            // if IAdd.Error & Delay set Delay=0
        end
        else if (ALUPort.lopShift == 1'b1)
        begin
            Ibs.Shifter.Din = DataPort.rs1;
            Ibs.Shifter.Shift = DataPort.rs2[$clog2(XLEN):0];
            Ibs.Shifter.opArithmetic = ALUPort.opArithmetic;
            Ibs.Shifter.opRightShift = ALUPort.opRightShift;
            ALUPort.rd = Ibs.Shifter.Dout;
        end
        // FIXME:  Comparator
        // There are basic gates
        else if (ALUPort.lopAND == 1'b1)
            ALUPort.rd = DataPort.rs1 & DataPort.rs2;
        else if (ALUPort.lopOR == 1'b1)
            ALUPort.rd = DataPort.rs1 | DataPort.rs2;
        else if (ALUPort.lopXOR == 1'b1)
            ALUPort.rd = DataPort.rs1 ^ DataPort.rs2;
        // FIXME:  MUL, DIV
    end;
endmodule
