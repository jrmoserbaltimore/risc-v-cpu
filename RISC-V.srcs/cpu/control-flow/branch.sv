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
// This relies on an ALU providing add and compare.  Full ALUs provide compare as
// a separate function in parallel, so a single ALU execution unit can implement
// branching.
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire