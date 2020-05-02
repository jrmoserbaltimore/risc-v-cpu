// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 05/01/2020
// Design Name: RISC-V RVM Decoder
// Module Name: RVIDecoderTable
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A RISC-V RVM Decoder
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

module RVCTranslator
(
    IPipelineData.ContextIn ContextIn,
    IPipelineData.FetchIn Fetch,
    IPipelineData.ContextOut ContextOut
);

    // FIXME:  Capture both ContextIn and Fetch into fifo, track the 16-bit alignment of PC
    
    logic [15:0] insn;
 
    logic [15:0] r_insn = '0;
    logic register = '0;
    let insn_misaligned = {r_insn, insn};  
    
    
    always_comb
    begin
        // if PC is aligned to 16 bits, move forward.
        // TODO:  Delay and buffer the next 32-bit word if receiving a misaligned 32-bit instuction 
        if (ContextIn.pc[1] == 1'b0)
        begin
            insn = Context.insn[15:0];
        end
        else
        begin
            insn = Context.insn[31:16];
        end
    end

    let opcode = insn[1:0];
    // CI, CSS, CIW, CL, CS, CB, CJ
    let funct3 = insn[15:13];
    // CR
    let funct4 = insn[15:12];
    // CA
    let funct2 = insn[6:5];
    let funct6 = insn[15:10];
    // CIW, CL
    let rd = insn[4:2];
    // CL, CS, CB
    let rs1 = insn[9:7];
    // CS, CA encode rs2 in the same place CIW/CL encode rd
    let rs2 = rd;
    // CR, CI wide registers
    let rs1W = insn[11:7];
    // CR, CSS
    let rs2W = insn[6:2];
    
    // Immediates
    // CIW Wide Immediate
    let imm_ciw = {insn[10:7], insn[12:11], insn[4], insn[5]};
 
    // XXX:  sign extension: C.J, C.JAL, C.BEQZ, C.BNEZ, C.LI, C.LUI, C.ADDI, C.ADDIW, C.ADDI16SP,
    // CSRLI, C.SRAI, C.ANDI
    // -------------------------
    // -- Expansion Functions --
    // -------------------------

    // Output an I-Type by zero-extending the immediate
    function logic[31:0] clToI(
                                input logic[15:0] insn,
                                input logic[1:0] scale, // 00 = 4 (W), 01 = 8 (D), 10 = 16 (Q)
                                input logic[2:0] funct3,
                                input logic[6:0] opcode
                               );
        // CL Load, CS Store, word, double, quad
        let imm_w = {insn[5], insn[12:10], insn[6]};
        let imm_d = {insn[6:5], insn[12:10]};
        let imm_q = {insn[10], insn[6:5], insn[12:11]};

        let rs1 = insn[9:7];
        let rd = insn[4:2];
                
        logic[31:0] insnOut;
        case (scale)
        2'b00: // scale by 4
            insnOut[31:20] = {
                              5'b00000,
                              imm_w,
                              2'b00
                             };
        2'b01: // scale by 8
            insnOut[31:20] = {
                              5'b0000,
                              imm_d,
                              3'b000
                             };
        2'b10: // scale by 16
            insnOut[31:20] = {
                              5'b000,
                              imm_q,
                              4'b0000
                             };
        endcase
        insnOut[19:0] = {
                         2'b01, // register x8+
                         rs1,
                         funct3, // LW funct3
                         2'b01, // x8+
                         rd,
                         opcode // opcode
                        };
        return insnOut;
    endfunction
    
    // Output an S-Type by ???zero-extending the immediate
    function logic[31:0] csToS(
                                input logic[15:0] insn,
                                input logic[1:0] scale, // 00 = 4 (W), 01 = 8 (D), 10 = 16 (Q)
                                input logic[2:0] funct3,
                                input logic[6:0] opcode
                               );
        let imm_w = {insn[5], insn[12:10], insn[6]};
        let imm_d = {insn[6:5], insn[12:10]};
        let imm_q = {insn[10], insn[6:5], insn[12:11]};

        let rs1 = insn[9:7];
        let rs2 = insn[4:2];
        logic[31:0] insnOut;
        case (scale)
        2'b00: // scale by 4
        begin
            insnOut[11:7] = {
                             imm_w[2:0],
                             2'b00
                            };
            insnOut[31:25] = {
                              5'b00000,
                              imm_w[4:3]
                             };
        end
        2'b01: // scale by 8
        begin
            insnOut[11:7] = {
                             imm_d[1:0],
                             3'b000
                            };
            insnOut[31:25] = {
                              4'b0000,
                              imm_d[4:2]
                             };
        end
        2'b10: // scale by 16
        begin
            insnOut[11:7] = {
                             imm_q[0],
                             4'b0000
                            };
            insnOut[31:25] = {
                              3'b000,
                              imm_q[4:1]
                             };
        end
        endcase
        insnOut[24:12] = {
                          2'b01, // register x8+
                          rs2,
                          2'b01,
                          rs1,
                          funct3
                         };
        insnOut[6:0] = opcode;
        return insnOut;
    endfunction

    // ----------------
    // -- Quadrant 0 --
    // ----------------
    //
    // It IS possible to compact Q0 into a mathematical relationship:
    //
    //   funct3[0] = 1 if XLEN-sensitive
    //   funct3[2] = 1 for Store, goes in opcode[5]
    //   funct3[1] = 1 for (RV32) vs (RV64/128) XLEN-Sensitive insns
    //   funct3[1] = 0 for (RV32/64) vs (RV128) XLEN-Sensitive insns
    //
    // The decoder isn't likely in the critical path, nor is it likely a large part of the power
    // consumption.
    module Quadrant0
    (
        IPipelineData.ContextIn ContextIn,
        IPipelineData.ContextOut ContextOut,
        output logic Sel
    );
        always_comb
        begin
            if (
                |insn[15:5] == '0 // Canonical illegal insn or reserved C.ADDI4SPN
                || funct3 == 3'b100
               )
            begin
                // All the invalid instructions
                Sel = 1'b0;
            end
            else
            begin
                // All these are valid
                Sel = 1'b1;
                if (funct3[0] == 1'b0)
                begin
                    // 000, 010, 110
                    // XLEN-insensitive
                    case (funct3)
                        3'b000:
                        begin
                            // C.ADDI4SPN: addi rd, x2, nzuimm
                            /// FIXME:  Convert to function
                            ContextOut.insn = {
                                                2'b00,
                                                imm_ciw,
                                                1'b0,
                                                5'b00010, // x2
                                                3'b000, // ADDI funct3
                                                2'b01, // rd starts from x8
                                                rd,
                                                7'b0010011 // opcode
                                              };
                        end
                        3'b010:
                        begin
                            // C.LW: lw rd, offset(rs1)
                            ContextOut.insn = clToI(ContextIn.insn, 0, 3'b010, 7'b0000011);
                        end
                        3'b110:
                        begin
                            // C.SW: sw rs2, offset(rs1)
                            ContextOut.insn = csToS(ContextIn.insn, 0, 3'b010, 7'b0100011);
                        end
                    endcase
                end // Funct3 == xx0
                else // funct3 == xx1
                begin
                    // XLEN-sensitive functions
                    case (funct3)
                        3'b001:
                        begin
                            if (ContextIn.xlen != 3) // 128
                            begin
                                // C.FLD (RV32/64): fld rd, offset(rs1)
                                ContextOut.insn = clToI(ContextIn.insn, 1, 3'b011, 7'b0000111);
                            end
                            else
                            begin
                                // C.LQ (RV128): lq rd, offset(rs1)
                                // ContextOut.insn = csTol(ContextIn.insn, 2, ?, ?);
                            end
                        end
                        3'b011:
                        begin
                            if (ContextIn.xlen == 0) // 32
                            begin
                                // C.FLW (RV32): flw rd, offset(rs1)
                                ContextOut.insn = clToI(ContextIn.insn, 0, 3'b010, 7'b0000111);
                            end
                            else
                            begin
                                // C.LD (RV64/128): ld rd, offset(rs1)
                                ContextOut.insn = clToI(ContextIn.insn, 1, 3'b011, 7'b0000011);
                            end
                        end
                        3'b101:
                        begin
                            if (ContextIn.xlen != 3) // 128
                            begin
                                // C.FSD (RV32/64): fsd rs2, offset(rs1)
                                ContextOut.insn = csToS(ContextIn.insn, 1, 3'b011, 7'b0100111);
                            end
                            else
                            begin
                                // C.SQ (RV128): sq rs2, offset(rs1)
                                // ContextOut.insn = csToS(ContextIn.insn, 2, ?, ?);
                            end
                        end
                        3'b111:
                        begin
                            if (ContextIn.xlen == 0) // 32
                            begin
                                // C.FSW (RV32): fsw rd, offset(rs1)
                                ContextOut.insn = csToS(ContextIn.insn, 0, 3'b010, 7'b0100111);
                            end
                            else
                            begin
                                // C.SD (RV64/128): sd rs2, offset(rs1)
                                ContextOut.insn = clToS(ContextIn.insn, 1, 3'b011, 7'b0100011);
                            end
                        end
                    endcase
                end
            end
        end
    endmodule

    // ----------------
    // -- Quadrant 1 --
    // ----------------
    module Quadrant1
    (
        IPipelineData.ContextIn ContextIn,
        IPipelineData.ContextOut ContextOut,
        output logic Sel
    );

    endmodule
    
    always_comb
    begin
        if (ContextIn.misaC == 1'b0)
        begin
            // If not supported, don't decode.  Instructions are 32-bit aligned.
            ContextOut.insn = ContextIn.insn;
        end
        else if (insn[1:0] == 2'b11)
        begin
            // FIXME:  Stall, obtain more if pc misaligned
            
        end
        else
        begin
            // Clear state
            DecodedOut.lopAdd = 1'b0;
            DecodedOut.lopShift = 1'b0;
            DecodedOut.lopCmp = 1'b0;
            DecodedOut.lopAND = 1'b0;
            DecodedOut.lopOR = 1'b0;
            DecodedOut.lopXOR = 1'b0;
            DecodedOut.lopMUL = 1'b0;
            DecodedOut.lopDIV = 1'b0;
            DecodedOut.lopLoad = 1'b0;
            DecodedOut.lopStore = 1'b0;
            DecodedOut.lopIllegal = 1'b0;
            
            DecodedOut.opB = 1'b0;
            DecodedOut.opH = 1'b0;
            DecodedOut.opW = 1'b0;
            DecodedOut.opD = 1'b0;
            DecodedOut.opUnsigned = 1'b0;
            DecodedOut.opArithmetic = 1'b0;
            DecodedOut.opRightShift = 1'b0;
            DecodedOut.opHSU = 1'b0;
            DecodedOut.opRemainder = 1'b0;
    
            DecodedOut.lrR = 1'b0;
            DecodedOut.lrI = 1'b0;
            DecodedOut.lrS = 1'b0;
            DecodedOut.lrB = 1'b0;
            DecodedOut.lrU = 1'b0;
            DecodedOut.lrJ = 1'b0;
            
            // FIXME:  SElect between 
        end
    end
endmodule