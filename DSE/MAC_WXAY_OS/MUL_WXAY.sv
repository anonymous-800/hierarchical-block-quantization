/*
    Low precision Vector MAC unit
    Modules:
        FP_WXAY_vector: Parameterized design for WXAYB design
        FP_mul_vector: Parameterized design for E2 FP multiplier, with converter to fixed point (FP2FX)
        ADDER_TREE_{B}: Adder tree module for different block size
*/

`include "params.vh"

module FP_WXAY_vector (
    input  wire                          clk,
    input  wire [Y*B-1:0]                ACT,
    input  wire [X*B-1:0]                WEIGHT,
    output reg  signed [PRODUCT_WIDTH+LEVEL-1:0] PSUM
);
    wire [PRODUCT_WIDTH*B-1:0] product;
    wire [PRODUCT_WIDTH+LEVEL-1:0] psum;

    FP_mul_vector mul (
        .WEIGHT(WEIGHT),
        .ACT(ACT),
        .PRODUCT(product)
    );

    generate
        if (B == 4) begin : adder_tree
            ADDER_TREE_4 adder_tree (
                .fixed_point_in(product),
                .sum(psum)
            );
        end
        else if (B == 8) begin : adder_tree
            ADDER_TREE_8  adder_tree (
                .fixed_point_in(product),
                .sum(psum)
            );
        end
        else if (B == 8) begin : adder_tree
            ADDER_TREE_8  adder_tree (
                .fixed_point_in(product),
                .sum(psum)
            );
        end
        else if (B == 16) begin : adder_tree
            ADDER_TREE_16  adder_tree (
                .fixed_point_in(product),
                .sum(psum)
            );
        end
        else if (B == 32) begin : adder_tree
            ADDER_TREE_32  adder_tree (
                .fixed_point_in(product),
                .sum(psum)
            );
        end
        else if (B == 64) begin : adder_tree
            ADDER_TREE_64  adder_tree (
                .fixed_point_in(product),
                .sum(psum)
            );
        end
        else if (B == 128) begin : adder_tree
            ADDER_TREE_128  adder_tree (
                .fixed_point_in(product),
                .sum(psum)
            );
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Register output
    // ------------------------------------------------------------------------
    always @(posedge clk)
        PSUM <= psum;
endmodule

module SYS_REG (
    input                     clk,
    input                     drain,
    input  [2:0]              mode,
    input  [Y*B-1:0]          act_vec,
    input  [X*B-1:0]          wgt_vec,
    input  [8*NUM_SUB_B-1:0]  scale_x,
    input  [8*NUM_SUB_B-1:0]  scale_w,

    output reg                   drain_out,
    output reg [2:0]             mode_out,
    output reg [Y*B-1:0]         act_vec_out,
    output reg [X*B-1:0]         wgt_vec_out,
    output reg [8*NUM_SUB_B-1:0] scale_x_out,
    output reg [8*NUM_SUB_B-1:0] scale_w_out
);
    always @(posedge clk) begin
        act_vec_out <= act_vec;
        wgt_vec_out <= wgt_vec;
        scale_x_out <= scale_x;
        scale_w_out <= scale_w;
        mode_out    <= mode;
        drain_out   <= drain;
    end
endmodule

/*
    FP multipliers and convert to fixed point, WXAY
*/
module FP_mul_vector (
    input  wire [X*B-1:0] WEIGHT,
    input  wire [Y*B-1:0] ACT,
    output wire [PRODUCT_WIDTH*B-1:0] PRODUCT
);

    localparam [1:0] FP4_EXP_BIAS = 2'b01;
    // ------------------------------------------------------------------------
    // Per-element fields (global [0:B-1] arrays)
    // ------------------------------------------------------------------------
    wire                act_s       [0:B-1];
    wire [1:0]          act_e_pre   [0:B-1];  // e2m5 for a8
    wire [Y-4:0]        act_m_pre   [0:B-1];  // e2m5 for a8
    wire                wgt_s       [0:B-1];
    wire [1:0]          wgt_e_pre   [0:B-1];  // e2m1 for w4
    wire [X-4:0]        wgt_m_pre   [0:B-1];  // e2m1 for w4

    wire [1:0]          act_e       [0:B-1];
    wire [1:0]          wgt_e       [0:B-1];
    wire [Y-3:0]        act_m       [0:B-1];  // add the leading 1 or 0
    wire [X-3:0]        wgt_m       [0:B-1];  // add the leading 1 or 0

    wire [(X-2)+(Y-2)-1:0]        p_raw       [0:B-1];    // unsigned product
    wire signed [(X-2)+(Y-2):0]   p_sgn       [0:B-1];    // signed product
    wire [2:0]          shamt       [0:B-1];    // 0-4 left-shift amount

    // ------------------------------------------------------------------------
    // Per-element combinational logic (only assign statements inside generate)
    // ------------------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign {act_s[g], act_e_pre[g], act_m_pre[g]} = ACT   [Y*g +: Y];
            assign {wgt_s[g], wgt_e_pre[g], wgt_m_pre[g]} = WEIGHT[X*g +: X];

            assign act_e[g] = (act_e_pre[g] == 2'b00) ? 2'b00 : act_e_pre[g] - FP4_EXP_BIAS; // FP4 subnormal exp = 0
            assign wgt_e[g] = (wgt_e_pre[g] == 2'b00) ? 2'b00 : wgt_e_pre[g] - FP4_EXP_BIAS; // FP4 subnormal exp = 0

            assign act_m[g] = { (act_e_pre[g] != 2'b00), act_m_pre[g] }; // leading 1 for normal, 0 for subnormal
            assign wgt_m[g] = { (wgt_e_pre[g] != 2'b00), wgt_m_pre[g] }; // leading 1 for normal, 0 for subnormal

            assign p_raw[g]  = act_m[g] * wgt_m[g];
            assign p_sgn[g]  = (act_s[g] ^ wgt_s[g]) ? -$signed({1'b0,p_raw[g]})
                                                     :  $signed({1'b0,p_raw[g]});
            assign shamt[g]  = act_e[g] + wgt_e[g];

            // FP product -> integer product
            assign PRODUCT[g*PRODUCT_WIDTH +: PRODUCT_WIDTH] = (shamt[g] == 3'd0) ? {{4{p_sgn[g][(X-2)*(Y-2)]}}, p_sgn[g]        } :
                                                               (shamt[g] == 3'd1) ? {{3{p_sgn[g][(X-2)*(Y-2)]}}, p_sgn[g], 1'b0  } :
                                                               (shamt[g] == 3'd2) ? {{2{p_sgn[g][(X-2)*(Y-2)]}}, p_sgn[g], 2'b0  } :
                                                               (shamt[g] == 3'd3) ? {{1{p_sgn[g][(X-2)*(Y-2)]}}, p_sgn[g], 3'b0  } :
                                                                                    {                            p_sgn[g], 4'b0  } ;
        end
    endgenerate

endmodule

module ADDER_TREE_4 (
    input  wire [PRODUCT_WIDTH*B-1:0]             fixed_point_in,
    output reg  signed [PRODUCT_WIDTH+LEVEL-1:0] sum
);
    // ------------------------------------------------------------------------
    // Arrange input into arrays
    // ------------------------------------------------------------------------
    wire [PRODUCT_WIDTH-1:0] in_arr [0:B-1];
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign in_arr[g] = fixed_point_in[PRODUCT_WIDTH*g +: PRODUCT_WIDTH];
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Adder-tree accumulation (each level +1 bit growth)
    // ------------------------------------------------------------------------
    // Level-0 : keep original PRODUCT_WIDTH bit terms
    wire signed [PRODUCT_WIDTH-1:0] lvl0 [0:B-1];
    generate
        for (g = 0; g < B; g = g + 1) begin : EXT
            assign lvl0[g] = in_arr[g];  // no extra sign-extension here
        end
    endgenerate

    // Level-1 : 4 ? 2 sums (PRODUCT_WIDTH+1 bit)
    wire signed [PRODUCT_WIDTH:0] lvl1 [0:1];
    assign lvl1[0] = lvl0[0] + lvl0[1];
    assign lvl1[1] = lvl0[2] + lvl0[3];

    // Level-2 : final PRODUCT_WIDTH+2 bit sum
    assign sum = lvl1[0] + lvl1[1];
endmodule

module ADDER_TREE_8 (
    input  wire [PRODUCT_WIDTH*B-1:0]             fixed_point_in,
    output reg  signed [PRODUCT_WIDTH+LEVEL-1:0] sum
);

    // ------------------------------------------------------------------------
    // Arrange input into arrays
    // ------------------------------------------------------------------------
    wire [PRODUCT_WIDTH-1:0] in_arr [0:B-1];
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign in_arr[g] = fixed_point_in[PRODUCT_WIDTH*g +: PRODUCT_WIDTH];
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Adder-tree accumulation (each level +1 bit growth)
    // ------------------------------------------------------------------------
    // Level-0 : keep original PRODUCT_WIDTH bit terms
    wire signed [PRODUCT_WIDTH-1:0] lvl0 [0:B-1];
    generate
        for (g = 0; g < B; g = g + 1) begin : EXT
            assign lvl0[g] = in_arr[g];  // no extra sign-extension here
        end
    endgenerate

    // Level-1 : 8 ? 4 sums (PRODUCT_WIDTH+1 bit)
    wire signed [PRODUCT_WIDTH:0] lvl1 [0:3];
    generate
        for (g = 0; g < 4; g = g + 1) begin : L1
            assign lvl1[g] = lvl0[2*g] + lvl0[2*g+1];
        end
    endgenerate

    // Level-2 : 4 ? 2 sums (PRODUCT_WIDTH+2 bit)
    wire signed [PRODUCT_WIDTH+1:0] lvl2 [0:1];
    assign lvl2[0] = lvl1[0] + lvl1[1];
    assign lvl2[1] = lvl1[2] + lvl1[3];

    // Level-3 : final PRODUCT_WIDTH+3 bit sum
    assign sum = lvl2[0] + lvl2[1];
endmodule

module ADDER_TREE_16 (
    input  wire [PRODUCT_WIDTH*B-1:0]             fixed_point_in,
    output reg  signed [PRODUCT_WIDTH+LEVEL-1:0] sum
);

    // ------------------------------------------------------------------------
    // Arrange input into arrays
    // ------------------------------------------------------------------------
    wire [PRODUCT_WIDTH-1:0] in_arr [0:B-1];
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign in_arr[g] = fixed_point_in[PRODUCT_WIDTH*g +: PRODUCT_WIDTH];
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Adder-tree accumulation (each level +1 bit growth)
    // ------------------------------------------------------------------------
    // Level-0 : keep original PRODUCT_WIDTH bit terms
    wire signed [PRODUCT_WIDTH-1:0] lvl0 [0:B-1];
    generate
        for (g = 0; g < B; g = g + 1) begin : EXT
            assign lvl0[g] = in_arr[g];  // no extra sign-extension here
        end
    endgenerate

    // Level-1 : 16 ? 8 sums (PRODUCT_WIDTH+1 bit)
    wire signed [PRODUCT_WIDTH:0] lvl1 [0:7];
    generate
        for (g = 0; g < 8; g = g + 1) begin : L1
            assign lvl1[g] = lvl0[2*g] + lvl0[2*g+1];
        end
    endgenerate

    // Level-2 : 8 ? 4 sums (PRODUCT_WIDTH+2 bit)
    wire signed [PRODUCT_WIDTH+1:0] lvl2 [0:3];
    generate
        for (g = 0; g < 4; g = g + 1) begin : L2
            assign lvl2[g] = lvl1[2*g] + lvl1[2*g+1];
        end
    endgenerate

    // Level-3 : 4 ? 2 sums (PRODUCT_WIDTH+3 bit)
    wire signed [PRODUCT_WIDTH+2:0] lvl3 [0:1];
    assign lvl3[0] = lvl2[0] + lvl2[1];
    assign lvl3[1] = lvl2[2] + lvl2[3];

    // Level-4 : final PRODUCT_WIDTH+4 bit sum
    assign sum = lvl3[0] + lvl3[1];
endmodule

module ADDER_TREE_32 (
    input  wire [PRODUCT_WIDTH*B-1:0]             fixed_point_in,
    output reg  signed [PRODUCT_WIDTH+LEVEL-1:0] sum
);

    // ------------------------------------------------------------------------
    // Arrange input into arrays
    // ------------------------------------------------------------------------
    wire [PRODUCT_WIDTH-1:0] in_arr [0:B-1];
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign in_arr[g] = fixed_point_in[PRODUCT_WIDTH*g +: PRODUCT_WIDTH];
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Adder-tree accumulation (each level +1 bit growth)
    // ------------------------------------------------------------------------
    // Level-0 : keep original PRODUCT_WIDTH bit terms
    wire signed [PRODUCT_WIDTH-1:0] lvl0 [0:B-1];
    generate
        for (g = 0; g < B; g = g + 1) begin : EXT
            assign lvl0[g] = in_arr[g];  // no extra sign-extension here
        end
    endgenerate

    // Level-1 : 32 ? 16 sums (PRODUCT_WIDTH+1 bit)
    wire signed [PRODUCT_WIDTH:0] lvl1 [0:15];
    generate
        for (g = 0; g < 16; g = g + 1) begin : L1
            assign lvl1[g] = lvl0[2*g] + lvl0[2*g+1];
        end
    endgenerate

    // Level-2 : 16 ? 8 sums (PRODUCT_WIDTH+2 bit)
    wire signed [PRODUCT_WIDTH+1:0] lvl2 [0:7];
    generate
        for (g = 0; g < 8; g = g + 1) begin : L2
            assign lvl2[g] = lvl1[2*g] + lvl1[2*g+1];
        end
    endgenerate

    // Level-3 : 8 ? 4 sums (PRODUCT_WIDTH+3 bit)
    wire signed [PRODUCT_WIDTH+2:0] lvl3 [0:3];
    generate
        for (g = 0; g < 4; g = g + 1) begin : L3
            assign lvl3[g] = lvl2[2*g] + lvl2[2*g+1];
        end
    endgenerate

    // Level-4 : 4 ? 2 sums (PRODUCT_WIDTH+4 bit)
    wire signed [PRODUCT_WIDTH+3:0] lvl4 [0:1];
    assign lvl4[0] = lvl3[0] + lvl3[1];
    assign lvl4[1] = lvl3[2] + lvl3[3];

    // Level-5 : final PRODUCT_WIDTH+5 bit sum
    assign sum = lvl4[0] + lvl4[1];
endmodule

module ADDER_TREE_64 (
    input  wire [PRODUCT_WIDTH*B-1:0]             fixed_point_in,
    output reg  signed [PRODUCT_WIDTH+LEVEL-1:0] sum
);

    // ------------------------------------------------------------------------
    // Arrange input into arrays
    // ------------------------------------------------------------------------
    wire [PRODUCT_WIDTH-1:0] in_arr [0:B-1];
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign in_arr[g] = fixed_point_in[PRODUCT_WIDTH*g +: PRODUCT_WIDTH];
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Adder-tree accumulation (each level +1 bit growth)
    // ------------------------------------------------------------------------
    // Level-0 : keep original PRODUCT_WIDTH bit terms
    wire signed [PRODUCT_WIDTH-1:0] lvl0 [0:B-1];
    generate
        for (g = 0; g < B; g = g + 1) begin : EXT
            assign lvl0[g] = in_arr[g];  // no extra sign-extension here
        end
    endgenerate

    // Level-1 : 64 ? 32 sums (PRODUCT_WIDTH+1 bit)
    wire signed [PRODUCT_WIDTH:0] lvl1 [0:31];
    generate
        for (g = 0; g < 32; g = g + 1) begin : L1
            assign lvl1[g] = lvl0[2*g] + lvl0[2*g+1];
        end
    endgenerate

    // Level-2 : 32 ? 16 sums (PRODUCT_WIDTH+2 bit)
    wire signed [PRODUCT_WIDTH+1:0] lvl2 [0:15];
    generate
        for (g = 0; g < 16; g = g + 1) begin : L2
            assign lvl2[g] = lvl1[2*g] + lvl1[2*g+1];
        end
    endgenerate

    // Level-3 : 16 ? 8 sums (PRODUCT_WIDTH+3 bit)
    wire signed [PRODUCT_WIDTH+2:0] lvl3 [0:7];
    generate
        for (g = 0; g < 8; g = g + 1) begin : L3
            assign lvl3[g] = lvl2[2*g] + lvl2[2*g+1];
        end
    endgenerate

    // Level-4 : 8 ? 4 sums (PRODUCT_WIDTH+4 bit)
    wire signed [PRODUCT_WIDTH+3:0] lvl4 [0:3];
    generate
        for (g = 0; g < 4; g = g + 1) begin : L4
            assign lvl4[g] = lvl3[2*g] + lvl3[2*g+1];
        end
    endgenerate

    // Level-5 : 4 ? 2 sums (PRODUCT_WIDTH+5 bit)
    wire signed [PRODUCT_WIDTH+4:0] lvl5 [0:1];
    assign lvl5[0] = lvl4[0] + lvl4[1];
    assign lvl5[1] = lvl4[2] + lvl4[3];

    // Level-6 : final PRODUCT_WIDTH+6 bit sum
    assign sum = lvl5[0] + lvl5[1];
endmodule

module ADDER_TREE_128 (
    input  wire [PRODUCT_WIDTH*B-1:0]             fixed_point_in,
    output reg  signed [PRODUCT_WIDTH+LEVEL-1:0] sum
);

    // ------------------------------------------------------------------------
    // Arrange input into arrays
    // ------------------------------------------------------------------------
    wire [PRODUCT_WIDTH-1:0] in_arr [0:B-1];
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign in_arr[g] = fixed_point_in[PRODUCT_WIDTH*g +: PRODUCT_WIDTH];
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Adder-tree accumulation (each level +1 bit growth)
    // ------------------------------------------------------------------------
    // Level-0 : keep original PRODUCT_WIDTH bit terms
    wire signed [PRODUCT_WIDTH-1:0] lvl0 [0:B-1];
    generate
        for (g = 0; g < B; g = g + 1) begin : EXT
            assign lvl0[g] = in_arr[g];  // no extra sign-extension here
        end
    endgenerate

    // Level-1 : 128 ? 64 sums (PRODUCT_WIDTH+1 bit)
    wire signed [PRODUCT_WIDTH:0] lvl1 [0:63];
    generate
        for (g = 0; g < 64; g = g + 1) begin : L1
            assign lvl1[g] = lvl0[2*g] + lvl0[2*g+1];
        end
    endgenerate

    // Level-2 : 64 ? 32 sums (PRODUCT_WIDTH+1 bit)
    wire signed [PRODUCT_WIDTH+1:0] lvl2 [0:31];
    generate
        for (g = 0; g < 32; g = g + 1) begin : L2
            assign lvl2[g] = lvl1[2*g] + lvl1[2*g+1];
        end
    endgenerate

    // Level-3 : 32 ? 16 sums (PRODUCT_WIDTH+2 bit)
    wire signed [PRODUCT_WIDTH+2:0] lvl3 [0:15];
    generate
        for (g = 0; g < 16; g = g + 1) begin : L3
            assign lvl3[g] = lvl2[2*g] + lvl2[2*g+1];
        end
    endgenerate

    // Level-4 : 16 ? 8 sums (PRODUCT_WIDTH+3 bit)
    wire signed [PRODUCT_WIDTH+3:0] lvl4 [0:7];
    generate
        for (g = 0; g < 8; g = g + 1) begin : L4
            assign lvl4[g] = lvl3[2*g] + lvl3[2*g+1];
        end
    endgenerate

    // Level-5 : 8 ? 4 sums (PRODUCT_WIDTH+4 bit)
    wire signed [PRODUCT_WIDTH+4:0] lvl5 [0:3];
    generate
        for (g = 0; g < 4; g = g + 1) begin : L5
            assign lvl5[g] = lvl4[2*g] + lvl4[2*g+1];
        end
    endgenerate

    // Level-6 : 4 ? 2 sums (PRODUCT_WIDTH+6 bit)
    wire signed [PRODUCT_WIDTH+5:0] lvl6 [0:1];
    assign lvl6[0] = lvl5[0] + lvl5[1];
    assign lvl6[1] = lvl5[2] + lvl5[3];

    // Level-7 : final PRODUCT_WIDTH+7 bit sum
    assign sum = lvl6[0] + lvl6[1];
endmodule

