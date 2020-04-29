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
    IPipelineData.Decoder DecoderPort,
    output logic Sel
);
    // opcode
    let opcode = DecoderPort.insn[6:0];
    let funct3 = DecoderPort.insn[14:12];
    // I-type immediate value
    let imm = DecoderPort.insn[31:20];
    // R-type
    let funct7 = DecoderPort.insn[31:25];

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
        IPipelineData.Decoder DecoderPort,
        output logic Sel
    );
        always_comb
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
            
            Sel = 1'b0;
            if (
                ((opcode & 7'b1100011) == 7'b1100011)
                && opcode[4] == 1'b0
                // && opcode [3:2] != 2'b10 // Unnecessary due to no check for this one
               )
            begin
                // Definitely a Branch/JAL/JALR opcode
                // J-type JAL
                DecoderPort.lrJ = (opcode[3:2] == 2'b11) ? 1'b1 : 1'b0;
                // B-type Branch opcode; funct3 cannot be 010 or 011
                DecoderPort.lrB = (opcode[3:2] == 2'b00 && funct3[2:1] != 2'b01) ? 1'b1 : 1'b0;
                // I-type JALR
                DecoderPort.lrI = (opcode[3:2] == 2'b01 && funct3 == 3'b000) ? 1'b1 : 1'b0;
                DecoderPort.Sel = DecoderPort.lrI | DecoderPort.lrB | DecoderPort.lrJ;
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
        IPipelineData.Decoder DecoderPort,
        output logic Sel
    );
        always_comb
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
            
            Sel = 1'b0;
            if (
                   ((opcode | 7'b0100000) == 7'b0100011) // Load/Store
                || (opcode == 7'b0110111) // LUI
                || (opcode == 7'b0010111) // AUIPC
               )
            begin
                if ((opcode[5] == 1'b1) && (funct3[2] == 1'b1))
                    // Illegal instruction
                    DecoderPort.lopIllegal = 1'b1;
                else
                begin
                    case (opcode)
                    // Load/Store
                        7'b0000011 || 7'b0100011:
                        begin
                            // LWU is also "110"
                            DecoderPort.opUnsigned = funct3[2];
                            //64-bit LD/SD
                            DecoderPort.opD = funct3[1] & funct3[0];
                            // 32-bit LD/ST
                            DecoderPort.opW = funct3[1] & ~DecoderPort.opD;
                            DecoderPort.opH = funct3[0] & ~DecoderPort.opD;
                            // Operation load/store
                            DecoderPort.lopLoad  = ~opcode[5];
                            DecoderPort.lopStore = opcode[5];
                            DecoderPort.lrI      = DecoderPort.lopLoad;
                            DecoderPort.lrS      = DecoderPort.lopStore;
                        end
                        7'b0110111 || 7'b0010111:
                        begin
                            // LUI/AUIPC
                            DecoderPort.lopLoad = 1'b1;
                            // U type
                            DecoderPort.lrU     = opcode[5];
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
        IPipelineData.Decoder DecoderPort,
        output logic Sel
    );
        always_comb
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
                DecoderPort.opW = opcode[3];
                DecoderPort.opArithmetic = funct7[5];
                
                // Arithmetic bit doesn't go to output for SUB
                DecoderPort.lrR = opcode[5]; // R-type
                DecoderPort.lrI = ~opcode[5]; // I-type 
                // Check for illegal instruction
                if (
                       ( (DecoderPort.opAr == 1'b1) && (funct3 != 3'b000) && (funct3 != 3'b101) ) // not SUB or SRA
                    || ( (DecoderPort.lrI == 1'b1) && (funct3 == 3'b000) ) // SUBI isn't an opcode
                    || ( (DecoderPort.opW == 1'b1) && (
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
                    DecoderPort.lopIllegal = 1'b1;
                    Sel = 1'b0;
                end
                else
                begin
                    // Decode funct3
                    case (funct3)
                        3'b000:
                            // lrA determins add or subtract as per table above
                            DecoderPort.lopAdd = 1'b1;
                        3'b001 || 3'b101:
                        begin
                            DecoderPort.lopShift = 1'b1;
                            // assign opAr = funct7(5); // Done above
                            // Right shift
                            DecoderPort.opRightShift = (funct3 == 3'b101) ? 1'b1 : 1'b0;
                        end
    
                        3'b010 || 3'b011:
                        begin
                            DecoderPort.lopCmp = 1'b1;
                            DecoderPort.opUnsigned = (funct3 == 3'b011) ? 1'b1 : 1'b0;
                        end

                        3'b100:
                            DecoderPort.lopXOR = 1'b1;
                        3'b110:
                            DecoderPort.lopOR = 1'b1;
                        3'b111:
                            DecoderPort.lopAND = 1'b1;
                    endcase
                end 
            end
            else
                Sel = 1'b0;
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
        IPipelineData.Decoder DecoderPort,
        output logic Sel
    );
        always_comb
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
            
            Sel = 1'b0;
            // FIXME:  implement these
            if (
                   opcode == 7'b1110011
                && DecoderPort.insn[31:26] == '0
                && DecoderPort.insn[24:7] == '0
               )
            begin
                // ECALL/EBREAK
                // DecoderPort.lopSysCallBreak = 1'b1;
            end
            // DecoderPort.lopFence = (opcode == 7'b0001111) ? 1'b1 : 1'b0;
            // DecoderPort.Sel = DecoderPort.lopFence & DecoderPort.lopSysCallBreak;
        end
    endmodule

    DecoderPort BranchPort();
    DecoderPort LoadStorePort();
    DecoderPort ArithmeticPort();
    DecoderPort SystemPort();

    Branch BranchDec(.DecoderPort(BranchPort));
    LoadStore LoadDec(.DecoderPort(LoadStorePort));
    Arithmetic ArithmeticDec(.DecoderPort(ArithmeticPort));
    System SystemDec(.DecoderPort(SystemPort));

    always_comb
    begin
        // Huge 5:1 mux
        if (BranchDec.Sel == 1'b1)
        begin
            DecoderPort.lopAdd = BranchPort.lopAdd;
            DecoderPort.lopShift = BranchPort.lopShift;
            DecoderPort.lopCmp = BranchPort.lopCmp;
            DecoderPort.lopAND = BranchPort.lopAND;
            DecoderPort.lopOR = BranchPort.lopOR;
            DecoderPort.lopXOR = BranchPort.lopXOR;
            DecoderPort.lopMUL = BranchPort.lopMUL;
            DecoderPort.lopDIV = BranchPort.lopDIV;
            DecoderPort.lopLoad = BranchPort.lopLoad;
            DecoderPort.lopStore = BranchPort.lopStore;
            DecoderPort.lopIllegal = BranchPort.lopIllegal;
            
            DecoderPort.opB = BranchPort.opB;
            DecoderPort.opH = BranchPort.opH;
            DecoderPort.opW = BranchPort.opW;
            DecoderPort.opD = BranchPort.opD;
            DecoderPort.opUnsigned = BranchPort.opUnsigned;
            DecoderPort.opArithmetic = BranchPort.opArithmetic;
            DecoderPort.opRightShift = BranchPort.opRightShift;
            DecoderPort.opHSU = BranchPort.opHSU;
            DecoderPort.opRemainder = BranchPort.opRemainder;
    
            DecoderPort.lrR = BranchPort.lrR;
            DecoderPort.lrI = BranchPort.lrI;
            DecoderPort.lrS = BranchPort.lrS;
            DecoderPort.lrB = BranchPort.lrB;
            DecoderPort.lrU = BranchPort.lrU;
            DecoderPort.lrJ = BranchPort.lrJ;
        end
        else if (LoadDec.Sel == 1'b1)
        begin
            DecoderPort.lopAdd = LoadStorePort.lopAdd;
            DecoderPort.lopShift = LoadStorePort.lopShift;
            DecoderPort.lopCmp = LoadStorePort.lopCmp;
            DecoderPort.lopAND = LoadStorePort.lopAND;
            DecoderPort.lopOR = LoadStorePort.lopOR;
            DecoderPort.lopXOR = LoadStorePort.lopXOR;
            DecoderPort.lopMUL = LoadStorePort.lopMUL;
            DecoderPort.lopDIV = LoadStorePort.lopDIV;
            DecoderPort.lopLoad = LoadStorePort.lopLoad;
            DecoderPort.lopStore = LoadStorePort.lopStore;
            DecoderPort.lopIllegal = LoadStorePort.lopIllegal;
            
            DecoderPort.opB = LoadStorePort.opB;
            DecoderPort.opH = LoadStorePort.opH;
            DecoderPort.opW = LoadStorePort.opW;
            DecoderPort.opD = LoadStorePort.opD;
            DecoderPort.opUnsigned = LoadStorePort.opUnsigned;
            DecoderPort.opArithmetic = LoadStorePort.opArithmetic;
            DecoderPort.opRightShift = LoadStorePort.opRightShift;
            DecoderPort.opHSU = LoadStorePort.opHSU;
            DecoderPort.opRemainder = LoadStorePort.opRemainder;
    
            DecoderPort.lrR = LoadStorePort.lrR;
            DecoderPort.lrI = LoadStorePort.lrI;
            DecoderPort.lrS = LoadStorePort.lrS;
            DecoderPort.lrB = LoadStorePort.lrB;
            DecoderPort.lrU = BranchPort.lrU;
            DecoderPort.lrJ = BranchPort.lrJ;
        end
        else if (ArithmeticDec.Sel == 1'b1)
        begin
            DecoderPort.lopAdd = ArithmeticPort.lopAdd;
            DecoderPort.lopShift = ArithmeticPort.lopShift;
            DecoderPort.lopCmp = ArithmeticPort.lopCmp;
            DecoderPort.lopAND = ArithmeticPort.lopAND;
            DecoderPort.lopOR = ArithmeticPort.lopOR;
            DecoderPort.lopXOR = ArithmeticPort.lopXOR;
            DecoderPort.lopMUL = ArithmeticPort.lopMUL;
            DecoderPort.lopDIV = ArithmeticPort.lopDIV;
            DecoderPort.lopLoad = ArithmeticPort.lopLoad;
            DecoderPort.lopStore = ArithmeticPort.lopStore;
            DecoderPort.lopIllegal = ArithmeticPort.lopIllegal;
            
            DecoderPort.opB = ArithmeticPort.opB;
            DecoderPort.opH = ArithmeticPort.opH;
            DecoderPort.opW = ArithmeticPort.opW;
            DecoderPort.opD = ArithmeticPort.opD;
            DecoderPort.opUnsigned = ArithmeticPort.opUnsigned;
            DecoderPort.opArithmetic = ArithmeticPort.opArithmetic;
            DecoderPort.opRightShift = ArithmeticPort.opRightShift;
            DecoderPort.opHSU = ArithmeticPort.opHSU;
            DecoderPort.opRemainder = ArithmeticPort.opRemainder;
    
            DecoderPort.lrR = ArithmeticPort.lrR;
            DecoderPort.lrI = ArithmeticPort.lrI;
            DecoderPort.lrS = ArithmeticPort.lrS;
            DecoderPort.lrB = ArithmeticPort.lrB;
            DecoderPort.lrU = BranchPort.lrU;
            DecoderPort.lrJ = BranchPort.lrJ;
        end
        else if (SystemDec.Sel == 1'b1)
        begin
            DecoderPort.lopAdd = SystemPort.lopAdd;
            DecoderPort.lopShift = SystemPort.lopShift;
            DecoderPort.lopCmp = SystemPort.lopCmp;
            DecoderPort.lopAND = SystemPort.lopAND;
            DecoderPort.lopOR = SystemPort.lopOR;
            DecoderPort.lopXOR = SystemPort.lopXOR;
            DecoderPort.lopMUL = SystemPort.lopMUL;
            DecoderPort.lopDIV = SystemPort.lopDIV;
            DecoderPort.lopLoad = SystemPort.lopLoad;
            DecoderPort.lopStore = SystemPort.lopStore;
            DecoderPort.lopIllegal = SystemPort.lopIllegal;
            
            DecoderPort.opB = SystemPort.opB;
            DecoderPort.opH = SystemPort.opH;
            DecoderPort.opW = SystemPort.opW;
            DecoderPort.opD = SystemPort.opD;
            DecoderPort.opUnsigned = SystemPort.opUnsigned;
            DecoderPort.opArithmetic = SystemPort.opArithmetic;
            DecoderPort.opRightShift = SystemPort.opRightShift;
            DecoderPort.opHSU = SystemPort.opHSU;
            DecoderPort.opRemainder = SystemPort.opRemainder;
    
            DecoderPort.lrR = SystemPort.lrR;
            DecoderPort.lrI = SystemPort.lrI;
            DecoderPort.lrS = SystemPort.lrS;
            DecoderPort.lrB = SystemPort.lrB;
            DecoderPort.lrU = SystemPort.lrU;
            DecoderPort.lrJ = SystemPort.lrJ;
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
        Sel = BranchDec.Sel | LoadDec.Sel | ArithmeticPort.Sel;
    end
endmodule