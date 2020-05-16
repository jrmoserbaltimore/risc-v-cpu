// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: RISC-V Pipeline Data
// Module Name: IPipelineData
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: An interface to carry pipeline data
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.2
// Revision 0.2 - Reworked around new data unions
// Revision 0.1 - Changed to IPipelineData interface
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

import Kerberos::*;

interface IPipelineData
#(
    parameter XLEN = 2,
    FetchSize = 32
);
    logic [31:0] insn = '0;
    // Extra data from Fetch, if wide bus.  Append to insn.
    logic [FetchSize-32:0] FetchData = '0;

    // virtually extend misa on access: [XLEN-1:XLEN-2] is mxlen
    misa_t misa;

    logic[xlen2bits(XLEN)-1:0] mstatus = '0;
    bit[1:0] ring = '0;

    let sxl = mstatus[35:34];
    let uxl = mstatus[33:32];
    let mxl = misa.misa.mxl;
    logic[1:0] xlen;
    
    always_comb
    begin
        case (ring)
            0: assign xlen = uxl;
            1: assign xlen = sxl;
            3: assign xlen = mxl;
        endcase
    end

    logic[xlen2bits(XLEN)-1:0] rs1 = '0;
    logic[xlen2bits(XLEN)-1:0] rs2 = '0;
    logic[xlen2bits(XLEN)-1:0] rd = '0;
    // Exec stage cannot Strobe if Ready = 0
    logic Ready = '0;

    // XLEN can only increment/decrement by 2 (4 without RVC)
    logic[xlen2bits(XLEN)-2:0] pc = '0;

    // Decoded information
    decoded_data_t DecodedInstruction;

    modport FetchOut
    (
        output FetchData
    );
    
    modport FetchIn
    (
        input FetchData
    );

    // Used in most stages.  Sends context information forward.
    modport ContextOut
    (
        output insn,
        output mstatus,
        output ring,
        output xlen,
        output pc,
        output misa
    );

    // Provides inputs used for most stages
    // A translation layer (e.g. RVC) is a context in (from Fetch) and a context out
    // (to Decode).
    modport ContextIn
    (
        input insn,
        input mstatus,
        input ring,
        input xlen,
        input pc,
        input misa
    );

    // Decode:  take fetched data, analyze, mark up single-bits signaling what kind
    // of operation to carry out.
    //
    // These are the results
    modport DecodedOut
    (
        output DecodedInstruction
    );

    modport DecodedIn
    (
        input DecodedInstruction
    );

    // Loaded data
    // B and S type instructions use two registers and an immediate, but those instructions
    // are also rigid in their data sources (always two registers and the immediate) and so
    // don't benefit from having these parsed out
    modport LoadedOut
    (
        output rs1,
        output rs2
    );
    
    modport LoadedIn
    (
        input rs1,
        input rs2
    );
endinterface