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
// Revision: 0.10
// Revision 0.10 - Configurable adder (inferred vs fabric types)
// Revision 0.01 - File Created
// Additional Comments:
// 
// The ALU pointedly does not complain about invalid input.  Don't send invalid input.
//
// MUL may use the ALU's other resources, including bi shifters and the adder.  MUL
// ties up the ALU for several cycles.
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

import Kerberos::*;

interface IALU
#(
    parameter XLEN = 2
);  
    logic [xlen2bits(XLEN)-1:0] A, B, rs1, rs2, rd;
    logic Equal, LessThan, LessThanUnsigned;
    
    // ----------------------
    // -- Logic Operations --
    // ----------------------
    // What operation

    // ALU ops
    // add, sub: ADD, ADDI, SUB; 64 ADDW, ADDIW, SUBW
    logic lopAdd = '0;
    // shift: SLL, SLLI, SRL, SRLI, SRA; 64 SLLIW, SRRIW, SRAIW
    logic lopShift = '0;
    // Comparator (SLT, SLTU, SLTI, SLTIU)
    logic lopCmp = '0;
    // AND: AND, ANDI
    logic lopAND = '0;
    // OR: OR, ORI
    logic lopOR = '0;
    // XOR: XOR, XORI
    logic lopXOR = '0;
    
    // Extension: M
    // Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
    logic lopMUL = '0;

    // --------------------
    // -- Operation Flags--
    // --------------------
    // Word sizes: Byte, Half, Word, Double
    logic opB = '0;
    logic opH = '0;
    logic opW = '0;
    logic opD = '0;
    // Unsigned
    logic opUnsigned = '0;
    // Arithmetic is also Adder-Subtractor subtract
    logic opArithmetic = '0;
    logic opRightShift = '0;
    // MULHSU and DIV Remainder REM
    logic opHSU = '0;
    logic opRemainder = '0;
    
    modport Client
    (
        // Computations
        output rs1,
        output rs2,

        output lopAdd,
        output lopShift,
        output lopCmp,
        output lopAND,
        output lopOR,
        output lopXOR,
        output lopMUL,

        output opB,
        output opH,
        output opW,
        output opD,
        output opUnsigned,
        output opArithmetic,
        output opRightShift,
        output opHSU,
        output opRemainder,

        input  rd,
        // Comparator
        output A,
        output B,
        input Equal,
        input LessThan,
        input LessThanUnsigned
    );
    
    modport ALU
    (
        input rs1,
        input rs2,

        input lopAdd,
        input lopShift,
        input lopCmp,
        input lopAND,
        input lopOR,
        input lopXOR,
        input lopMUL,

        input opB,
        input opH,
        input opW,
        input opD,
        input opUnsigned,
        input opArithmetic,
        input opRightShift,
        input opHSU,
        input opRemainder,

        output rd,

        input A,
        input B,
        output Equal,
        output LessThan,
        output LessThanUnsigned
    );
endinterface

module BasicALU
#(
    parameter XLEN = 2,
    parameter Adder = ADD_HAN_CARLSON_SPECULATIVE
)
(
    input uwire Clk,
    IALU.ALU ALUPort
);

    always_comb
    begin
        // Comparator port
        ALUPort.Equal = (ALUPort.A == ALUPort.B) ? 1'b1 : 1'b0;
        ALUPort.LessThan = (signed'(ALUPort.A) < signed'(ALUPort.B)) ? 1'b1 : 1'b0;
        ALUPort.LessThanUnsigned = (unsigned'(ALUPort.A) < unsigned'(ALUPort.B)) ? 1'b1 : 1'b0;

        // Bit ops
        if (ALUPort.lopAND == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 & ALUPort.rs2;
        else if (ALUPort.lopOR == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 | ALUPort.rs2;
        else if (ALUPort.lopXOR == 1'b1)
            assign ALUPort.rd = ALUPort.rs1 ^ ALUPort.rs2;
    end

    // -------------------------
    // -- Adder Configuration --
    // -------------------------
    generate
    if (Adder == ADD_INFERRED)
    begin
        always_ff@(posedge Clk)
        begin
            if (ALUPort.lopAdd == 1'b1 && ALUPort.opArithmetic == 1'b0)
                assign ALUPort.rd = ALUPort.rs1 + ALUPort.rs2;
            else if (ALUPort.lopAdd == 1'b1 && ALUPort.opArithmetic == 1'b1)
                assign ALUPort.rd = ALUPort.rs1 - ALUPort.rs2;
        end
    end
    else if (Adder == ADD_HAN_CARLSON_SPECULATIVE || Adder == ADD_HAN_CARLSON)
    begin
        // Speculative Han-Carlson Adder
        IAdder #(XLEN) IAdd();
        HanCarlsonAdder #(XLEN) HCAdder(.DataPort(IAdd.Adder));
    
        always_ff@(posedge Clk)
        begin
            if (ALUPort.lopAdd == 1'b1)
            begin
                IAdd.A = ALUPort.rs1;
                IAdd.B = ALUPort.rs2;
                IAdd.Sub = ALUPort.opArithmetic;
                IAdd.Speculate = (Adder == ADD_HAN_CARLSON_SPECULATIVE); // && context using speculative add
                // FIXME:  pass through adder busy signal
            end
        end
    end
    endgenerate

    // --------------------
    // -- Barrel Shifter --
    // --------------------
    IBarrelShifter #(XLEN) Ibs();
    BarrelShifter #(XLEN) bs(.Shifter(Ibs.Shifter));

    always_ff@(posedge Clk)
    begin
        if (ALUPort.lopShift == 1'b1)
        begin
            assign Ibs.Shifter.Din = ALUPort.rs1;
            assign Ibs.Shifter.Shift = ALUPort.rs2[$clog2(XLEN):0];
            assign Ibs.Shifter.opArithmetic = ALUPort.opArithmetic;
            assign Ibs.Shifter.opRightShift = ALUPort.opRightShift;
            assign ALUPort.rd = Ibs.Shifter.Dout;
        end
    end
        // FIXME:  MUL
endmodule