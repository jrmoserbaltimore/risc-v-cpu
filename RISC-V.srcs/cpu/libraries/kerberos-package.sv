// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 05/16/2020
// Design Name: Kerberos Package
// Module Name: 
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: Package for Kerberos
// 
// Dependencies: 
// 
// License:  MIT, 7-year CC0
// 
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

package Kerberos;

    typedef enum
    {
        ADD_INFERRED,
        ADD_HAN_CARLSON,
        ADD_HAN_CARLSON_SPECULATIVE,
        ADD_DSP48
    } adder_type;
    
    typedef enum
    {
        ALU_BASIC,
        ALU_FABRIC,
        ALU_DSP48
    } alu_type;
    typedef enum
    {
        DIV_QUICKDIV,
        DIV_PARAVARTYA
    } divider_type;
    
    typedef enum
    {
        CACHE_NCOR
    } cache_type;
    
    typedef enum
    {
        CACHE_VIVT
    } cache_indexing;
    
    // All smaller widths supported implicitly
    typedef enum
    {
        FPU_NONE,
        FPU_F,
        FPU_D,
        FPU_Q
    } fpu_type;
    
    typedef enum
    {
        A_NONE,
        A_ATOMIC,
        A_ZAM
    } atomic_type;

    // -----------------
    // -- Instruction --
    // -----------------

    // Register
    typedef struct packed
    {
        logic [6:0] funct7;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } instruction_r_t;

    // Immediate
    typedef struct packed
    {
        logic [11:0] imm;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } instruction_i_t;

    // Store
    // XXX:  Can't actually do this.
//    typedef struct packed
//    {
//        logic [11:5] imm;
//        logic [4:0] rs1;
//        logic [2:0] funct3;
//        logic [4:0] imm;
//        logic [6:0] opcode;
//    } opcode_s_t;

    // XXX:  Can't branch, no opcode_b_t;

    // Upper immediate
    typedef struct packed
    {
        logic [31:12] imm;
        logic [4:0] rd;
        logic [6:0] opcode;
    } instruction_u_t;

    // XXX:  Can't jump, no opcode_j_t;

    typedef union packed
    {
        logic [31:0] insn;
        instruction_r_t r;
        instruction_i_t i;
        instruction_u_t u;
    } instruction_t;

    // get s-type immediate; use opcode_t.r to get other fields
    function logic[11:0] instruction_s_imm(instruction_t insn);
        return {insn.insn[31:25], insn.insn[11:7]};
    endfunction

    // get b-type immediate
    function logic[12:1] instruction_b_imm(instruction_t insn);
        return {insn.insn[31], insn.insn[7], insn.insn[30:25], insn.insn[11:8]};
    endfunction

    // get j-type immediate
    function logic[20:1] instruction_j_imm(instruction_t insn);
        return {insn.insn[31], insn.insn[19:12], insn.insn[20], insn.insn[30:21]};
    endfunction

    // -------------------------
    // -- Decoded Information --
    // -------------------------

    // ----------------------
    // -- Logic Operations --
    // ----------------------
    // What operation
    typedef struct packed
    {
        // ALU ops
        // add, sub: ADD, ADDI, SUB; 64 ADDW, ADDIW, SUBW
        logic Add;
        // shift: SLL, SLLI, SRL, SRLI, SRA; 64 SLLIW, SRRIW, SRAIW
        logic Shift;
        // Comparator (SLT, SLTU, SLTI, SLTIU)
        logic Cmp;
        // AND: AND, ANDI
        logic AND;
        // OR: OR, ORI
        logic OR;
        // XOR: XOR, XORI
        logic XOR;

        // Extension: M
        // Multiplier: MUL, MULH, MULHSU, MULHU; 64 MULW 
        logic MUL;
        // Divider: DIV, DIVU, REM, REMU; 64 DIVW, DIVUW, REMW, REMUW
        logic DIV;
        
        // Non-ALU ops
        // Load/Store
        logic Load;
        logic Store;
        // Branch decodes from funct3
        logic Branch;
        // System
        logic Fence;
        logic SysCall;
        logic SysBreak;
        // illegal instruction
        logic Illegal;
    } logic_ops_t; // 15 ops

    // --------------------
    // -- Operation Flags--
    // --------------------
    typedef struct packed
    {
        // Word sizes: Byte, Half, Word, Double
        logic B;
        logic H;
        logic W;
        logic D;
        // Unsigned
        logic Unsigned;
        // Arithmetic is also Adder-Subtractor subtract
        logic Arithmetic;
        logic RightShift;
        // MULHSU and DIV Remainder REM
        logic HSU;
        logic Remainder;
    } logic_ops_flags_t; // 9 flags

    typedef struct packed
    {
        // Load resource:   Type        what to load
        // bit 0:  R-type   Register    (rs1, rs2)
        logic R;
        // bit 1:  I-type   Immediate   (rs1, insn[31:20] sign-extend)
        logic I;
        // bit 2:  S-Type   Store       (rs1, insn[31:25] insn[11:7] sign-extended)
        logic S;
        // bit 3:  B-type   Branch      (rs1, rs2, insn[31] insn[7] insn[30:25] insn[11:8] sign-extend)
        logic B;
        // bit 4:  U-type   Upper-Imm   (insn[31:12])
        logic U;
        // bit 5:  J-type   Jump        (insn[31] insn[19:12] insn[20] insn[30:21] sign-extend)
        logic J;
    } instruction_format_t; // 6 instruction types
    
    typedef struct packed
    {
        logic_ops_t ops;
        logic_ops_flags_t flags;
        instruction_format_t load_resource;
    } logic_ops_group_t;

    typedef union packed
    {
        logic[$bits(logic_ops_group_t)-1:0] bitfield;
        logic_ops_group_t ops;
    } decode_data_t;

    // -------------
    // -- Context --
    // -------------

    // misa flags
    typedef struct packed
    {
        // top 2 most significant bits
        logic [1:0] mxl;

        // Unassigned
        logic Z;
        logic Y;

        logic X; // Non-standard extensions

        // Unassigned
        logic W;
        logic V;

        logic U; // User

        // Unassigned
        logic T;

        logic S; // Supervisor

        // Unassigned
        logic R;

        logic Q; // Quad-float

        // Unassigned
        logic P;
        logic O;

        logic N; // User-level interrupts
        logic M; // MUL/DIV

        // Unassigned
        logic L;
        logic K;
        logic J;

        logic I; // RVI
        logic H; // Hypervisor

        // Unassigned
        logic G;

        logic F; // Single-float
        logic E; // RVE, ~I
        logic D; // Double-float

        logic C; // Compressed

        // Unassigned
        logic B;

        logic A; // Atomic
    } misa_flags_t;

    typedef union packed
    {
        logic[$bits(misa_flags_t)-1:0] bitmask;
        misa_flags_t misa;
    } misa_t;

    // ---------------
    // -- Functions --
    // ---------------
    function int xlen2bits(input int xlen);
        assert(xlen > 0 && xlen < 4);
        return 16 << xlen;
    endfunction;
endpackage