// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/26/2020
// Design Name: Buffered Handshake
// Module Name:
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A buffered pipeline handshake
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.01
// Revision 0.1 - Filled out 
// Revision 0.01 - File Created
// Additional Comments:
//
// Within a single module, a pipeline stage applies as such:
//
//  <- | Busy      Busy  | <-
//  -> | Strobe   Strobe | ->
//  -> | Data       Data | ->
//
// If the next (right) module is busy, the current module must send Busy to the
// prior (left) module.  This interface handles that coordination.
//
// This module provides a simplified interface:
//
//   - The client (pipeline stage, etc.) indicates processing (busy) and data ready
//     (strobe)
//   - The handshake module indicates data to process (strobe) when both the client
//     is not processing (busy) and the circuit to the right has received the data
//   - The client resets itself (removes data ready) on any cycle in which the
//     handshake module indicates data to process (strobe)
//
// This interface looks like this:
//
//  Client        Handshake
//     Run | <- |
//   Input | <- |
//  Strobe | -> |
//    Data | -> |
//
// The handshake module handles communication with the left and right module.  It
// signals the client is busy, buffers data when there is strobe on a cycle wherein
// it BECOMES busy, directs input or the buffer to the client as appropriate, and
// stops the strobe to the next module when the client's data has been accepted.
//
// This abstracts the details of the pipeline itself.  The client only knows two
// things:  "Run" and "I'm done."  A Strobe from the client indicates it is no
// longer busy, and the handshake module waits until the data has been sent before
// changing the input and triggering the client to run.
//
// Keep in mind the "Data" output is implicit:  the client places data directly on
// the output bus.
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

// This goes across two components
interface IBufferedHandshake;
    uwire Busy;
    uwire Strobe;

    modport Receiver
    (
        input Strobe,
        output Busy
    );
    
    modport Sender
    (
        input Busy,
        output Strobe
    );
endinterface

interface IBufferedHandshakeController
#(
    parameter BufferSize = 32 // MUST be set
);
    // Data processing and such
    uwire dataReady; // Client has data ready to go
    uwire R; // Reset and process data
    uwire [BufferSize-1:0] Din;
    uwire [BufferSize-1:0] DinR;

    modport Client
    (
        input R,
        input DinR, // use this as logic circuit data input
        output Din, // Send data in to handshake
        output dataReady
    );
    
    modport Server
    (
        input Din,
        input dataReady,
        output R,
        output DinR
    );
endinterface
// Inside a component, the receiver end and sender end of two different
// buffered handshake interfaces are connected to this for coordination
module BufferedHandshake
#(
    parameter BufferSize = 32 // MUST be set
)
(
    input uwire Clk,
    IBufferedHandshake.Receiver Receiver,
    IBufferedHandshake.Sender Sender,
    IBufferedHandshakeController.Server Client
);
    logic Processing = 1'b0;
    // Is there register data?
    logic Rstore = 1'b0;
    logic [BufferSize-1:0] Rbuf;

    // If 1, use register buffer
    logic oRstore = 1'b0;
    assign Client.DinR = (oRstore) ? Rbuf : Client.Din;
    
    logic oRun = 1'b0;
    assign Client.R = oRun;
    
    logic isBusy = 1'b0;
    assign Receiver.Busy = isBusy;
    
    logic sStrobe = 1'b0;
    assign Sender.Strobe = Client.dataReady & Processing;
    //assign R = !Processing & Receiver.Strobe; // ?

    // There is no clock delay between the caller and the handshake module.
    // iStrobe and oBusy appear here on the same cycle they appear on the
    // caller and are not latched by this modle.
    always @(posedge Clk)
    begin
        if (!Processing)
        begin
            // If we're not busy, we can take data
            if (Rstore)
            begin
                // We have data in the buffer, so give it to the client
                oRstore <= 1'b1;
                oRun <= 1'b1; // Client.R <= R & ~Processing combinationally?
            end
            else
            begin
                oRstore <= 1'b0; // Direct data input
                // Tell the client to process this cycle
                // Client needs to read R=1 on the cycle that we receive Strobe.
                // On the immediate following cycle, Client must read R=0
                oRun <= Receiver.Strobe;
            end
            // Also assign our busy.  Assume we'll be free next clock, one-cycle process.
            isBusy <= 1'b0;
            // Register is empty in either case.  If we're still busy we can bank new data.
            Rstore <= 1'b0;
            Processing <= Receiver.Strobe; // We're processing if we trigger R
        end
        else if (!Sender.Strobe)
        begin
            // We're processing and not sending a data strobe.  Strobe only if we're both
            // processing (redundant) and the output is ready.
            sStrobe <= Client.dataReady;
            // We're busy if:
            //  - We're processing (established)
            //  - Either the data isn't ready OR the next stage is busy
            isBusy <= !Client.dataReady || Sender.Busy;
            // Data is ready, we're strobing, and the sender isn't busy.  Done.
            Processing <= Client.dataReady && !Sender.Busy;
        end
        else if ((!Receiver.Busy) && (Receiver.Strobe))
        begin
            // We're processing, not signaling busy, and we received a strobe.
            // Bank to register.
            Rstore <= 1'b0;
            Rbuf <= Client.Din;
        end
    end
endmodule

