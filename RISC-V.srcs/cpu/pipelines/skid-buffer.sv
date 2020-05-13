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
    
    modport In
    (
        input .Strobe(sStrobe),
        output .Busy(sBusy)
    );
    
    modport Out
    (
        input .Busy(rBusy),
        output .Strobe(rStrobe)
    );
    
    modport DataPort
    (
        input Din,
        output rDin
    );
endinterface

// Connects between components
module SkidBuffer
#(
    parameter BufferSize = 32 // MUST be set
)
(
    input uwire Clk,
    ISkidBuffer.In In,
    ISkidBuffer.Out Out,
    ISkidBuffer.DataPort DataPort
);
    // Is there register data?
    logic Rstore = 1'b0;
    logic [BufferSize-1:0] Rbuf;

    // We're not busy if there's nothing in the register.
    assign In.Busy = Rstore;

    always @(posedge Clk)
    begin
        if (!Rstore)
            Rbuf <= DataPort.Din;
    end
    
    logic Reset = 1'b1;
    always @(posedge Clk)
    begin
        if (Reset)
        begin
            Reset <= 1'b0;
            Out.Strobe <= 1'b0;
            Rstore <= 1'b0;
        end
        else if (!Out.Busy)
        begin
            // Next stage is not busy and is ready for data
            if (!Rstore)
            begin
                // Bypass the buffer and strobe
                DataPort.rDin <= DataPort.Din;
                Out.Strobe <= In.Strobe;
            end
            else
            begin
                // We have data in the buffer, flush to the client
                DataPort.rDin <= Rbuf;
                Out.Strobe <= 1'b1;
            end
            // Register is empty in either case.  If we're still busy we can bank new data.
            Rstore <= 1'b0;
        end
        else if (!In.Strobe)
        begin
            // No data payload at all:  Not busy and not sending
            Out.Strobe <= In.Strobe;
            Rstore <= 1'b0; // Redundant?
            // Out.Busy <= 1'b1; // This is always Rstore

        end
        else if (In.Strobe && !In.Busy)
        begin
            // We're busy, not signaling busy, and we received a strobe.
            // Bank to register.
            Rstore <= Out.Strobe && In.Strobe;
        end
    end
    
    `ifdef FORMAL
    // Formal verification

    // Rstore is equivalent to In.Busy.  Using different names for clarity.
    //
    // All combinations of In.Strobe and Rstore (synonymous with Out.Busy) are valid; only certain
    // states following these are valid, based on Out.Busy.
    //
    // (!In.Strobe && Rstore) occurs after the skid buffer buffers data from In when In has no
    // further data
    //
    // (!Rstore && In.Strobe) is just pass-through or entering buffer.
    //
    // (Rstore && In.Strobe) is In waiting for the skid buffer to not be busy.
    //
    // (!Rstore && !In.Strobe) is idle, sitting in passthrough.

    // Assumptions about caller (the output circuit can become busy whenever the hell it wants)
    // Caller will hold strobe and data until !In.Busy
    property FV_ASSUME_CALLER_STROBE_WAITS;
        In.Strobe && In.Busy |=> In.Strobe && (Din == $past(Din)); 
    endproperty

    // Valid state changes

    // A reset (or pipeline flush) must clear the buffer and outgoing strobe.
    // Buffer and output data don't matter
    property FV_RESET_CLEARS_STATE;
        @(posedge Clk) Reset |=> !Reset && !Rstore && !Out.Strobe;
    endproperty

    // Rbuf should always be stable when storing a buffer    
    property FV_BUFFER_IS_STABLE;
        @(posedge Clk) Rstore |=> $stable(Rbuf);
    endproperty

    // Store data from In if not already storing data
    property FV_BUFFER_SAVES_INPUT;
        @posedge(Clk) disable iff (Rstore)
          !Rstore |=> Rbuf == DataPort.Din;
    endproperty

    // flush or pass becomes pass
    property FV_FLUSH_OR_PASS_TO_PASS;
        @posedge(Clk)
          !Rstore && (!In.Strobe || !Out.Busy) |=> !Rstore && (Out.Strobe == In.Strobe) && (rDin == Din);
    endproperty

    // pass becomes buf.
    //property FV_PASS_TO_BUF;
    property FV_PASS_BUF_OR_FLUSH_TO_BUF;
        // This matches both Flush->Buf and Pass->Buf
        //@posedge(Clk)
        //  !Rstore && In.Strobe && Out.Busy |=> Rstore && (Out.Strobe == In.Strobe) && (rDin == Din);

        // This matches Buf->Buf
        //@posedge(Clk)
        //  Rstore && Out.Busy |=> Rstore && (Out.Strobe == In.Strobe) && (rDin == Din);

        // XXX:  Is Rstore or In.Busy more elucidating here?
        @posedge(Clk)
          Out.Busy && (In.Strobe || Rstore) |=> Rstore && (Out.Strobe == In.Strobe) && (rDin == Din);
    endproperty
    
    // There is only one state change to reach here
    property FV_BUF_OR_FLUSH_TO_FLUSH;
        @posedge(Clk)
            // Buf->Flush
            (!Out.Busy && Rstore)
            // Flush state -> Buf
            // From Pass, if In.Strobe && !Out.Busy followed by !In.Strobe && Out.Busy, In.Busy (Rstore)
            // will be 0, Out.Strobe will be 0, and rDin will be Din
            || (!In.Strobe && Out.Busy && !Rstore && Out.Strobe == 1'b1 && rDin == Rbuf)
          |=> !Rstore && (Out.Strobe == 1'b1) && (rDin == Rbuf);
    endproperty

    assume property FV_ASSUME_CALLER_STROBE_WAITS;

    assert property FV_RESET_CLEARS_STATE;
    assert property FV_BUFFER_IS_STABLE;
    assert property FV_BUFFER_SAVES_INPUT;
    assert property FV_FLUSH_OR_PASS_TO_PASS;
    assert property FV_PASS_BUF_OR_FLUSH_TO_BUF;
    assert property FV_BUF_OR_FLUSH_TO_FLUSH;
    `endif
endmodule
