// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 05/05/2020
// Design Name: Kerberos CPU setup
// Module Name: KerberosRISCV
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: Configuration for the Kerberos CPU
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

import Kerberos::*;

module KerberosRISCV
#(
    parameter XLEN = 2, // highest supported xlen:  1 = RV32, 2 = RV64, 3 = RV128, 4 = throw
    parameter RVM = 1, // M extension
    parameter RVA = A_ATOMIC, // A extension
    parameter FPU = FPU_D, // FDQ extension
    parameter RVC = 1, // 1 = C extension
    parameter ALU = ALU_BASIC,
    parameter Adder = ADD_HAN_CARLSON_SPECULATIVE,
    parameter Divider = DIV_PARAVARTYA,
    parameter Cache = CACHE_NCOR, // Cache type
    parameter D1Index = CACHE_VIVT,
    parameter I1Index = CACHE_VIVT,
    parameter L1Cache = 4, // Kilobytes
    parameter L2Cache = 8 // Kilobytes
)
(
    input uwire Clk,
    input uwire Reset,
    output logic ClkOut
);

    // FIXME:  Placeholder to get synthesizer to check stuff
    IPipelineData #(.XLEN(XLEN)) PData();
    //instruction_t insn;
    decode_data_t decoded;
    logic decoderSel;

    RVDecoder Decoder(.ContextIn(PData.ContextIn), .DecodedOut(decoded), .Sel(decoderSel));
endmodule