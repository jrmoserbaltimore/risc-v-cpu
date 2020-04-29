// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/27/2020
// Design Name: RISC-V Decoder
// Module Name: RVDecoder
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A RISC-V Decoder
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.1
// Revision 0.1 - Changed to IPipelineData interface
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

module RVDecoder
(
    logic Clk,
    IPipelineData.Decoder DecoderPort,
    logic Sel
);

    DecoderPort RVIPort();
    DecoderPort RVMPort();

    RVIDecoderTable RVIDec(.DecoderPort(RVIPort));
    RVMDecoderTable RVMDec(.DecoderPort(RVMPort));

    always_ff@(posedge Clk)
    begin
        if (RVIDec.Sel == 1'b1)
        begin
            DecoderPort.lopAdd = RVIPort.lopAdd;
            DecoderPort.lopShift = RVIPort.lopShift;
            DecoderPort.lopCmp = RVIPort.lopCmp;
            DecoderPort.lopAND = RVIPort.lopAND;
            DecoderPort.lopOR = RVIPort.lopOR;
            DecoderPort.lopXOR = RVIPort.lopXOR;
            DecoderPort.lopMUL = RVIPort.lopMUL;
            DecoderPort.lopDIV = RVIPort.lopDIV;
            DecoderPort.lopLoad = RVIPort.lopLoad;
            DecoderPort.lopStore = RVIPort.lopStore;
            DecoderPort.lopIllegal = RVIPort.lopIllegal;
            
            DecoderPort.opB = RVIPort.opB;
            DecoderPort.opH = RVIPort.opH;
            DecoderPort.opW = RVIPort.opW;
            DecoderPort.opD = RVIPort.opD;
            DecoderPort.opUnsigned = RVIPort.opUnsigned;
            DecoderPort.opArithmetic = RVIPort.opArithmetic;
            DecoderPort.opRightShift = RVIPort.opRightShift;
            DecoderPort.opHSU = RVIPort.opHSU;
            DecoderPort.opRemainder = RVIPort.opRemainder;
    
            DecoderPort.lrR = RVIPort.lrR;
            DecoderPort.lrI = RVIPort.lrI;
            DecoderPort.lrS = RVIPort.lrS;
            DecoderPort.lrB = RVIPort.lrB;
            DecoderPort.lrU = RVIPort.lrU;
            DecoderPort.lrJ = RVIPort.lrJ;
        end
        else if (RVMPort.Sel == 1'b1)
        begin
            DecoderPort.lopAdd = RVMPort.lopAdd;
            DecoderPort.lopShift = RVMPort.lopShift;
            DecoderPort.lopCmp = RVMPort.lopCmp;
            DecoderPort.lopAND = RVMPort.lopAND;
            DecoderPort.lopOR = RVMPort.lopOR;
            DecoderPort.lopXOR = RVMPort.lopXOR;
            DecoderPort.lopMUL = RVMPort.lopMUL;
            DecoderPort.lopDIV = RVMPort.lopDIV;
            DecoderPort.lopLoad = RVMPort.lopLoad;
            DecoderPort.lopStore = RVMPort.lopStore;
            DecoderPort.lopIllegal = RVMPort.lopIllegal;
            
            DecoderPort.opB = RVMPort.opB;
            DecoderPort.opH = RVMPort.opH;
            DecoderPort.opW = RVMPort.opW;
            DecoderPort.opD = RVMPort.opD;
            DecoderPort.opUnsigned = RVMPort.opUnsigned;
            DecoderPort.opArithmetic = RVMPort.opArithmetic;
            DecoderPort.opRightShift = RVMPort.opRightShift;
            DecoderPort.opHSU = RVMPort.opHSU;
            DecoderPort.opRemainder = RVMPort.opRemainder;
    
            DecoderPort.lrR = RVMPort.lrR;
            DecoderPort.lrI = RVMPort.lrI;
            DecoderPort.lrS = RVMPort.lrS;
            DecoderPort.lrB = RVMPort.lrB;
            DecoderPort.lrU = BranchPort.lrU;
            DecoderPort.lrJ = BranchPort.lrJ;
        end
        else
        begin
            // Clear state
            DecoderPort.lopAdd = 1'b0;
            DecoderPort.lopShift = 1'b0;
            DecoderPort.lopCmp = 1'b0;
            DecoderPort.lopAND = 1'b0;
            DecoderPort.lopOR = 1'b0;
            DecoderPort.lopXOR = 1'b0;
            DecoderPort.lopMUL = 1'b0;
            DecoderPort.lopDIV = 1'b0;
            DecoderPort.lopLoad = 1'b0;
            DecoderPort.lopStore = 1'b0;
            DecoderPort.lopIllegal = 1'b0;
            
            DecoderPort.opB = 1'b0;
            DecoderPort.opH = 1'b0;
            DecoderPort.opW = 1'b0;
            DecoderPort.opD = 1'b0;
            DecoderPort.opUnsigned = 1'b0;
            DecoderPort.opArithmetic = 1'b0;
            DecoderPort.opRightShift = 1'b0;
            DecoderPort.opHSU = 1'b0;
            DecoderPort.opRemainder = 1'b0;
    
            DecoderPort.lrR = 1'b0;
            DecoderPort.lrI = 1'b0;
            DecoderPort.lrS = 1'b0;
            DecoderPort.lrB = 1'b0;
            DecoderPort.lrU = 1'b0;
            DecoderPort.lrJ = 1'b0;
            // Illegal…instruction?  No you're not going to jail, do not unplug...!
            // We're not raising Sel anyway
            // DecoderPort.lopIll = 1'b1;
        end
        
        // Only raise Sel if we decoded an instruction 
        DecoderPort.Sel = RVIDec.Sel | RVMDec.Sel;
    end;
endmodule