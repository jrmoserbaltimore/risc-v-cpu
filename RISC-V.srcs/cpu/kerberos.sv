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
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

typedef enum
{
    INFERRED,
    HAN_CARLSON,
    HAN_CARLSON_SPECULATIVE
} adder_type;

typedef enum
{
    DIV_QUICKDIV,
    DIV_PARAVARTYA
} divider_type;

typedef enum
{
    CACHE_NCOR
} cache_type;

// All smaller widths supported implicitly
typedef enum
{
    FPU_NONE,
    FPU_F,
    FPU_D,
    FPU_Q
} fpu_type;

typedef enum
{
    A_NONE,
    A_ATOMIC,
    A_ZAM
} atomic_type;

module KerberosRISCV
#(
    parameter XLEN = 2, // highest supported xlen:  1 = RV32, 2 = RV64, 3 = RV128, 4 = throw
    parameter RVM = 1, // M extension
    parameter RVA = A_ATOMIC, // A extension
    parameter FPU = FPU_D, // FDQ extension
    parameter RVC = 1, // 1 = C extension
    parameter Adder = HAN_CARLSON_SPECULATIVE,
    parameter Divider = DIV_PARAVARTYA,
    parameter Cache = CACHE_NCOR, // Cache type
    parameter L1Cache = 4, // Kilobytes
    parameter L2Cache = 8 // Kilobytes
);
endmodule