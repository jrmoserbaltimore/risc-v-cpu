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
    realtime ClkDelay = 2.5ns; // 500MHz
    
    IBarrelShifter #(8) Ibs();
    BarrelShifter #(8) bs(.Shifter(Ibs.Shifter));

    IPipelineData #(8) IALU();
    BasicALU #(8) ALU(.Clk(Clk), .DataPort(IALU.LoadedIn), .ALUPort(IALU.ALU));
    DSP48ALU #(8) DSPALU(.Clk(Clk), .DataPort(IALU.LoadedIn), .ALUPort(IALU.ALU));
    FullALU #(8) FullALU(.Clk(Clk), .DataPort(IALU.LoadedIn), .ALUPort(IALU.ALU));
    
    initial
    begin
        Clk = 1'b0;
        IALU.LoadedOut.rs1 = '0;
        IALU.LoadedOut.rs2 = '0;
    end
    always #ClkDelay Clk = ~Clk;

    always@(posedge Clk)
    begin
        if (IALU.DecodedIn.lopAdd == 1'b1)
        begin
            if (IALU.DecodedIn.opArithmetic == 1'b0)
            begin
                // Add -> Sub
                IALU.DecodedOut.opArithmetic = 1'b1;
            end
            else
            begin
                // Sub -> Shift Left Logical
                IALU.DecodedOut.opArithmetic = 1'b0;
                IALU.DecodedOut.lopAdd = 1'b0;
                IALU.DecodedOut.lopShift = 1'b1;
            end
        end
        else if (IALU.DecodedOut.lopShift == 1'b1)
        begin
            if (IALU.DecodedOut.opRightShift == 1'b0)
            begin
                // SLL -> Shift Right Logical
                IALU.DecodedOut.opRightShift = 1'b1;
            end
            else if (IALU.DecodedOut.opArithmetic == 1'b0)
            begin
                // SRL -> Shift Right Arithmetic 
                IALU.DecodedOut.opArithmetic = 1'b1;
            end
            else
            begin
                // AND
                IALU.DecodedOut.opArithmetic = 1'b0;
                IALU.DecodedOut.opArithmetic = 1'b0;
                IALU.DecodedOut.lopShift = 1'b0;
                IALU.DecodedOut.lopAND = 1'b1;
            end
        end
        else if (IALU.DecodedOut.lopAND == 1'b1)
        begin
            IALU.DecodedOut.lopAND = 1'b0;
            IALU.DecodedOut.lopOR = 1'b1;
        end
        else if (IALU.DecodedOut.lopOR == 1'b1)
        begin
            IALU.DecodedOut.lopOR = 1'b0;
            IALU.DecodedOut.lopXOR = 1'b1;
        end
        else
        begin
            // By default, start with Add
            IALU.DecodedOut.lopAdd = 1'b1;
            // Clear everything else
            IALU.DecodedOut.opArithmetic = 1'b0;
            IALU.DecodedOut.opRightShift = 1'b0;
            IALU.DecodedOut.lopShift = 1'b0;
            IALU.DecodedOut.lopAND = 1'b0;
            IALU.DecodedOut.lopOR = 1'b0;
        end
        IALU.LoadedOut.rs1 = 8'b10110101;
        IALU.LoadedOut.rs2 = 8'b00000011;
        
        assign Ibs.Shifter.Din = IALU.LoadedIn.rs1; //8'b10110101;
        assign Ibs.Shifter.Shift = IALU.LoadedIn.rs2[$clog2(8):0]; //4'b0011;
        assign Ibs.Shifter.opArithmetic = IALU.DecodedIn.opArithmetic;
        assign Ibs.Shifter.opRightShift = IALU.DecodedIn.opRightShift;
    end
    
    
//    always_ff@(posedge Clk)
//    begin
//
//    end
    
endmodule