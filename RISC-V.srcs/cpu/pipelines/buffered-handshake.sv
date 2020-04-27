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
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

// Within a single module, a pipeline stage applies as such:
//
//  <- | Busy      Busy  | <-
//  -> | Strobe   Strobe | ->
//  -> | Data       Data | ->
//
// If the next (right) module is busy, the current module must send Busy to the
// prior (left) module.  This interface handles that coordination. 
//
interface BufferedHandshake
#(
    parameter type InType, OutType
);

    uwire Clk;
    uwire Rst;

    uwire DReady; // Data is ready
    InType DBuf; // Buffer for when we get data but aren't ready

    uwire rBusy;
    uwire rStrobe;
    InType Din;
    
    uwire sBusy;
    uwire sStrobe;
    OutType Dout;

    // Receiver sets Busy, receives Strobe.
    // Module calls IsReady and, if 1, gets data from DReg.
    modport Receiver
    (
        output rBusy,
        input rStrobe,
        input Din,
        output DReady,
        import function GetData()
    );
    
    // Sender strobes and waits for not-busy.
    modport Sender
    (
        input sBusy,
        output sStrobe,
        output Dout,
        import task Send(OutType Data)
    );
    
    // XXX TODO:  make these work
    // Module should call this when DReady is 1
    function InType GetData();
        return 1'b1;
    endfunction
    
    // Send:  on the next clock, data is on the output bus, Strobe is '1'
    task Send(OutType Data);
        Dout <= Data;
    endtask
   
endinterface
