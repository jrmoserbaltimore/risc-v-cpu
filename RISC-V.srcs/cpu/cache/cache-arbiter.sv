// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 05/16/2020
// Design Name: Cache Arbiter
// Module Name: CacheArbiter
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A Cache arbiter
// 
// Dependencies:  L1 to L2 arbiter, TLB, etc.
// 
// License:  MIT, 7-year CC0
// 
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

import Kerberos::*;

interface ICacheArbiter
#(
    parameter XLEN = 2 // word size
);
    logic [xlen2bits(XLEN)-1:0] Address;
    logic [xlen2bits(XLEN)-1:0] Data;
    modport Cache
    (
        input Address,
        output Data
    );
    
    modport Client
    (
        input Data,
        output Address
    );
endinterface


module CacheArbiter
#(
    parameter XLEN = 2 //Cacheline size
// FIXME:  Cacheline size?  L1 size?
)
(
    ICacheArbiter.Cache Client
);

    // FIXME:  Placeholder
    assign Client.Data = '0;
endmodule