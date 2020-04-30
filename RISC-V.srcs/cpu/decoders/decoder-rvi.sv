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
// Revision: 0.2
// Revision 0.2 - Changed to IPipelineData interface
// Revision 0.1 - Added all except FENCE, ECALL, EBREAK
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

module RVIDecoderTable
(
    IPipelineData.ContextIn ContextIn,
    IPipelineData.DecodedOut DecodedOut,
    output logic Sel
);
    // opcode
    let opcode = ContextIn.insn[6:0];
    let funct3 = ContextIn.insn[14:12];
    // I-type immediate value
    let imm = ContextIn.insn[31:20];
    // R-type
    let funct7 = ContextIn.insn[31:25];

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
        IPipelineData.DecodedOut DecodedOut,
        output logic Sel
    );
        always_comb
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
            
            Sel = 1'b0;
            if (
                ((opcode & 7'b1100011) == 7'b1100011)
                && opcode[4] == 1'b0
                // && opcode [3:2] != 2'b10 // Unnecessary due to no check for this one
               )
            begin
                // Definitely a Branch/JAL/JALR opcode
                // J-type JAL
                DecodedOut.lrJ = (opcode[3:2] == 2'b11) ? 1'b1 : 1'b0;
                // B-type Branch opcode; funct3 cannot be 010 or 011
                DecodedOut.lrB = (opcode[3:2] == 2'b00 && funct3[2:1] != 2'b01) ? 1'b1 : 1'b0;
                // I-type JALR
                DecodedOut.lrI = (opcode[3:2] == 2'b01 && funct3 == 3'b000) ? 1'b1 : 1'b0;
                Sel = DecodedOut.lrI | DecodedOut.lrB | DecodedOut.lrJ;
                // Ignore all invalid or non-branch instructions
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
        IPipelineData.DecodedOut DecodedOut,
        output logic Sel
    );
        always_comb
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
            
            Sel = 1'b0;
            if (
                   ((opcode | 7'b0100000) == 7'b0100011) // Load/Store
                || (opcode == 7'b0110111) // LUI
                || (opcode == 7'b0010111) // AUIPC
               )
            begin
                if ((opcode[5] == 1'b1) && (funct3[2] == 1'b1))
                    // Illegal instruction
                    DecodedOut.lopIllegal = 1'b1;
                else
                begin
                    case (opcode)
                    // Load/Store
                        7'b0000011 || 7'b0100011:
                        begin
                            // LWU is also "110"
                            DecodedOut.opUnsigned = funct3[2];
                            //64-bit LD/SD
                            DecodedOut.opD = funct3[1] & funct3[0];
                            // 32-bit LD/ST
                            DecodedOut.opW = funct3[1] & ~DecodedOut.opD;
                            DecodedOut.opH = funct3[0] & ~DecodedOut.opD;
                            // Operation load/store
                            DecodedOut.lopLoad  = ~opcode[5];
                            DecodedOut.lopStore = opcode[5];
                            DecodedOut.lrI      = DecodedOut.lopLoad;
                            DecodedOut.lrS      = DecodedOut.lopStore;
                        end
                        7'b0110111 || 7'b0010111:
                        begin
                            // LUI/AUIPC
                            DecodedOut.lopLoad = 1'b1;
                            // U type
                            DecodedOut.lrU     = opcode[5];
                        end
                    endcase
                end
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
        IPipelineData.DecodedOut DecodedOut,
        output logic Sel
    );
        always_comb
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
            
            Sel = 1'b0;
            // Not RVI Arithmetic if these aren't met
            if (
                ((opcode & 7'b0010011) == 7'b0010011) // These bits on
                && ((opcode & 7'b1000100) == 7'b0000000) // These bits off
                     // Essential mask 0_1_011
                && ((funct7 & 7'b1011111) == 7'b0000000)
               )
            begin
                // extract W and I bits
                DecodedOut.opW = opcode[3];
                DecodedOut.opArithmetic = funct7[5];
                
                // Arithmetic bit doesn't go to output for SUB
                DecodedOut.lrR = opcode[5]; // R-type
                DecodedOut.lrI = ~opcode[5]; // I-type 
                // Check for illegal instruction
                if (
                       ( (DecodedOut.opAr == 1'b1) && (funct3 != 3'b000) && (funct3 != 3'b101) ) // not SUB or SRA
                    || ( (DecodedOut.lrI == 1'b1) && (funct3 == 3'b000) ) // SUBI isn't an opcode
                    || ( (DecodedOut.opW == 1'b1) && (
                                             (funct3 == 3'b010) // SLT
                                          || (funct3 == 3'b011) // SLTU
                                          || (funct3 == 3'b100) // XOR
                                          || (funct3 == 3'b110) // OR
                                          || (funct3 == 3'b111) // AND
                                          )
                        )
                   )
                begin
                    // illegal instruction.  Don't Sel in case something else sees it as legal
                    DecodedOut.lopIllegal = 1'b1;
                    Sel = 1'b0;
                end
                else
                begin
                    // Decode funct3
                    case (funct3)
                        3'b000:
                            // lrA determins add or subtract as per table above
                            DecodedOut.lopAdd = 1'b1;
                        3'b001 || 3'b101:
                        begin
                            DecodedOut.lopShift = 1'b1;
                            // assign opAr = funct7(5); // Done above
                            // Right shift
                            DecodedOut.opRightShift = (funct3 == 3'b101) ? 1'b1 : 1'b0;
                        end
    
                        3'b010 || 3'b011:
                        begin
                            DecodedOut.lopCmp = 1'b1;
                            DecodedOut.opUnsigned = (funct3 == 3'b011) ? 1'b1 : 1'b0;
                        end

                        3'b100:
                            DecodedOut.lopXOR = 1'b1;
                        3'b110:
                            DecodedOut.lopOR = 1'b1;
                        3'b111:
                            DecodedOut.lopAND = 1'b1;
                    endcase
                end 
            end
            else
            begin
                Sel = 1'b0;
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
        IPipelineData.DecodedOut DecodedOut,
        output logic Sel
    );
        always_comb
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
            
            Sel = 1'b0;
            // FIXME:  implement these
            if (
                   opcode == 7'b1110011
                && ContextIn.insn[31:26] == '0
                && ContextIn.insn[24:7] == '0
               )
            begin
                // ECALL/EBREAK
                // DecodedOut.lopSysCallBreak = 1'b1;
            end
            // DecodedOut.lopFence = (opcode == 7'b0001111) ? 1'b1 : 1'b0;
            // Sel = DecoderPort.lopFence & DecoderPort.lopSysCallBreak;
        end
    endmodule

    DecoderPort BranchPort();
    DecoderPort LoadStorePort();
    DecoderPort ArithmeticPort();
    DecoderPort SystemPort();

    Branch BranchDec(.ContextOut(BranchPort.ContextOut));
    LoadStore LoadDec(.ContextOut(LoadStorePort.ContextOut));
    Arithmetic ArithmeticDec(.ContextOut(LoadStorePort.ContextOut));
    System SystemDec(.ContextOut(LoadStorePort.ContextOut));

    always_comb
    begin
        // Huge 5:1 mux
        if (BranchDec.Sel == 1'b1)
        begin
            DecodedOut.lopAdd = BranchPort.lopAdd;
            DecodedOut.lopShift = BranchPort.lopShift;
            DecodedOut.lopCmp = BranchPort.lopCmp;
            DecodedOut.lopAND = BranchPort.lopAND;
            DecodedOut.lopOR = BranchPort.lopOR;
            DecodedOut.lopXOR = BranchPort.lopXOR;
            DecodedOut.lopMUL = BranchPort.lopMUL;
            DecodedOut.lopDIV = BranchPort.lopDIV;
            DecodedOut.lopLoad = BranchPort.lopLoad;
            DecodedOut.lopStore = BranchPort.lopStore;
            DecodedOut.lopIllegal = BranchPort.lopIllegal;
            
            DecodedOut.opB = BranchPort.opB;
            DecodedOut.opH = BranchPort.opH;
            DecodedOut.opW = BranchPort.opW;
            DecodedOut.opD = BranchPort.opD;
            DecodedOut.opUnsigned = BranchPort.opUnsigned;
            DecodedOut.opArithmetic = BranchPort.opArithmetic;
            DecodedOut.opRightShift = BranchPort.opRightShift;
            DecodedOut.opHSU = BranchPort.opHSU;
            DecodedOut.opRemainder = BranchPort.opRemainder;
    
            DecodedOut.lrR = BranchPort.lrR;
            DecodedOut.lrI = BranchPort.lrI;
            DecodedOut.lrS = BranchPort.lrS;
            DecodedOut.lrB = BranchPort.lrB;
            DecodedOut.lrU = BranchPort.lrU;
            DecodedOut.lrJ = BranchPort.lrJ;
        end
        else if (LoadDec.Sel == 1'b1)
        begin
            DecodedOut.lopAdd = LoadStorePort.lopAdd;
            DecodedOut.lopShift = LoadStorePort.lopShift;
            DecodedOut.lopCmp = LoadStorePort.lopCmp;
            DecodedOut.lopAND = LoadStorePort.lopAND;
            DecodedOut.lopOR = LoadStorePort.lopOR;
            DecodedOut.lopXOR = LoadStorePort.lopXOR;
            DecodedOut.lopMUL = LoadStorePort.lopMUL;
            DecodedOut.lopDIV = LoadStorePort.lopDIV;
            DecodedOut.lopLoad = LoadStorePort.lopLoad;
            DecodedOut.lopStore = LoadStorePort.lopStore;
            DecodedOut.lopIllegal = LoadStorePort.lopIllegal;
            
            DecodedOut.opB = LoadStorePort.opB;
            DecodedOut.opH = LoadStorePort.opH;
            DecodedOut.opW = LoadStorePort.opW;
            DecodedOut.opD = LoadStorePort.opD;
            DecodedOut.opUnsigned = LoadStorePort.opUnsigned;
            DecodedOut.opArithmetic = LoadStorePort.opArithmetic;
            DecodedOut.opRightShift = LoadStorePort.opRightShift;
            DecodedOut.opHSU = LoadStorePort.opHSU;
            DecodedOut.opRemainder = LoadStorePort.opRemainder;
    
            DecodedOut.lrR = LoadStorePort.lrR;
            DecodedOut.lrI = LoadStorePort.lrI;
            DecodedOut.lrS = LoadStorePort.lrS;
            DecodedOut.lrB = LoadStorePort.lrB;
            DecodedOut.lrU = LoadStorePort.lrU;
            DecodedOut.lrJ = LoadStorePort.lrJ;
        end
        else if (ArithmeticDec.Sel == 1'b1)
        begin
            DecodedOut.lopAdd = ArithmeticPort.lopAdd;
            DecodedOut.lopShift = ArithmeticPort.lopShift;
            DecodedOut.lopCmp = ArithmeticPort.lopCmp;
            DecodedOut.lopAND = ArithmeticPort.lopAND;
            DecodedOut.lopOR = ArithmeticPort.lopOR;
            DecodedOut.lopXOR = ArithmeticPort.lopXOR;
            DecodedOut.lopMUL = ArithmeticPort.lopMUL;
            DecodedOut.lopDIV = ArithmeticPort.lopDIV;
            DecodedOut.lopLoad = ArithmeticPort.lopLoad;
            DecodedOut.lopStore = ArithmeticPort.lopStore;
            DecodedOut.lopIllegal = ArithmeticPort.lopIllegal;
            
            DecodedOut.opB = ArithmeticPort.opB;
            DecodedOut.opH = ArithmeticPort.opH;
            DecodedOut.opW = ArithmeticPort.opW;
            DecodedOut.opD = ArithmeticPort.opD;
            DecodedOut.opUnsigned = ArithmeticPort.opUnsigned;
            DecodedOut.opArithmetic = ArithmeticPort.opArithmetic;
            DecodedOut.opRightShift = ArithmeticPort.opRightShift;
            DecodedOut.opHSU = ArithmeticPort.opHSU;
            DecodedOut.opRemainder = ArithmeticPort.opRemainder;
    
            DecodedOut.lrR = ArithmeticPort.lrR;
            DecodedOut.lrI = ArithmeticPort.lrI;
            DecodedOut.lrS = ArithmeticPort.lrS;
            DecodedOut.lrB = ArithmeticPort.lrB;
            DecodedOut.lrU = BranchPort.lrU;
            DecodedOut.lrJ = BranchPort.lrJ;
        end
        else if (SystemDec.Sel == 1'b1)
        begin
            DecodedOut.lopAdd = SystemPort.lopAdd;
            DecodedOut.lopShift = SystemPort.lopShift;
            DecodedOut.lopCmp = SystemPort.lopCmp;
            DecodedOut.lopAND = SystemPort.lopAND;
            DecodedOut.lopOR = SystemPort.lopOR;
            DecodedOut.lopXOR = SystemPort.lopXOR;
            DecodedOut.lopMUL = SystemPort.lopMUL;
            DecodedOut.lopDIV = SystemPort.lopDIV;
            DecodedOut.lopLoad = SystemPort.lopLoad;
            DecodedOut.lopStore = SystemPort.lopStore;
            DecodedOut.lopIllegal = SystemPort.lopIllegal;
            
            DecodedOut.opB = SystemPort.opB;
            DecodedOut.opH = SystemPort.opH;
            DecodedOut.opW = SystemPort.opW;
            DecodedOut.opD = SystemPort.opD;
            DecodedOut.opUnsigned = SystemPort.opUnsigned;
            DecodedOut.opArithmetic = SystemPort.opArithmetic;
            DecodedOut.opRightShift = SystemPort.opRightShift;
            DecodedOut.opHSU = SystemPort.opHSU;
            DecodedOut.opRemainder = SystemPort.opRemainder;
    
            DecodedOut.lrR = SystemPort.lrR;
            DecodedOut.lrI = SystemPort.lrI;
            DecodedOut.lrS = SystemPort.lrS;
            DecodedOut.lrB = SystemPort.lrB;
            DecodedOut.lrU = SystemPort.lrU;
            DecodedOut.lrJ = SystemPort.lrJ;
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
            // Illegal…instruction?  No you're not going to jail, do not unplug...!
            // We're not raising Sel anyway
            // DecoderPort.lopIll = 1'b1;
        end
        
        // Only raise Sel if we decoded an instruction 
        Sel = BranchDec.Sel | LoadDec.Sel | ArithmeticPort.Sel;
    end
endmodule