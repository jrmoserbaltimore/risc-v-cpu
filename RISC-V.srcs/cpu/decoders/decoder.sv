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
// Revision: 0.3
// Revision 0.2 - Reworked around new data unions
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
`default_nettype none

import Kerberos::*;

module RVDecoder
(
    input instruction_t Insn,
    IPipelineData.ContextIn ContextIn,
    IPipelineData.DecodedOut DecodedOut,
    output logic Sel
);
    IPipelineData.DecodedOut RVIDecoded, RVMDecoded;
    uwire RVISel, RVMSel;

    RVIDecoderTable RVIDec(.Insn(Insn), .ContextIn(ContextIn), .DecodedOut(RVIDecoded), .Sel(RVISel));
    RVMDecoderTable RVMDec(.Insn(Insn), .ContextIn(ContextIn), .DecodedOut(RVMDecoded), .Sel(RVMSel));

    always_comb
    begin
        if (RVISel)
        begin
            DecodedOut = RVIDecoded;
        end
        else if (RVMSel)
        begin
            DecodedOut = RVMDecoded;
        end

        // Illegal…instruction?  No you're not going to jail, do not unplug...!
        // We're not raising Sel anyway
        // DecodedOut.ops.ops.Illegal = 1'b1;

        // No need to clear state:  only raise Sel if we decoded an instruction        
        Sel = RVISel | RVMSel;
    end
endmodule