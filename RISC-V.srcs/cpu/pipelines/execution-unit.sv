// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 05/02/2020
// Design Name: Branch Control
// Module Name: ControlBranch
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A branching and control transfer function
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:
// 
// Use paravartya or quick-div for a divider separate from the ALU.  The FPGA DSP
// does not provide one.
//
// Divider obtains and caches the remainder and product to catch the RISC-V M
// specified sequence:
//
//   DIV[U] rdq, rs1, rs2
//   REM[U] rdq, rs1, rs2
//
// This sequence is fused together into a single divide.
//
// Paravartya uses the barrel shifter for one cycle, and otherwise requires its own
// internal specialized adders and single-AND multipliers, as individual bits are
// signed.
//
// Quick-Div uses the barrel shifter and adder for repeat subtraction.  It might
// provide better fMax than Paravartya and, in such a case, would be better in
// execution units which cannot carry out multiple operations in the same cycle. 
//
// A stripped ALU may provide an adder (branch), barrel shifter (divider), and
// multiplier to get these out of the IPS critical path for single execution units
// computing multiple instructions in parallel.  For multiple parallel full
// execution units, providing add, cmp, and shift supports add/sub, branch, shift,
// load/store, and SLT.  Further, while a multiplier ties up the ALU for several
// cycles, a divider only uses the ALU once for shift:  multiple dividers embedded
// into a single execution unit accelerates integer-division-heavy code paths when
// divisions are independent.
////////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire
