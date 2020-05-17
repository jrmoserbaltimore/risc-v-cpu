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
    
    IBarrelShifter #(1) Ibs();
    BarrelShifter #(1) bs(.Shifter(Ibs.Shifter));

    IALU #(1) ALUPort();
    BasicALU #(1) ALU(.Clk(Clk), .ALUPort(ALUPort.ALU));
    DSP48ALU #(1) DSPALU(.Clk(Clk), .ALUPort(ALUPort.ALU));
    FullALU #(1) FullALU(.Clk(Clk), .ALUPort(ALUPort.ALU));

    // Pipeline tests.  Direct manipulation of the handshake.
    logic [31:0] PTA = '0;
    logic [31:0] PTB = '0;
    logic [31:0] PTS;

    // Input (ISB.Out) -SBC-> (ISB.In) EAD (ISBR.Out) -SBCR-> (ISBR.In)
    ISkidBuffer #(.BufferSize($size(PTA) + $size(PTB))) ISB();
    ISkidBuffer #(.BufferSize($size(PTA) + $size(PTB))) ISBR();
    
    SkidBuffer #(.BufferSize($size(PTA) + $size(PTB)))
            SBC(.Clk(Clk), .In(ISB.In), .Out(ISB.Out), .DataPort(ISB.DataPort));

    SkidBuffer #(.BufferSize($size(PTA) + $size(PTB)))
            SBO(.Clk(Clk), .In(ISBR.In), .Out(ISBR.Out), .DataPort(ISBR.DataPort));

    // ISB.Receiver Data -> Ar/Br    
    assign ISB.Din = {PTA,PTB};
    uwire [$size(PTA)-1:0] Ar = ISB.DataPort.rDin[($size(PTA) + $size(PTB))-1:$size(PTB)];
    uwire [$size(PTB)-1:0] Br = ISB.DataPort.rDin[$size(PTB)-1:0];

    uwire EABusy;
    assign EABusy = ISB.ClientOut.Busy;
    ExampleAdditionHandshake EAD(.Clk(Clk), .A(Ar), .B(Br), .S(PTS), .PipeIn(ISB.ClientIn), .PipeOut(ISBR.ClientOut));
    // Setup

    logic HSStrobe = '0;
    logic HSBusy = '0;
    logic HSWait = '0;
    logic [$size(PTA)-1:0] HSResult = '0;
    assign ISB.ClientOut.Strobe = HSStrobe;
    assign ISBR.ClientIn.Busy = (EABusy || HSBusy) ? 1'b1 : 1'b0;
    initial
    begin
        Clk = 1'b0;
        ALUPort.Client.rs1 = '0;
        ALUPort.Client.rs2 = '0;
    end
    always #ClkDelay Clk = ~Clk;

    bit [2:0] delayPipe = 5;
    always_ff@(posedge Clk)
    begin
        if (delayPipe == 0)
        begin
            // Increment and strobe immediately
            PTA <= PTA + 1;
            HSStrobe <= 1'b1;
            delayPipe = 1;
            HSBusy <= 1'b1;
        end
        else if (!EABusy)
        begin
            HSStrobe <= 1'b0;
            HSBusy <= 1'b0;
            // Decrement only when this happens
            delayPipe--;
        end
        
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
        // FIXME:  32 bits now
        ALUPort.Client.rs1 = 8'b10110101;
        ALUPort.Client.rs2 = 8'b00000011;
        
        Ibs.Shifter.Din = ALUPort.ALU.rs1; //8'b10110101;
        Ibs.Shifter.Shift = ALUPort.ALU.rs2[$clog2(xlenbits):0]; //4'b0011;
        Ibs.Shifter.opArithmetic = ALUPort.ALU.opArithmetic;
        Ibs.Shifter.opRightShift = ALUPort.ALU.opRightShift;
    end
endmodule