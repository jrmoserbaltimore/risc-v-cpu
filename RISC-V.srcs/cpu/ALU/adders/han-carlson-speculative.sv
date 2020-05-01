// vim: sw=4 ts=4 et
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: John Moser
// 
// Create Date: 04/28/2020
// Design Name: Speculative Han-Carlson Adder
// Module Name: HanCarlsonAdder
// Project Name: RISC-V
// Target Devices: Xilinx 7-series
// Tool Versions: Vivado 2019.2.1
// Description: A speculative Han-Carlson adder
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

module HanCarlsonAdder
#(
    parameter XLEN = 32
)
(
    IAdder.Adder DataPort
);

    module GreyCell
    (
        input logic G,
        input logic P,
        input logic Gin,
        output logic Gout
    );
        assign Gout = G | (P & Gin);
    endmodule
    
    module BlackCell
    (
        input logic G,
        input logic P,
        input logic Gin,
        input logic Pin,
        output logic Gout,
        output logic Pout
    );
        GreyCell gc(G, P, Gin, Gout);
        assign Pout = P & Pin & Gin;
    endmodule

    localparam int LastStage = $clog2(XLEN);
    
    logic [XLEN-1:0] Subtrahend;
    logic [XLEN-1:0] SAccurate;
    logic [XLEN-1:0] SSpeculative;
    
    logic Error;

    // Row, G/P, Column
    // Center: 1 = G, 0 = P
    logic [LastStage:-1][1:0][XLEN-1:0] AdderTree;

    // -------------------
    // -- Setup Top Row --
    // -------------------
    //
    // This inverts B if necessary, generates the top row G/P, and incorporates Sub carry in

    // if Sub = 0, it remains an addend
    // Subtrahend = Dataport.Sub ? ~B : B;
    assign Subtrahend = DataPort.B ^ {(XLEN){DataPort.Sub}};

    // G across the top row
    assign AdderTree[-1][1][XLEN-1:1] = DataPort.A[XLEN-1:1] & Subtrahend[XLEN-1:1];
    // P across the top row
    assign AdderTree[-1][0][XLEN-1:1] = DataPort.A[XLEN-1:1] ^ Subtrahend[XLEN-1:1];
    
    // For the first bit, propagate a carry in from Cin.
    // This adds a stage, but avoids propagating Cin far across the adder.
    // G is a standard Grey sell , G=(A & B), P=(A XOR B), Gin=Sub (Carry In)
    //AdderTree[0][1][0] = (DataPort.A[0] & Subtrahend[0]) | ((DataPort.A[0] ^ Subtrahend[0]) & DataPort.Sub);
    GreyCell TwoComp(DataPort.A[0], Subtrahend[0], DataPort.Sub, AdderTree[-1][1][0]);
    // P is a bit more interesting:
    //   If A&B = 0, G becomes Sub from (A^B)&Sub if A|B=1.  P is also bit 0 of the result.
    //   We complete the addition by P^Sub to get the P bit feeding INTO the adder.
    //   This means bit 0 is A^B^Cin, and G (the generated carry!) is (A&B)|((A^B)&Cin), a full adder. G is
    //   Cout.  The sum also becomes the propogated carry.
    assign AdderTree[-1][0][0] = DataPort.A[0] ^ Subtrahend[0] ^ DataPort.Sub;

    // --------------------------
    // -- Parallel Prefix Tree --
    // --------------------------

    // Now to carry out the addition
    // The G tree generates the ultimate carry bit, but we ignore this because RISC-V has no carry flag
    generate
        genvar i, j;
        for (j = LastStage; j >= 0; j--)
        begin
            for (i = XLEN-1; i >= 0; i--)
            begin
                if (
                    // only on 0-base even bits (1 3 5...)
                    (i % 2 == 1)
                    // each successive stage reaches twice as far back
                    && ($floor(((i+1)/2)) > (2**j))
                   )
                begin
                    
                    // each successive stage reaches twice as far back
                    // Black cells
                    BlackCell b(
                        .G(AdderTree[j-1][1][i]),
                        .P(AdderTree[j-1][0][i]),
                        .Gin(AdderTree[j-1][1][i-(2**j)]),
                        .Pin(AdderTree[j-1][0][i-(2**j)]),
                        .Gout(AdderTree[j][1][i]),
                        .Pout(AdderTree[j][0][i])
                    );
                end
                else if (
                         (i % 2 == 1)
                         && ($floor(((i+1)/2)) <= (2**j))
                         && (i >= 2**j)
                        )
                begin
                    // The last in each row is a gray cell.  j stops before the last row, so
                    // we don't get double grey cells.
                    //
                    // Same as above, but all the furthest-LSB columns we skipped
                    GreyCell g(
                        .G(AdderTree[j-1][1][i]),
                        .P(AdderTree[j-1][0][i]),
                        .Gin(AdderTree[j-1][1][i-(2**j)]),
                        .Gout(AdderTree[j][1][i])
                    );
                    // Pass down the propagate carry
                    assign AdderTree[j][0][i] = AdderTree[j-1][0][i];
                end // i % 2 == 1
                else if (
                         (i % 2 == 0)
                         && (j == LastStage)
                         && (i > 0)
                        )
                begin
                    // All the last row cells that go directly one bit over
                    GreyCell g(
                        .G(AdderTree[j-1][1][i]),
                        .P(AdderTree[j-1][0][i]),
                        .Gin(AdderTree[j-1][1][i-1]),
                        .Gout(AdderTree[j][1][i])
                    );
                    // Pass down the propagate carry
                    assign AdderTree[j][0][i] = AdderTree[j-1][0][i];
                end // i % 2 == 0
                else if (
                         (
                          (
                           (i < 2**j)
                           || (i % 2 == 0)
                          )
                          && (j < LastStage)
                         )
                         ||
                         (
                          ((i % 2 == 1) || (i == 0))
                          && (j == LastStage)
                         )
                        )
                begin
                    // This fills in the rest of the areas without cells
                    assign AdderTree[j][1][i] = AdderTree[j-1][1][i];
                    assign AdderTree[j][0][i] = AdderTree[j-1][0][i];
                end // Fill empty cells
            end // for i
        end // for j

        // --------------------
        // -- Accurate Stage --
        // --------------------
        //
        // The lower half of the speculative stage is always correct
        assign SAccurate[XLEN/2-1:0] = SSpeculative[XLEN/2-1:0];
        
        for (i = XLEN-1; i >= XLEN/2; i--)
        begin
            // XOR prior bit's generated with current bit's originated propogated carry
            assign SAccurate[i] = AdderTree[LastStage][1][i-1] ^ AdderTree[-1][0][i];
        end

        // -----------------------
        // -- Speculative Stage --
        // -----------------------

        logic [XLEN-1:0] SpeculateG;
        for (i = XLEN-1; i >= 0; i--)
        begin
            if ((i % 2 == 0) && i > 0)
            begin
                // Skip to the second to last row
                GreyCell s(
                    .G(AdderTree[LastStage-2][1][i]),
                    .P(AdderTree[LastStage-2][0][i]),
                    .Gin(AdderTree[LastStage-2][1][i-1]),
                    .Gout(SpeculateG[i])
                );
            end
            else if ((i % 2 == 1) || i == 0)
            begin
                // pass down 
                assign SpeculateG[i] = AdderTree[LastStage-2][1][i];
            end
            if (i > 0)
            begin
                // Generate speculative outcome
                assign SSpeculative[i] = SpeculateG[i-1] ^ AdderTree[-1][0][i];
            end
        end
        // Bit zero is just the propagated carry from A0+B0
        assign SSpeculative[0] = AdderTree[-1][0][0];

        // ---------------------
        // -- Error Detection --
        // ---------------------
        logic [XLEN/4-1:0] ErrorCalc;
        for (i = XLEN/4; i >= 1; i--)
        begin
            assign ErrorCalc[i-1] = AdderTree[LastStage-2][1][2**i - 1] & AdderTree[LastStage-2][0][2**i + XLEN/2 - 1];
        end
        // OR them all together
        assign Error = |ErrorCalc;
    endgenerate

    assign DataPort.Error = Error;     
    // The circuit using the adder must check for Error and, if found,
    // delay for an extra cycle
    always_comb
    begin
        if (Error == 1'b1)
        begin
            DataPort.S = SAccurate;
        end
        else
        begin
            DataPort.S = SSpeculative;
        end
    end
endmodule
