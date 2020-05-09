// An example handshake module:  addition
module ExampleAdditionHandshake
(
    input logic Clk,
    input logic [31:0] A,
    input logic [31:0] B,
    output logic [31:0] S,
    IBufferedHandshake.Receiver Receiver,
    IBufferedHandshake.Sender Sender  
);
    logic dataReady = 1'b0;
    IBufferedHandshakeController #(.BufferSize($size(A) + $size(B))) IBHC();
    BufferedHandshake #(.BufferSize($size(A) + $size(B)))
            BH(.Clk(Clk), .Receiver(Receiver), .Sender(Sender), .Client(IBHC.Server));
    
    assign IBHC.Client.Din = {A,B};
    assign IBHC.Client.dataReady = dataReady;
    
    uwire Ar = IBHC.DinR[($size(A) + $size(B))-1:$size(B)];
    uwire Br = IBHC.DinR[$size(B)-1:0];
    
    logic Processing = 1'b0;
    always_ff @(posedge Clk)
    begin
        if (IBHC.Client.R)
        begin
            // If this is a multi-cycle instruction, it must set
            // dataReady <= 0 here.  If it is a potential multi-cycle instruction,
            // it must set dataReady <= 1 if it finishes in 1 cycle, and 0 if it
            // must delay
            
            // Put the data on the output
            S <= Ar + Br;
            // Signal that processing is complete.
            // This should have the same effect as just setting Sender.Strobe
            // and clearing Receiver.Busy in this block; we let BH handle that part
            dataReady <= 1'b0;
        end
        else if (dataReady == 1'b0 && Processing == 1'b1)
        begin
            // The pipeline ignores this if not processing
            dataReady <= 1'b1;
            Processing <= 1'b0;
        end
        else if (Processing == 1'b0)
        begin
            dataReady <= 1'b0;
        end
        
        // output and dataReady just sit until R is active again.  BH knows it hasn't
        // requested anything and that it has strobed and been accepted.
    end
endmodule