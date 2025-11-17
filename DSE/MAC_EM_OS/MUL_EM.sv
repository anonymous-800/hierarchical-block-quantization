/*
    Low precision Vector MAC unit
    Modules:
        FP_W4A8_vector: Parameterized design for WXAYB design
        FP8_4_vector_e4m3: Parameterized design for E2 FP multiplier, with converter to fixed point
        ADDER_TREE_{B}: Adder tree module for different block size
*/
`include "params.vh"

module FP_W4A8_vector (
    input  wire                          clk,
    input  wire [Y*B-1:0]                ACT,
    input  wire [X*B-1:0]                WEIGHT,
    output reg  signed [PRODUCT_WIDTH+LEVEL-1:0] PSUM
);
    wire [PRODUCT_WIDTH*B-1:0] product;
    wire [PRODUCT_WIDTH+LEVEL-1:0] psum;

    generate
        if (E == 2) begin : mul
            FP8_4_vector_e2m5  mul (
                .WEIGHT(WEIGHT),
                .ACT(ACT),
                .PRODUCT(product)
            );
        end
        else if (E == 3) begin : mul
            FP8_4_vector_e3m4  mul (
                .WEIGHT(WEIGHT),
                .ACT(ACT),
                .PRODUCT(product)
            );
        end
        else if (E == 4) begin : mul
            FP8_4_vector_e4m3  mul (
                .WEIGHT(WEIGHT),
                .ACT(ACT),
                .PRODUCT(product)
            );
        end
        else if (E == 5) begin : mul
            FP8_4_vector_e5m2  mul (
                .WEIGHT(WEIGHT),
                .ACT(ACT),
                .PRODUCT(product)
            );
        end
    endgenerate

    generate
        if (B == 4) begin : adder_tree
            ADDER_TREE_4  adder_tree (
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

/*
    FP multipliers and convert to fixed point, WXAY
*/

module FP8_4_vector_e2m5 (
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

    wire [(X-2)+(Y-2)-1:0]        p_raw       [0:B-1];    // unsigned 8-bit product, 6bit * 2bit
    wire signed [(X-2)+(Y-2):0]   p_sgn       [0:B-1];    // signed 9-bit product
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

module FP8_4_vector_e3m4 (
    input  wire [8*B-1:0]           ACT,
    input  wire [4*B-1:0]           WEIGHT,  
    output reg  signed [16*B-1:0]   PRODUCT
);

    localparam [1:0] FP4_EXP_BIAS = 2'b01;   // 1
    localparam [2:0] FP8_EXP_BIAS = 3'b011;  // 3
    // ------------------------------------------------------------------------
    // Per-element fields (global [0:B-1] arrays)
    // ------------------------------------------------------------------------
    wire               act_s       [0:B-1];
    wire [2:0]         act_e_pre   [0:B-1]; // e3m4 for a8
    wire [3:0]         act_m_pre   [0:B-1]; // e3m4 for a8
    wire               wgt_s       [0:B-1];
    wire [1:0]         wgt_e_pre   [0:B-1]; // e2m1 for w4
    wire               wgt_m_pre   [0:B-1]; // e2m1 for w4

    wire signed [3:0]  act_e       [0:B-1]; // range: -2 ~ 4. originally 0 ~ 7, but subtract 3, and exclude -3.
    wire [1:0]         wgt_e       [0:B-1]; // range: 0 ~ 2. originally 0 ~ 3, but subtract 1, and exlcude -1.
    wire [4:0]         act_m       [0:B-1]; // add the leading 1 or 0
    wire [1:0]         wgt_m       [0:B-1]; // add the leading 1 or 0

    wire [6:0]         p_raw       [0:B-1];      // unsigned 7-bit product, 5bit * 2bit
    wire signed [7:0]  p_sgn       [0:B-1];      // signed 8-bit product
    wire [3:0]         shift_left_amount       [0:B-1];      // 0-8 left-shift amount
    wire [3:0]         shift_right_amount      [0:B-1];      // 0-8 right-shift amount
    wire signed [15:0] p_shift     [0:B-1];      // shifted, signed 13-bit term, decimal point at bit 2

    // ------------------------------------------------------------------------
    // Per-element combinational logic (only assign statements inside generate)
    // ------------------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign {act_s[g], act_e_pre[g], act_m_pre[g]} = ACT   [8*g +: 8];
            assign {wgt_s[g], wgt_e_pre[g], wgt_m_pre[g]} = WEIGHT[4*g +: 4];

            // act exp: -2 ~ 4, wgt exp: 0 ~ 2
            assign act_e[g] = (act_e_pre[g] == 4'b0000) ? -4'sd2 : $signed({1'b0, act_e_pre[g]}) - $signed({1'b0, FP8_EXP_BIAS}); // E3 subnormal exp = -2
            assign wgt_e[g] = (wgt_e_pre[g] == 2'b00) ? 2'b00 : wgt_e_pre[g] - FP4_EXP_BIAS; // FP4 subnormal exp = 0

            assign act_m[g] = { (act_e_pre[g] != 3'b000), act_m_pre[g] }; // leading 1 for normal, 0 for subnormal
            assign wgt_m[g] = { (wgt_e_pre[g] != 2'b00), wgt_m_pre[g] }; // leading 1 for normal, 0 for subnormal

            assign p_raw[g]  = act_m[g] * wgt_m[g]; // 1.x * 1.xxxx
            assign p_sgn[g]  = (act_s[g] ^ wgt_s[g]) ? -$signed({1'b0,p_raw[g]})
                                                     :  $signed({1'b0,p_raw[g]});
            assign shift_left_amount[g] = act_e[g] + 2 + wgt_e[g]; // 0 ~ 8
            assign shift_right_amount[g] = 8 - shift_left_amount[g];

            // FP product -> integer product with implicit scale 2^-10
            assign p_shift[g] = (shift_right_amount[g] == 8) ?  $signed({p_sgn[g], 8'd0}) >>> 8 : // avoid using 4 bit shifter
                                                                $signed({p_sgn[g], 8'd0}) >>> shift_right_amount[g][2:0];
            assign PRODUCT[g*16 +: 16] = p_shift[g];
        end
    endgenerate

endmodule


module FP8_4_vector_e4m3 (
    input  wire [8*B-1:0]           ACT,
    input  wire [4*B-1:0]           WEIGHT,  
    output reg  signed [23*B-1:0]   PRODUCT
);

    localparam [1:0] FP4_EXP_BIAS = 2'b01;   // 1
    localparam [3:0] FP8_EXP_BIAS = 4'b0111; // 7
    // ------------------------------------------------------------------------
    // Per-element fields (global [0:B-1] arrays)
    // ------------------------------------------------------------------------
    wire               act_s       [0:B-1];
    wire [3:0]         act_e_pre   [0:B-1]; // e4m3 for a8
    wire [2:0]         act_m_pre   [0:B-1]; // e4m3 for a8
    wire               wgt_s       [0:B-1];
    wire [1:0]         wgt_e_pre   [0:B-1]; // e2m1 for w4
    wire               wgt_m_pre   [0:B-1]; // e2m1 for w4

    wire signed [4:0]  act_e       [0:B-1]; // range: -6 ~ 8. originally 0 ~ 15, but subtract 7, and exclude -7.
    wire [1:0]         wgt_e       [0:B-1]; // range: 0 ~ 2. originally 0 ~ 3, but subtract 1, and exlcude -1.
    wire [3:0]         act_m       [0:B-1]; // add the leading 1 or 0
    wire [1:0]         wgt_m       [0:B-1]; // add the leading 1 or 0

    wire [5:0]         p_raw       [0:B-1];      // unsigned 6-bit product, 4bit * 2bit
    wire signed [6:0]  p_sgn       [0:B-1];      // signed 7-bit product
    wire [4:0]         shift_left_amount       [0:B-1];      // 0-16 left-shift amount
    wire [4:0]         shift_right_amount      [0:B-1];      // 0-16 right-shift amount
    wire signed [22:0] p_shift     [0:B-1];      // shifted, signed 13-bit term, decimal point at bit 2

    // ------------------------------------------------------------------------
    // Per-element combinational logic (only assign statements inside generate)
    // ------------------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign {act_s[g], act_e_pre[g], act_m_pre[g]} = ACT   [8*g +: 8];
            assign {wgt_s[g], wgt_e_pre[g], wgt_m_pre[g]} = WEIGHT[4*g +: 4];

            // act exp: -6 ~ 8, wgt exp: 0 ~ 2
            assign act_e[g] = (act_e_pre[g] == 4'b0000) ? -5'sd6 : $signed({1'b0, act_e_pre[g]}) - $signed({1'b0, FP8_EXP_BIAS}); // E4 subnormal exp = -6
            assign wgt_e[g] = (wgt_e_pre[g] == 2'b00) ? 2'b00 : wgt_e_pre[g] - FP4_EXP_BIAS; // FP4 subnormal exp = 0

            assign act_m[g] = { (act_e_pre[g] != 4'b0000), act_m_pre[g] }; // leading 1 for normal, 0 for subnormal
            assign wgt_m[g] = { (wgt_e_pre[g] != 2'b00), wgt_m_pre[g] }; // leading 1 for normal, 0 for subnormal

            assign p_raw[g]  = act_m[g] * wgt_m[g]; // 1.x * 1.xxx
            assign p_sgn[g]  = (act_s[g] ^ wgt_s[g]) ? -$signed({1'b0,p_raw[g]})
                                                     :  $signed({1'b0,p_raw[g]});
            assign shift_left_amount[g] = act_e[g] + 6 + wgt_e[g]; // 0 ~ 16
            assign shift_right_amount[g] = 16 - shift_left_amount[g];

            // FP product -> integer product with implicit scale 2^-10
            assign p_shift[g] = (shift_right_amount[g] == 16) ? $signed({p_sgn[g], 16'd0}) >>> 16 : // avoid using 5 bit shifter
                                                                $signed({p_sgn[g], 16'd0}) >>> shift_right_amount[g][3:0];
            assign PRODUCT[g*23 +: 23] = p_shift[g];
        end
    endgenerate

endmodule

module FP8_4_vector_e5m2 (
    input  wire [8*B-1:0]           ACT,
    input  wire [4*B-1:0]           WEIGHT,  
    output reg  signed [38*B-1:0]   PRODUCT
);

    localparam [1:0] FP4_EXP_BIAS = 2'b01;   // 1
    localparam [4:0] FP8_EXP_BIAS = 5'b01111; // 15
    // ------------------------------------------------------------------------
    // Per-element fields (global [0:B-1] arrays)
    // ------------------------------------------------------------------------
    wire               act_s       [0:B-1];
    wire [4:0]         act_e_pre   [0:B-1]; // e5m2 for a8
    wire [1:0]         act_m_pre   [0:B-1]; // e5m2 for a8
    wire               wgt_s       [0:B-1];
    wire [1:0]         wgt_e_pre   [0:B-1]; // e2m1 for w4
    wire               wgt_m_pre   [0:B-1]; // e2m1 for w4

    wire signed [5:0]  act_e       [0:B-1]; // range: -14 ~ 16. originally 0 ~ 31, but subtract 15, and exclude -15.
    wire [1:0]         wgt_e       [0:B-1]; // range: 0 ~ 2. originally 0 ~ 3, but subtract 1, and exlcude -1.
    wire [2:0]         act_m       [0:B-1]; // add the leading 1 or 0
    wire [1:0]         wgt_m       [0:B-1]; // add the leading 1 or 0

    wire [4:0]         p_raw       [0:B-1];      // unsigned 5-bit product, 3bit * 2bit
    wire signed [5:0]  p_sgn       [0:B-1];      // signed 6-bit product
    wire [5:0]         shift_left_amount       [0:B-1];      // 0-32 left-shift amount
    wire [5:0]         shift_right_amount      [0:B-1];      // 0-32 right-shift amount
    wire signed [37:0] p_shift     [0:B-1];      // shifted, signed 13-bit term, decimal point at bit 2

    // ------------------------------------------------------------------------
    // Per-element combinational logic (only assign statements inside generate)
    // ------------------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < B; g = g + 1) begin : ELEM
            assign {act_s[g], act_e_pre[g], act_m_pre[g]} = ACT   [8*g +: 8];
            assign {wgt_s[g], wgt_e_pre[g], wgt_m_pre[g]} = WEIGHT[4*g +: 4];

            // act exp: -14 ~ 16, wgt exp: 0 ~ 2
            assign act_e[g] = (act_e_pre[g] == 5'b00000) ? -6'sd14 : $signed({1'b0, act_e_pre[g]}) - $signed({1'b0, FP8_EXP_BIAS}); // E5 subnormal exp = -14
            assign wgt_e[g] = (wgt_e_pre[g] == 2'b00) ? 2'b00 : wgt_e_pre[g] - FP4_EXP_BIAS; // FP4 subnormal exp = 0

            assign act_m[g] = { (act_e_pre[g] != 5'b00000), act_m_pre[g] }; // leading 1 for normal, 0 for subnormal
            assign wgt_m[g] = { (wgt_e_pre[g] != 2'b00), wgt_m_pre[g] }; // leading 1 for normal, 0 for subnormal

            assign p_raw[g]  = act_m[g] * wgt_m[g]; // 1.x * 1.xx
            assign p_sgn[g]  = (act_s[g] ^ wgt_s[g]) ? -$signed({1'b0,p_raw[g]})
                                                     :  $signed({1'b0,p_raw[g]});
            assign shift_left_amount[g] = act_e[g] + 14 + wgt_e[g]; // 0 ~ 32
            assign shift_right_amount[g] = 32 - shift_left_amount[g];

            // FP product -> integer product with implicit scale 2^-10
            assign p_shift[g] = (shift_right_amount[g] == 32) ? $signed({p_sgn[g], 32'd0}) >>> 32 : // avoid using 6 bit shifter
                                                                $signed({p_sgn[g], 32'd0}) >>> shift_right_amount[g][4:0];
            assign PRODUCT[g*38 +: 38] = p_shift[g];
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

