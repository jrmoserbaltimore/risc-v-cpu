// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: DSP48 Arithmetic Logic Unit
// Module Name: DSP48ALU
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: An ALU directly leveraging the Xilinx DSP48, as in the iDEA CPU
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:
// 
// This ALU is based on lessons from the iDEA CPU leveraging the DSP48E1 as an ALU.
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

module DSP48ALU
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

    always_ff@(posedge Clk)
    begin
        if (ALUPort.lopAdd == 1'b1 && ALUPort.opArithmetic == 1'b0)
            // FIXME:  DSP48E1 adder-subtractor
            assign ALUPort.rd = DataPort.rs1 + DataPort.rs2;
        else if (ALUPort.lopAdd == 1'b1 && ALUPort.opArithmetic == 1'b1)
            // FIXME:  Remove in favor of adder-subtractor
            assign ALUPort.rd = DataPort.rs1 - DataPort.rs2;
        else if (ALUPort.lopShift == 1'b1)
        begin
            // The DSP48E1 doesn't have a barrel shifter
            assign Ibs.Shifter.Din = DataPort.rs1;
            assign Ibs.Shifter.Shift = DataPort.rs2[$clog2(XLEN):0];
            assign Ibs.Shifter.opArithmetic = ALUPort.opArithmetic;
            assign Ibs.Shifter.opRightShift = ALUPort.opRightShift;
            assign ALUPort.rd = Ibs.Shifter.Dout;
        end
        // FIXME:  Comparator
        // There are basic logic, but the DSP48 can accept these too
        else if (ALUPort.lopAND == 1'b1)
            assign ALUPort.rd = DataPort.rs1 & DataPort.rs2;
        else if (ALUPort.lopOR == 1'b1)
            assign ALUPort.rd = DataPort.rs1 | DataPort.rs2;
        else if (ALUPort.lopXOR == 1'b1)
            assign ALUPort.rd = DataPort.rs1 ^ DataPort.rs2;
        // FIXME:  MUL via DSP48E1, DIV via Quick-Div or Paravartya
    end;
endmodule