// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: RISC-V RVI Decoder
// Module Name: RVIDecoderTable
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A RISC-V RVI Decoder
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.3
// Revision 0.3 - Reworked around new data unions
// Revision 0.2 - Changed to IPipelineData interface
// Revision 0.1 - Added all except FENCE, ECALL, EBREAK
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

import Kerberos::*;

module RVIDecoderTable
(
    IPipelineData.ContextIn ContextIn,
    output decode_data_t DecodedOut,
    output uwire Sel
);
    // ---------------------------------
    // -- RV32I/RV64I jump and branch --
    // ---------------------------------
    // funct3: EUI, Equal, Unsigned, Invert
    // funct3   opcode      insn    Invert  Unsigned    Invert+Unsigned
    //          1101111     JAL
    // 000      1100111     JALR
    // 00i      1100011     BEQ     BNE
    // 1ui      1100011     BLT     BGE     BLTU        BGEU
    module Branch
    (
        input uwire instruction_t Insn,
        output decode_data_t DecodedOut,
        output uwire Sel
    );
        // Ignore all invalid or non-branch instructions
        assign Sel =  DecodedOut.ops.load_resource.J
                    | DecodedOut.ops.load_resource.B
                    | DecodedOut.ops.load_resource.J;
        always_comb
        begin
            // Clear state
            DecodedOut.bitfield = '0;
            if (
                ((Insn.r.opcode & 7'b1100011) == 7'b1100011)
                && Insn.r.opcode[4] == 1'b0
                // && Insn.r.opcode [3:2] != 2'b10 // Unnecessary due to no check for illegal instruction
               )
            begin
                // Definitely a Branch/JAL/JALR opcode
                DecodedOut.ops.ops.Branch = 1'b1;
                // J-type JAL
                DecodedOut.ops.load_resource.J = (Insn.r.opcode[3:2] == 2'b11) ? 1'b1 : 1'b0;
                // B-type Branch opcode; funct3 cannot be 010 or 011
                DecodedOut.ops.load_resource.B = (Insn.r.opcode[3:2] == 2'b00 && Insn.r.funct3[2:1] != 2'b01) ? 1'b1 : 1'b0;
                // I-type JALR
                DecodedOut.ops.load_resource.I = (Insn.r.opcode[3:2] == 2'b01 && Insn.r.funct3 == 3'b000) ? 1'b1 : 1'b0;
            end
        end
    endmodule

    // --------------------------------------------
    // -- RV32I/64I load/store and LUI/LWU/AUIPC --
    // --------------------------------------------
    // funct3: UWH, D is W+H
    // funct3   opcode      insn
    //          0110111     LUI
    //          0010111     AUIPC
    // 000      0000011     LB
    // 001      0000011     LH
    // 010      0000011     LW
    // 011      0000011     LD
    // 100      0000011     LBU
    // 101      0000011     LHU
    // 110      0000011     LWU
    // 000      0100011     SB
    // 001      0100011     SH
    // 010      0100011     SW
    // 011      0100011     SD
    module LoadStore
    (
        input uwire instruction_t Insn,
        output decode_data_t DecodedOut,
        output uwire Sel
    );
        // Only raise Sel on recognized valid load/store instruction
        assign Sel = DecodedOut.ops.ops.Load | DecodedOut.ops.ops.Store;

        always_comb
        begin
            // Clear state
            DecodedOut.bitfield = '0;
            if (
                (
                    ((Insn.r.opcode | 7'b0100000) == 7'b0100011) // Load/Store
                 || (Insn.r.opcode == 7'b0110111) // LUI
                 || (Insn.r.opcode == 7'b0010111) // AUIPC
                )
                && !((Insn.r.opcode[5] == 1'b1) && (Insn.r.funct3[2] == 1'b1)) // Undefined
               )
            begin
                case (Insn.r.opcode)
                // Load/Store
                    7'b0000011, 7'b0100011:
                    begin
                        // LWU is also "110"
                        DecodedOut.ops.flags.Unsigned = Insn.r.funct3[2];
                        //64-bit LD/SD
                        DecodedOut.ops.flags.D = Insn.r.funct3[1] & Insn.r.funct3[0];
                        // 32-bit LD/ST
                        DecodedOut.ops.flags.W = Insn.r.funct3[1] & ~DecodedOut.ops.flags.D;
                        DecodedOut.ops.flags.H = Insn.r.funct3[0] & ~DecodedOut.ops.flags.D;
                        // Operation load/store
                        DecodedOut.ops.ops.Load  = ~Insn.r.opcode[5];
                        DecodedOut.ops.ops.Store = Insn.r.opcode[5];
                        DecodedOut.ops.load_resource.I      = DecodedOut.ops.ops.Load;
                        DecodedOut.ops.load_resource.S      = DecodedOut.ops.ops.Store;
                    end
                    7'b0110111, 7'b0010111:
                    begin
                        // LUI/AUIPC
                        DecodedOut.ops.ops.Load = 1'b1;
                        // U type
                        DecodedOut.ops.load_resource.U     = Insn.r.opcode[5];
                    end
                endcase
            end
        end
    endmodule

    // ---------------------------------------
    // -- RV32I/RV64I Arithmetic operations --
    // ---------------------------------------
    // W operations: 0i1w011
    // funct7   funct3  opcode      insn    opcode-w=1  opcode-i=0  opcode-i=0,w=1
    // 0000000  000     0i1w011     ADD     ADDW        ADDI        ADDIW
    // 0100000  000     0i1w011     SUB     SUBW
    // 0000000  001     0i1w011     SLL     SLLW        SLLI        SLLIW
    // 0000000  010     0i1w011     SLT                 SLTI
    // 0000000  011     0i1w011     SLTU                SLTIU
    // 0000000  100     0i1w011     XOR                 XORI
    // 0000000  101     0i1w011     SRL     SRLW        SRLI        SRLIW
    // 0100000  101     0i1w011     SRA     SRAW        SRAI        SRAIW
    // 0000000  110     0i1w011     OR                  ORI
    // 0000000  111     0i1w011     AND                 ANDI
    module Arithmetic
    (
        input uwire instruction_t Insn,
        output decode_data_t DecodedOut,
        output uwire Sel
    );
    
        assign Sel =  DecodedOut.ops.ops.Add
                    | DecodedOut.ops.ops.Shift
                    | DecodedOut.ops.ops.Cmp
                    | DecodedOut.ops.ops.XOR
                    | DecodedOut.ops.ops.OR
                    | DecodedOut.ops.ops.AND;
        always_comb
        begin
            // Clear state
            DecodedOut.bitfield = '0;
            // Not RVI Arithmetic if these aren't met
            if (
                ((Insn.r.opcode & 7'b0010011) == 7'b0010011) // These bits on
                && ((Insn.r.opcode & 7'b1000100) == 7'b0000000) // These bits off
                     // Essential mask 0_1_011
                && ((Insn.r.funct7 & 7'b1011111) == 7'b0000000)
               )
            begin
                // extract W and I bits
                DecodedOut.ops.flags.W = Insn.r.opcode[3];
                DecodedOut.ops.flags.Arithmetic = Insn.r.funct7[5];
                
                // Arithmetic bit doesn't go to output for SUB
                DecodedOut.ops.load_resource.R = Insn.r.opcode[5]; // R-type
                DecodedOut.ops.load_resource.I = ~Insn.r.opcode[5]; // I-type 
                // Check for illegal instruction
                if (
                    !(
                         ( (DecodedOut.ops.flags.Arithmetic == 1'b1) && (Insn.r.funct3 != 3'b000) && (Insn.r.funct3 != 3'b101) ) // not SUB or SRA
                      || ( (DecodedOut.ops.load_resource.I == 1'b1) && (Insn.r.funct3 == 3'b000) ) // SUBI isn't an opcode
                      || ( (DecodedOut.ops.flags.W == 1'b1) && (
                                               (Insn.r.funct3 == 3'b010) // SLT
                                            || (Insn.r.funct3 == 3'b011) // SLTU
                                            || (Insn.r.funct3 == 3'b100) // XOR
                                            || (Insn.r.funct3 == 3'b110) // OR
                                            || (Insn.r.funct3 == 3'b111) // AND
                                            )
                         )
                    ) // not
                   )
                begin
                    // Decode funct3
                    case (Insn.r.funct3)
                        3'b000:
                            // lrA determins add or subtract as per table above
                            DecodedOut.ops.ops.Add = 1'b1;
                        3'b001, 3'b101:
                        begin
                            DecodedOut.ops.ops.Shift = 1'b1;
                            // assign opAr = funct7(5); // Done above
                            // Right shift
                            DecodedOut.ops.flags.RightShift = (Insn.r.funct3 == 3'b101) ? 1'b1 : 1'b0;
                        end
    
                        3'b010, 3'b011:
                        begin
                            DecodedOut.ops.ops.Cmp = 1'b1;
                            DecodedOut.ops.flags.Unsigned = (Insn.r.funct3 == 3'b011) ? 1'b1 : 1'b0;
                        end

                        3'b100:
                            DecodedOut.ops.ops.XOR = 1'b1;
                        3'b110:
                            DecodedOut.ops.ops.OR = 1'b1;
                        3'b111:
                            DecodedOut.ops.ops.AND = 1'b1;
                    endcase
                end 
            end
        end
    endmodule

    // -----------------------------------
    // -- RV32I/RV64I System Operations --
    // -----------------------------------
    // funct3 is always 000
    // opcode   [20]    insn
    // 0001111          FENCE
    // 1110011    0     ECALL
    // 1110011    1     EBREAK
    module System
    (
        input uwire instruction_t Insn,
        output decode_data_t DecodedOut,
        output uwire Sel
    );
        assign Sel =  DecodedOut.ops.ops.Fence
                    | DecodedOut.ops.ops.SysCall
                    | DecodedOut.ops.ops.SysBreak;

        always_comb
        begin
            // Clear state
            DecodedOut.bitfield = '0;
            // FIXME:  implement these
            if (
                   Insn.r.opcode == 7'b1110011
                && Insn.insn[31:26] == '0
                && Insn.insn[24:7] == '0
               )
            begin
                // ECALL/EBREAK
                // DecodedOut.lopSysCallBreak = 1'b1;
                DecodedOut.ops.ops.SysCall = ~Insn.insn[25];
                DecodedOut.ops.ops.SysBreak = Insn.insn[25];
            end
            DecodedOut.ops.ops.Fence = (Insn.r.opcode == 7'b0001111 && Insn.r.funct3 == 3'b000) ? 1'b1 : 1'b0;
        end
    endmodule

    decode_data_t BranchDecoded;
    decode_data_t LSDecoded;
    decode_data_t ArithmeticDecoded;
    decode_data_t SystemDecoded;
    
    uwire BranchSel, LSSel, ArithmeticSel, SystemSel;

    Branch BranchDec(.Insn(ContextIn.insn), .DecodedOut(BranchDecoded), .Sel(BranchSel));
    LoadStore LoadDec(.Insn(ContextIn.insn), .DecodedOut(LSDecoded), .Sel(LSSel));
    Arithmetic ArithmeticDec(.Insn(ContextIn.insn), .DecodedOut(ArithmeticDecoded), .Sel(ArithmeticSel));
    System SystemDec(.Insn(ContextIn.insn), .DecodedOut(SystemDecoded), .Sel(SystemSel));

    // Only raise Sel if we decoded an instruction 
    assign Sel = BranchSel | LSSel | ArithmeticSel | SystemSel;

    always_comb
    begin
        // Huge 5:1 mux
        if (BranchSel)
        begin
            DecodedOut = BranchDecoded;
        end
        else if (LSSel)
        begin
            DecodedOut = LSDecoded;
        end
        else if (ArithmeticSel)
        begin
            DecodedOut = ArithmeticDecoded;
        end
        else if (SystemSel)
        begin
            DecodedOut = SystemDecoded;
        end
        else
        begin
            DecodedOut = '0;
        end
    end
endmodule