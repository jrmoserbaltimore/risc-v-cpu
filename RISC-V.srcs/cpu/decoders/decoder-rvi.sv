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
// Description: A RISC-V Decoder
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

// Semantics of addressing all these things directly would cause large human error
`define lopAdd DecoderPort.logicOp[0]
`define lopShift DecoderPort.logicOp[1]
`define lopCmp DecoderPort.logicOp[2]
`define lopAND DecoderPort.logicOp[3]
`define lopOR DecoderPort.logicOp[4]
`define lopXOR DecoderPort.logicOp[5]
`define lopMUL DecoderPort.logicOp[6]
`define lopDIV DecoderPort.logicOp[7]
`define lopIll DecoderPort.logicOp[8]
`define lopLoad DecoderPort.logicOp[9]
`define lopStore DecoderPort.logicOp[10]

`define opB DecoderPort.opFlags[0]
`define opH DecoderPort.opFlags[1]
`define opW DecoderPort.opFlags[2]
`define opD DecoderPort.opFlags[3]
`define opUnS DecoderPort.opFlags[4]
`define opAr DecoderPort.opFlags[5]
`define opRSh DecoderPort.opFlags[6]
`define opHSU DecoderPort.opFlags[7]
`define opRem DecoderPort.opFlags[8]

`define lrR DecoderPort.loadResource[0]
`define lrI DecoderPort.loadResource[1]
`define lrS DecoderPort.loadResource[2]
`define lrB DecoderPort.loadResource[3]
`define lrU DecoderPort.loadResource[4]
`define lrJ DecoderPort.loadResource[5]
`define lrUPC DecoderPort.loadResource[6]

module RVIDecoderTable
(
    IDecoder.DecoderTable DecoderPort
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
        IDecoder.DecoderTable DecoderPort
    );
        always_comb
        begin
            DecoderPort.logicOp = '0;
            DecoderPort.opFlags = '0;
            DecoderPort.loadResource = '0;
            DecoderPort.Sel = 1'b0;
            if (
                ((opcode & 7'b1100011) == 7'b1100011)
                && opcode[4] == 1'b0
                // && opcode [3:2] != 2'b10 // Unnecessary due to no check for this one
               )
            begin
                // Definitely a Branch/JAL/JALR opcode
                if (opcode[3:2] == 2'b11)
                begin
                    // J-type JAL
                    DecoderPort.Sel = 1'b1;
                    `lrJ = 1'b1;
                end
                else if (opcode[3:2] == 2'b00 && funct3[2:1] != 2'b01)
                begin
                    // B-type Branch opcode; funct3 cannot be 010 or 011
                    DecoderPort.Sel = 1'b1;
                    `lrB = 1'b1;
                end
                else if (opcode[3:2] == 2'b01 && funct3 == 3'b000)
                begin
                    // I-type JALR
                    DecoderPort.Sel = 1'b1;
                    // I-type JALR
                    `lrI = 1'b1;
                end
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
        IDecoder.DecoderTable DecoderPort
    );
        always_comb
        begin
            DecoderPort.logicOp = '0;
            DecoderPort.opFlags = '0;
            DecoderPort.loadResource = '0;
            DecoderPort.Sel = 1'b0;
            if (
                   ((opcode | 7'b0100000) == 7'b0100011) // Load/Store
                || (opcode == 7'b0110111) // LUI
                || (opcode == 7'b0010111) // AUIPC
               )
            begin
                if ((opcode[5] == 1'b1) && (funct3[2] == 1'b1))
                    // Illegal instruction
                    `lopIll = 1'b1;
                else
                begin
                    case (opcode)
                    // Load/Store
                        7'b0000011 || 7'b0100011:
                        begin
                            // LWU is also "110"
                            `opUnS = funct3[2];
                            //64-bit LD/SD
                            `opD = funct3[1] & funct3[0];
                            // 32-bit LD/ST
                            `opW = funct3[1] & ~`opD;
                            `opH = funct3[0] & ~`opD;
                            // Operation load/store
                            `lopLoad  = ~opcode[5];
                            `lopStore = opcode[5];
                            `lrI      = `lopLoad;
                            `lrS      = `lopStore;
                        end
                        7'b0110111 || 7'b0010111:
                        begin
                            // LUI/AUIPC
                            `lopLoad = 1'b1;
                            // U or UPC type?
                            `lrU     = opcode[5];
                            `lrUPC   = ~opcode[5];
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
        IDecoder.DecoderTable DecoderPort
    );
        always_comb
        begin
            DecoderPort.logicOp = '0;
            DecoderPort.opFlags = '0;
            DecoderPort.loadResource = '0;
            DecoderPort.Sel = 1'b0;
            // Not RVI Arithmetic if these aren't met
            if (
                ((opcode & 7'b0010011) == 7'b0010011) // These bits on
                && ((opcode & 7'b1000100) == 7'b0000000) // These bits off
                     // Essential mask 0_1_011
                && ((funct7 & 7'b1011111) == 7'b0000000)
               )
            begin
                // extract W and I bits
                `opW = opcode[3];
                `opAr = funct7[5];
                
                // Arithmetic bit doesn't go to output for SUB
                `lrR = opcode[5]; // R-type
                `lrI = ~opcode[5]; // I-type 
                // Check for illegal instruction
                if (
                       ( (`opAr == 1'b1) && (funct3 != 3'b000) && (funct3 != 3'b101) ) // not SUB or SRA
                    || ( (`lrI == 1'b1) && (funct3 == 3'b000) ) // SUBI isn't an opcode
                    || ( (`opW == 1'b1) && (
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
                    `lopIll = 1'b1;
                    DecoderPort.Sel = 1'b0;
                end
                else
                begin
                    // Decode funct3
                    case (funct3)
                        3'b000:
                            // lrA determins add or subtract as per table above
                            `lopAdd = 1'b1;
                        3'b001 || 3'b101:
                        begin
                            `lopShift = 1'b1;
                            // assign opAr = funct7(5); // Done above
                            // Right shift
                            `opRSh = (funct3 == 3'b101) ? 1'b1 : 1'b0;
                        end
    
                        3'b010 || 3'b011:
                        begin
                            `lopCmp = 1'b1;
                            `opUnS = (funct3 == 3'b011) ? 1'b1 : 1'b0;
                        end
    
                    3'b100:
                        `lopXOR = 1'b1;
                    3'b110:
                        `lopOR = 1'b1;
                    3'b111:
                        `lopAND = 1'b1;
                    endcase
                end 
            end
            else
                DecoderPort.Sel = 1'b0;
        end
    endmodule

    DecoderPort BranchPort();
    DecoderPort LoadStorePort();
    DecoderPort ArithmeticPort();

    Branch BranchDec(.DecoderPort(BranchPort));
    LoadStore LoadDec(.DecoderPort(LoadStorePort));
    Arithmetic ArDec(.DecoderPort(ArithmeticPort));

    always_comb
    begin
        // 4:1 mux
        if (BranchDec.Sel == 1'b1)
        begin
            DecoderPort.logicOp = BranchPort.logicOp;
            DecoderPort.opFlags = BranchPort.opFlags;
            DecoderPort.loadResource = BranchPort.loadResource;
        end
        else if (LoadStorePort.Sel == 1'b1)
        begin
            DecoderPort.logicOp = LoadStorePort.logicOp;
            DecoderPort.opFlags = LoadStorePort.opFlags;
            DecoderPort.loadResource = LoadStorePort.loadResource;
        end
        else if (ArithmeticPort.Sel == 1'b1)
        begin
            DecoderPort.logicOp = ArithmeticPort.logicOp;
            DecoderPort.opFlags = ArithmeticPort.opFlags;
            DecoderPort.loadResource = ArithmeticPort.loadResource;
        end
        else
        begin
            DecoderPort.logicOp = '0;
            DecoderPort.opFlags = '0;
            DecoderPort.loadResource = '0;
            // Illegal…instruction?  No you're not going to jail, do not unplug...!
            // We're not raising Sel anyway
            // `lopIll = 1'b1;
        end
        
        // Only raise Sel if we decoded an instruction 
        DecoderPort.Sel = BranchPort.Sel + LoadStorePort.Sel + ArithmeticPort.Sel;
    end
endmodule