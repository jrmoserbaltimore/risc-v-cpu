// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/26/2020
// Design Name: Skid Buffer Handshake
// Module Name: SkidBuffer
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
interface ISkidBuffer
#(
    parameter BufferSize = 32 // MUST be set
);
    logic sBusy;
    uwire sStrobe;
    uwire rBusy;
    logic rStrobe;

    // Data processing and such
    uwire [BufferSize-1:0] Din;
    logic [BufferSize-1:0] rDin;
    
    modport Sender
    (
        input Din,
        input .Strobe(sStrobe),
        output .Busy(sBusy)
    );
    
    modport Receiver
    (
        input .Busy(rBusy),
        output .Strobe(rStrobe),
        output .Din(rDin)
    );
endinterface

// Connects between components
module SkidBuffer
#(
    parameter BufferSize = 32 // MUST be set
)
(
    input uwire Clk,
    ISkidBuffer.Receiver Receiver,
    ISkidBuffer.Sender Sender
);
    logic Processing = 1'b0;
    // Is there register data?
    logic Rstore = 1'b0;
    logic [BufferSize-1:0] Rbuf;

    // We're not busy if there's nothing in the register.
    assign Sender.Busy = Rstore;


    always @(posedge Clk)
    begin
        if (!Rstore)
            Rbuf <= Sender.Din;
    end
    
    logic Reset = 1'b1;
    always @(posedge Clk)
    begin
        if (Reset)
        begin
            Reset <= 1'b0;
            Sender.Busy <= 1'b0;
            Rstore <= 1'b0;
        end
        else if (!Receiver.Busy)
        begin
            // Next stage is not busy and is ready for data
            if (!Rstore)
            begin
                // Bypass the buffer and strobe
                Receiver.Din <= Sender.Din;
                Receiver.Strobe <= Sender.Strobe;
            end
            else
            begin
                // We have data in the buffer, flush to the client
                Receiver.Din <= Rbuf;
                Receiver.Strobe <= 1'b1;
            end
            // Register is empty in either case.  If we're still busy we can bank new data.
            Rstore <= 1'b0;
        end
        else if (!Receiver.Strobe)
        begin
            // No data payload at all:  Not busy and not sending
            Receiver.Strobe <= Sender.Strobe;
            Rstore <= 1'b0; // Redundant?
            // Sender.Busy <= 1'b1; // This is always ~Rstore

        end
        else if ((Sender.Strobe) && (!Sender.Busy))
        begin
            // We're busy, not signaling busy, and we received a strobe.
            // Bank to register.
            Rstore <= Sender.Strobe && Receiver.Strobe;
        end
    end
endmodule

