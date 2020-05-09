// vim: sw=4 ts=4 et
`timescale 1ns / 100ps
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

    IALU #(8) ALUPort();
    BasicALU #(8) ALU(.Clk(Clk), .ALUPort(ALUPort.ALU));
    DSP48ALU #(8) DSPALU(.Clk(Clk), .ALUPort(ALUPort.ALU));
    FullALU #(8) FullALU(.Clk(Clk), .ALUPort(ALUPort.ALU));

    // Pipeline tests.  Direct manipulation of the handshake.
    logic [31:0] PTA = '0;
    logic [31:0] PTB = '0;
    logic [31:0] PTS;
    IBufferedHandshake IBHR(); // We're the receiver here
    IBufferedHandshake IBHS(); // We're the sender here
    ExampleAdditionHandshake EAD(.Clk(Clk), .A(PTA), .B(PTB), .S(PTS), .Receiver(IBHS.Receiver), .Sender(IBHR.Sender));
    // Setup

    logic HSStrobe = '0;
    assign IBHS.Sender.Strobe = HSStrobe;

    logic sBusy = '0;
    assign IBHR.Receiver.Busy = sBusy;

    initial
    begin
        Clk = 1'b0;
        ALUPort.Client.rs1 = '0;
        ALUPort.Client.rs2 = '0;
    end
    always #ClkDelay Clk = ~Clk;

    always_ff@(posedge Clk)
    begin
        PTA <= PTA + 1;
        HSStrobe <= ~HSStrobe && ~IBHS.Sender.Busy;
        
        if (ALUPort.ALU.lopAdd == 1'b1)
        begin
            if (ALUPort.ALU.opArithmetic == 1'b0)
            begin
                // Add -> Sub
                ALUPort.Client.opArithmetic = 1'b1;
            end
            else
            begin
                // Sub -> Shift Left Logical
                ALUPort.Client.opArithmetic = 1'b0;
                ALUPort.Client.lopAdd = 1'b0;
                ALUPort.Client.lopShift = 1'b1;
            end
        end
        else if (ALUPort.ALU.lopShift == 1'b1)
        begin
            if (ALUPort.ALU.opRightShift == 1'b0)
            begin
                // SLL -> Shift Right Logical
                ALUPort.Client.opRightShift = 1'b1;
            end
            else if (ALUPort.ALU.opArithmetic == 1'b0)
            begin
                // SRL -> Shift Right Arithmetic 
                ALUPort.Client.opArithmetic = 1'b1;
            end
            else
            begin
                // AND
                ALUPort.Client.opArithmetic = 1'b0;
                ALUPort.Client.opArithmetic = 1'b0;
                ALUPort.Client.lopShift = 1'b0;
                ALUPort.Client.lopAND = 1'b1;
            end
        end
        else if (ALUPort.ALU.lopAND == 1'b1)
        begin
            ALUPort.Client.lopAND = 1'b0;
            ALUPort.Client.lopOR = 1'b1;
        end
        else if (ALUPort.ALU.lopOR == 1'b1)
        begin
            ALUPort.Client.lopOR = 1'b0;
            ALUPort.Client.lopXOR = 1'b1;
        end
        else
        begin
            // By default, start with Add
            ALUPort.Client.lopAdd = 1'b1;
            // Clear everything else
            ALUPort.Client.opArithmetic = 1'b0;
            ALUPort.Client.opRightShift = 1'b0;
            ALUPort.Client.lopShift = 1'b0;
            ALUPort.Client.lopAND = 1'b0;
            ALUPort.Client.lopOR = 1'b0;
        end
        ALUPort.Client.rs1 = 8'b10110101;
        ALUPort.Client.rs2 = 8'b00000011;
        
        Ibs.Shifter.Din = ALUPort.ALU.rs1; //8'b10110101;
        Ibs.Shifter.Shift = ALUPort.ALU.rs2[$clog2(8):0]; //4'b0011;
        Ibs.Shifter.opArithmetic = ALUPort.ALU.opArithmetic;
        Ibs.Shifter.opRightShift = ALUPort.ALU.opRightShift;
    end
endmodule