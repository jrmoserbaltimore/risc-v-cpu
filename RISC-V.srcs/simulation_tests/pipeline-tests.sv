// An example handshake module:  addition
module ExampleAdditionHandshake
(
    input uwire Clk,
    input logic [31:0] A,
    input logic [31:0] B,
    output logic [31:0] S,
    ISkidBuffer.Receiver Receiver
);
    logic [1:0] Processing = 2'b0;
    logic [$size(S)-1:0] OutS;
    assign Receiver.Busy = (Processing == 0) ? 1'b0 : 1'b1;
    always_ff @(posedge Clk)
    begin
        if (Receiver.Strobe && !Receiver.Busy)
        begin
            // If this is a multi-cycle instruction, it must set
            // dataReady <= 0 here.  If it is a potential multi-cycle instruction,
            // it must set dataReady <= 1 if it finishes in 1 cycle, and 0 if it
            // must delay
            
            // Put the data on the output
            OutS <= A + B;
            // Signal that processing is complete.
            // This should have the same effect as just setting Sender.Strobe
            // and clearing Receiver.Busy in this block; we let BH handle that part
            Processing <= 2;
        end
        else if (Processing)
        begin
            Processing <= Processing - 1;
            S <= OutS;
        end
        // output and dataReady just sit until R is active again.  BH knows it hasn't
        // requested anything and that it has strobed and been accepted.
    end
endmodule