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
// Revision: 0.2
// Revision 0.2 - Provide data ports tailored to more pipeline stages
// Revision 0.1 - Changed to IPipelineData interface
// Revision 0.01 - File Created
// Additional Comments:
// 
// Stage 1:  Fetch
// Stage 1.5:  Translate:  Decode instructions such as RVC to RISC-V
//             native instructions.  Also possible to translate
//             x86-64 etc. at this stage.
// Stage 2:  Decode
//   - identify what to load
//   - identify the instruction
//   - pass on to load stage
// Stage 3:  identify forward dependencies
//   - Avoid data hazards
//   OOE:  add current insn to forward dependencies, put in buffer,
//         start on next instruction; not meaningfully different
// Stage 4:  load registers and sign-extend
//   - Modify opFlags etc. based on processor feature settings
//   - Assign opFlags for word width (BHWD) by current XLEN if none set
// Stage 5:  execute instruction
// Stage 6:  memory fetch or write (for LOAD/STORE)
// Stage 7:  retire (write all registers)
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

module RVDecoder
(
    IPipelineData.ContextIn ContextIn,
    IPipelineData.DecodedOut DecodedOut,
    output logic Sel
);
    // Data ports for each decoder
    IPipelineData RVIPort();
    IPipelineData RVMPort();

    // Connect our input to their inputs
    assign RVIPort.ContextIn = ContextIn; // FIXME:  Is this valid?
    assign RVMPort.ContextIn = ContextIn;
    
    RVIDecoderTable RVIDec(.ContextIn(RVIPort.ContextIn), .ContextOut(RVIPort.ContextOut));
    RVMDecoderTable RVMDec(.ContextIn(RVMPort.ContextIn), .ContextOut(RVMPort.COntextOut));

    always_comb
    begin
        if (RVIDec.Sel == 1'b1)
        begin
            ContextOut.lopAdd = RVIPort.ContextOutlopAdd; // FIXME:  Figure out if this is valid 
            ContextOut.lopShift = RVIPort.lopShift;
            ContextOut.lopCmp = RVIPort.lopCmp;
            ContextOut.lopAND = RVIPort.lopAND;
            ContextOut.lopOR = RVIPort.lopOR;
            ContextOut.lopXOR = RVIPort.lopXOR;
            ContextOut.lopMUL = RVIPort.lopMUL;
            ContextOut.lopDIV = RVIPort.lopDIV;
            ContextOut.lopLoad = RVIPort.lopLoad;
            ContextOut.lopStore = RVIPort.lopStore;
            ContextOut.lopIllegal = RVIPort.lopIllegal;
            
            ContextOut.opB = RVIPort.opB;
            ContextOut.opH = RVIPort.opH;
            ContextOut.opW = RVIPort.opW;
            ContextOut.opD = RVIPort.opD;
            ContextOut.opUnsigned = RVIPort.opUnsigned;
            ContextOut.opArithmetic = RVIPort.opArithmetic;
            ContextOut.opRightShift = RVIPort.opRightShift;
            ContextOut.opHSU = RVIPort.opHSU;
            ContextOut.opRemainder = RVIPort.opRemainder;
    
            ContextOut.lrR = RVIPort.lrR;
            ContextOut.lrI = RVIPort.lrI;
            ContextOut.lrS = RVIPort.lrS;
            ContextOut.lrB = RVIPort.lrB;
            ContextOut.lrU = RVIPort.lrU;
            ContextOut.lrJ = RVIPort.lrJ;
        end
        else if (RVMPort.Sel == 1'b1)
        begin
            ContextOut.lopAdd = RVMPort.lopAdd;
            ContextOut.lopShift = RVMPort.lopShift;
            ContextOut.lopCmp = RVMPort.lopCmp;
            ContextOut.lopAND = RVMPort.lopAND;
            ContextOut.lopOR = RVMPort.lopOR;
            ContextOut.lopXOR = RVMPort.lopXOR;
            ContextOut.lopMUL = RVMPort.lopMUL;
            ContextOut.lopDIV = RVMPort.lopDIV;
            ContextOut.lopLoad = RVMPort.lopLoad;
            ContextOut.lopStore = RVMPort.lopStore;
            ContextOut.lopIllegal = RVMPort.lopIllegal;
            
            ContextOut.opB = RVMPort.opB;
            ContextOut.opH = RVMPort.opH;
            ContextOut.opW = RVMPort.opW;
            ContextOut.opD = RVMPort.opD;
            ContextOut.opUnsigned = RVMPort.opUnsigned;
            ContextOut.opArithmetic = RVMPort.opArithmetic;
            ContextOut.opRightShift = RVMPort.opRightShift;
            ContextOut.opHSU = RVMPort.opHSU;
            ContextOut.opRemainder = RVMPort.opRemainder;
    
            ContextOut.lrR = RVMPort.lrR;
            ContextOut.lrI = RVMPort.lrI;
            ContextOut.lrS = RVMPort.lrS;
            ContextOut.lrB = RVMPort.lrB;
            ContextOut.lrU = BranchPort.lrU;
            ContextOut.lrJ = BranchPort.lrJ;
        end
        else
        begin
            // Clear state
            ContextOut.lopAdd = 1'b0;
            ContextOut.lopShift = 1'b0;
            ContextOut.lopCmp = 1'b0;
            ContextOut.lopAND = 1'b0;
            ContextOut.lopOR = 1'b0;
            ContextOut.lopXOR = 1'b0;
            ContextOut.lopMUL = 1'b0;
            ContextOut.lopDIV = 1'b0;
            ContextOut.lopLoad = 1'b0;
            ContextOut.lopStore = 1'b0;
            ContextOut.lopIllegal = 1'b0;
            
            ContextOut.opB = 1'b0;
            ContextOut.opH = 1'b0;
            ContextOut.opW = 1'b0;
            ContextOut.opD = 1'b0;
            ContextOut.opUnsigned = 1'b0;
            ContextOut.opArithmetic = 1'b0;
            ContextOut.opRightShift = 1'b0;
            ContextOut.opHSU = 1'b0;
            ContextOut.opRemainder = 1'b0;
    
            ContextOut.lrR = 1'b0;
            ContextOut.lrI = 1'b0;
            ContextOut.lrS = 1'b0;
            ContextOut.lrB = 1'b0;
            ContextOut.lrU = 1'b0;
            ContextOut.lrJ = 1'b0;
            // Illegal…instruction?  No you're not going to jail, do not unplug...!
            // We're not raising Sel anyway
            // ContextOut.lopIll = 1'b1;
        end
        
        // Only raise Sel if we decoded an instruction 
        Sel = RVIDec.Sel | RVMDec.Sel;
    end
endmodule