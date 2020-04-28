// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: Arithmetic Logic Unit
// Module Name: BasicALU
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A basic ALU relying on synthesis
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments:
// 
// The ALU pointedly does not complain about invalid input.  Don't send invalid input.
//
// ALU operations like MUL and DIV may use the ALU's other resources, such as bit
// shifts and masks, addition, or even the multiplier.  MUL and DIV consume adder
// resources for several cycles; additional ALUs are valuable in OOE and superscalar
// applications. 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype uwire

// Semantics of addressing all these things directly would cause large human error
`define lopAdd ALUPort.logicOp[0]
`define lopShift ALUPort.logicOp[1]
`define lopCmp ALUPort.logicOp[2]
`define lopAND ALUPort.logicOp[3]
`define lopOR ALUPort.logicOp[4]
`define lopXOR ALUPort.logicOp[5]
`define lopMUL ALUPort.logicOp[6]
`define lopDIV ALUPort.logicOp[7]

`define opB ALUPort.opFlags[0]
`define opH ALUPort.opFlags[1]
`define opW ALUPort.opFlags[2]
`define opD ALUPort.opFlags[3]
`define opUnS ALUPort.opFlags[4]
`define opAr ALUPort.opFlags[5]
`define opRSh ALUPort.opFlags[6]
`define opHSU ALUPort.opFlags[7]
`define opRem ALUPort.opFlags[8]

interface IALU
#(
    XLEN = 32
);
    logic Clk;
    logic insn[31:0];
    // data in and out
    logic rs1[XLEN-1:0];
    logic rs2[XLEN-1:0];
    logic rd[XLEN-1:0];
    // Exec stage cannot Strobe if Ready = 0
    uwire Ready;

    // -----------------------
    // -- Function Selector --
    // -----------------------
    // ALU ops
    // 0: add, sub: ADD, ADDI, SUB; 64 ADDW, ADDIW, SUBW
    // 1: shift: SLL, SLLI, SRL, SRLI, SRA; 64 SLLIW, SRRIW, SRAIW
    // 2: Comparator (SLT, SLTU, SLTI, SLTIU)
    // 3: AND: AND, ANDI
    // 4: OR: OR, ORI
    // 5: XOR: XOR, XORI
    //
    // Extension: M
    // 6: Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
    // 7: Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
    uwire logicOp[7:0];
    
    // Operation flags
    // bit 0:  *B
    // bit 1:  *H
    // bit 2:  *W
    // bit 3:  *D
    // bit 4:  Unsigned
    // bit 5:  Arithmetic (and Adder-Subtractor subtract)
    // bit 6:  Right-shift
    // bit 7:  MULHSU
    // bit 8:  DIV Remainder
    uwire opFlags[8:0];

    modport Pipeline
    (
        input rd,
        input Ready,
        output Clk,
        output insn,
        output logicOp,
        output opFlags
    );

    modport ALU
    (
        input Clk,
        input insn,
        input rs1,
        input rs2,
        input logicOp,
        input opFlags,
        output rd,
        output Ready
    );
endinterface

module BasicALU
#(
    XLEN = 32
)
(
    IALU.ALU ALUPort
);

    always_ff@(posedge ALUPort.Clk)
    begin
        if (`lopAdd == 1'b1 && `opAr == 1'b0)
            assign ALUPort.rd = ALUPort.rs1 + ALUPort.rs2;
        else if (`lopAdd == 1'b1 && `opAr == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 - ALUPort.rs2;
        // FIXME:  Shift, Comparator
        else if (`lopAND == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 & ALUPort.rs2;
        else if (`lopOR == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 | ALUPort.rs2;
        else if (`lopXOR == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 ^ ALUPort.rs2;
        // FIXME:  MUL, DIV
        // paravartya or quick-div
        
        // Divider obtains and caches the remainder and product to
        // catch the RISC-V M specified sequence:
        //   DIV[U] rdq, rs1, rs2
        //   REM[U] rdq, rs1, rs2
        // This sequence is fused together into a single divide.
        //
        // Various divider components are possible, e.g. Paravartya.
        // The ALU requires a divider implementation, as the DSP
        // does not provide one.
    end;
endmodule

`undef lopAdd
`undef lopShift
`undef lopCmp
`undef lopAND
`undef lopOR
`undef lopXOR
`undef lopMUL
`undef lopDIV

`undef opB
`undef opH
`undef opW
`undef opD
`undef opUnS
`undef opAr
`undef opRSh
`undef opHSU
`undef opRem