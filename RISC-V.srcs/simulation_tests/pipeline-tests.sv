// An example handshake module:  addition
module ExampleAdditionHandshake
(
    input uwire Clk,
    input logic [31:0] A,
    input logic [31:0] B,
    output logic [31:0] S,
    ISkidBuffer.ClientIn PipeIn,
    ISkidBuffer.ClientOut PipeOut
);
    logic Processing = 1'b0;
    logic DataReady = 1'b0;
    logic [$size(S)-1:0] OutS;
    bit [4:0] delay = '0;
 
    // Busy if we're processing
    assign PipeIn.Busy = Processing || (DataReady && PipeOut.Busy);

    assign PipeOut.Strobe = DataReady;
    always_ff @(posedge Clk)
    begin
        if (!PipeOut.Busy && DataReady)
        begin
            DataReady <= 1'b0;
        end
        // XXX:  Broken
        if (PipeIn.Strobe && !Processing)
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
            Processing <= 1'b1;
            delay <= 9; // 3 cycle operation
        end
        else if (Processing)
        begin
            // We're busy processing.  Reduce delay by 1; processing is 0 when delay is 0
            if (delay > 0)
            begin
                delay--;
            end
            else
            begin
                // Send output
                S <= OutS;
                Processing <= 1'b0;
                DataReady <= 1'b1;
             end
        end
    end
endmodule