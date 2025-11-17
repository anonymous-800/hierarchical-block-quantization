/*
-----------------------------------------------------------------------------
Module: FX2FP_Scale
    Convert fixed point input (adder tree output) to FP16, and scale with activation and weight scaling factors
    Support both MX and NV format
    Input:
        psum_fixed_in: signed fixed point partial sum (implicit scale 2^-FIXED_SCALE) (will be one cycle delayed compared to scale_x & scale_w)
        scale_x: 8b scale for activation, when using MX, only use 5 bits
        scale_w: 8b scale for weight, when using MX, only use 5 bits
        nv_mode: 1: NV mode, 0: MX mode
    Output:
        scale_x_out: pipelined scale_x 
        scale_w_out: pipelined scale_w 
        float_out: 16b floating point output (S1E5M10)
Module: FX2FP_Scale_NV
    Does same thing as FX2FP_Scale, but only support NV mode
Module: FX2FP_Scale_MX
    Does same thing as FX2FP_Scale, but only support MX mode
Module: FX2FP
    Convert fixed point into FP format
Module: Scale
    Scale partial sum with scaling factor input
Module: Scale_NV
    Does same thing as Scale, but only support NV mode
Module: Scale_MX
    Does same thing as Scale, but only support MX mode
*/

`timescale 1ns / 1ps
`include "params.vh"

module FX2FP_Scale (
    input clk,
    input signed [FIXED_WIDTH-1:0] psum_fixed_in,
    input [7:0] scale_x,
    input [7:0] scale_w,
    input nv_mode, // 1: NV mode, 0: MX mode
    output reg [15:0] float_out
);
    reg [7:0] scale_x_r, scale_w_r;
    // systolic array pipeline
    always @(posedge clk) begin
        scale_x_r <= scale_x;
        scale_w_r <= scale_w;
    end

    // Convert fixed point input to FP16
    wire psum_is_zero;
    wire psum_sign;
    wire [FP_EXP_WIDTH:0] psum_exp;
    wire [FP_MANT_WIDTH-1:0] psum_mant;
    FX2FP fx2fp (
        .fixed_in(psum_fixed_in),
        .is_zero(psum_is_zero),
        .sign(psum_sign),
        .exp(psum_exp),
        .mant(psum_mant)
    );

    // Scale
    reg [15:0] scaled_psum;
    Scale scale (
        .psum_is_zero(psum_is_zero),
        .psum_sign(psum_sign),
        .psum_exp(psum_exp),
        .psum_mant(psum_mant),
        .scale_w(scale_w_r),
        .scale_x(scale_x_r),
        .nv_mode(nv_mode),
        .float_out(scaled_psum)
    );
    always @(posedge clk) begin
        float_out <= scaled_psum;
    end
endmodule

module FX2FP_Scale_NV (
    input clk,
    input signed [FIXED_WIDTH-1:0] psum_fixed_in,
    input [7:0] scale_x,
    input [7:0] scale_w,
    output reg [15:0] float_out
);
    reg [7:0] scale_x_r, scale_w_r;
    // systolic array pipeline
    always @(posedge clk) begin
        scale_x_r <= scale_x;
        scale_w_r <= scale_w;
    end

    // Convert fixed point input to FP16
    wire psum_is_zero;
    wire psum_sign;
    wire [FP_EXP_WIDTH:0] psum_exp;
    wire [FP_MANT_WIDTH-1:0] psum_mant;
    FX2FP fx2fp (
        .fixed_in(psum_fixed_in),
        .is_zero(psum_is_zero),
        .sign(psum_sign),
        .exp(psum_exp),
        .mant(psum_mant)
    );

    // Scale
    reg [15:0] scaled_psum;
    Scale_NV scale (
        .psum_is_zero(psum_is_zero),
        .psum_sign(psum_sign),
        .psum_exp(psum_exp),
        .psum_mant(psum_mant),
        .scale_w(scale_w_r),
        .scale_x(scale_x_r),
        .float_out(scaled_psum)
    );
    always @(posedge clk) begin
        float_out <= scaled_psum;
    end
endmodule

module FX2FP_Scale_MX (
    input clk,
    input signed [FIXED_WIDTH-1:0] psum_fixed_in,
    input [4:0] scale_x,
    input [4:0] scale_w,
    output reg [15:0] float_out
);
    reg [4:0] scale_x_r, scale_w_r;
    // systolic array pipeline
    always @(posedge clk) begin
        scale_x_r <= scale_x;
        scale_w_r <= scale_w;
    end

    // Convert fixed point input to FP16
    wire psum_is_zero;
    wire psum_sign;
    wire [FP_EXP_WIDTH:0] psum_exp;
    wire [FP_MANT_WIDTH-1:0] psum_mant;
    FX2FP fx2fp (
        .fixed_in(psum_fixed_in),
        .is_zero(psum_is_zero),
        .sign(psum_sign),
        .exp(psum_exp),
        .mant(psum_mant)
    );

    // Scale
    reg [15:0] scaled_psum;
    Scale_MX scale (
        .psum_is_zero(psum_is_zero),
        .psum_sign(psum_sign),
        .psum_exp(psum_exp),
        .psum_mant(psum_mant),
        .scale_w(scale_w_r),
        .scale_x(scale_x_r),
        .float_out(scaled_psum)
    );

    always @(posedge clk) begin
        float_out <= scaled_psum;
    end
endmodule

module FX2FP (
    input signed [FIXED_WIDTH-1:0] fixed_in,
    output reg is_zero,
    output reg sign,
    output reg signed [FP_EXP_WIDTH:0] exp,
    output reg [FP_MANT_WIDTH-1:0] mant
);

    reg [FIXED_WIDTH-1:0]  abs_val;
    reg [4:0]   leading_zeros;
    integer     i;
    reg         found;

    // Extra wide register for normalized value (to safely hold shifted result)
    reg [FIXED_WIDTH-1:0]  normalized;
    always @(*) begin
        sign = fixed_in[FIXED_WIDTH-1];
        if (sign)
            abs_val = ~fixed_in + 1;  // 2's complement conversion for negative numbers
        else
            abs_val = fixed_in;       
        found = 1'b0;
        leading_zeros = 0;
        for (i = FIXED_WIDTH-1; i >= 0; i = i - 1) begin
            if (!found && abs_val[i]) begin
                leading_zeros = FIXED_WIDTH - i - 1;
                found = 1'b1;
            end
        end
        exp = FIXED_WIDTH - FIXED_SCALE - leading_zeros - 1;
        normalized = abs_val << leading_zeros;
        mant = normalized[FIXED_WIDTH-2-:FP_MANT_WIDTH]; // -1 for leading 1
        is_zero = (abs_val == 0);
    end
endmodule

module Scale (
    input psum_is_zero,
    input psum_sign,
    input signed [FP_EXP_WIDTH:0] psum_exp,
    input [FP_MANT_WIDTH-1:0] psum_mant,
    input [7:0] scale_w,
    input [7:0] scale_x,
    input nv_mode, // 1: NV mode, 0: MX mode
    output reg [15:0] float_out
);
    reg signed [5:0] scale_x_exp, scale_w_exp;
    reg [2:0] nv_scale_x_mant, nv_scale_w_mant;
    reg [7:0] nv_scale_mant_product;
    reg signed [FP_EXP_WIDTH:0] exp_sum; // add one bit for overflow
    reg [18:0] product;
    reg signed [FP_EXP_WIDTH:0] fp_exp; // add one bit for overflow
    reg [FP_MANT_WIDTH-1:0] fp_mant;
    reg round;
    always @(*) begin
        scale_x_exp = nv_mode ? {1'b0, scale_x[7:3]} : {1'b0, scale_x[4:0]}; // biased
        scale_w_exp = nv_mode ? {1'b0, scale_w[7:3]} : {1'b0, scale_w[4:0]}; // biased
        nv_scale_x_mant = scale_x[2:0];
        nv_scale_w_mant = scale_w[2:0];
        exp_sum = scale_x_exp + scale_w_exp + psum_exp - SCALE_EXP_BIAS;
        if (nv_mode) begin
            nv_scale_mant_product = {1'b1, nv_scale_x_mant} * {1'b1, nv_scale_w_mant}; // 1x.xxxxxx or 01.xxxxxx
            product = {1'b1, psum_mant} * nv_scale_mant_product; // 1xx.10b or 01x.10b or 001.10b
            if (product[18]) begin // 1xx.10b
                fp_exp = exp_sum+2;
                fp_mant = product[17-:FP_MANT_WIDTH];
                round = product[17-FP_MANT_WIDTH];
            end else if (product[17]) begin // 01x.10b
                fp_exp = exp_sum+1;
                fp_mant = product[16-:FP_MANT_WIDTH];
                round = product[16-FP_MANT_WIDTH];
            end else begin // 001.10b
                fp_exp = exp_sum;
                fp_mant = product[15-:FP_MANT_WIDTH];
                round = product[15-FP_MANT_WIDTH];
            end
            if (round) begin
                if (fp_mant == {FP_MANT_WIDTH{1'b1}}) begin
                    fp_exp = fp_exp + 1;
                    fp_mant = 0;
                end else begin
                    fp_mant = fp_mant + 1;
                end
            end
        end
        else begin
            product = 0;
            fp_exp = exp_sum;
            fp_mant = psum_mant;
        end

        if (psum_is_zero) begin
            float_out = {1'b0, {5'b00000}, {10'b0000000000}};
        end else if (fp_exp > FP_EXP_MAX_UNBIASED) begin // overflow, clip to max
            float_out = {psum_sign, {5'b11110}, {10'b1111111111}};
        end else if (fp_exp < 1) begin // underflow, clip to 0
            float_out = {1'b0, {5'b00000}, {10'b0000000000}};
        end else begin
            float_out = {psum_sign, fp_exp[FP_EXP_WIDTH-1:0], fp_mant};
        end
    end
endmodule

module Scale_NV (
    input psum_is_zero,
    input psum_sign,
    input signed [FP_EXP_WIDTH:0] psum_exp,
    input [FP_MANT_WIDTH-1:0] psum_mant,
    input [7:0] scale_x,
    input [7:0] scale_w,
    output reg [15:0] float_out
);
    reg signed [5:0] scale_x_exp, scale_w_exp;
    reg [2:0] nv_scale_x_mant, nv_scale_w_mant;
    reg [7:0] nv_scale_mant_product;
    reg signed [5:0] exp_sum; // add one bit for overflow
    reg [18:0] product;
    reg signed [FP_EXP_WIDTH:0] fp_exp; // add one bit for overflow
    reg [FP_MANT_WIDTH-1:0] fp_mant;
    reg round;
    always @(*) begin
        scale_x_exp = {1'b0, scale_x[7:3]}; // biased
        scale_w_exp = {1'b0, scale_w[7:3]}; // biased
        nv_scale_x_mant = scale_x[2:0];
        nv_scale_w_mant = scale_w[2:0];
        exp_sum = scale_x_exp + scale_w_exp + psum_exp - SCALE_EXP_BIAS;
        nv_scale_mant_product = {1'b1, nv_scale_x_mant} * {1'b1, nv_scale_w_mant}; // 1x.xxxxxx or 01.xxxxxx
        product = {1'b1, psum_mant} * nv_scale_mant_product; // 1xx.10b or 01x.10b or 001.10b
        if (product[18]) begin // 1xx.10b
            fp_exp = exp_sum+2;
            fp_mant = product[17-:FP_MANT_WIDTH];
            round = product[17-FP_MANT_WIDTH];
        end else if (product[17]) begin // 01x.10b
            fp_exp = exp_sum+1;
            fp_mant = product[16-:FP_MANT_WIDTH];
            round = product[16-FP_MANT_WIDTH];
        end else begin // 001.10b
            fp_exp = exp_sum;
            fp_mant = product[15-:FP_MANT_WIDTH];
            round = product[15-FP_MANT_WIDTH];
        end
        if (round) begin
            if (fp_mant == {FP_MANT_WIDTH{1'b1}}) begin
                fp_exp = fp_exp + 1;
                fp_mant = 0;
            end else begin
                fp_mant = fp_mant + 1;
            end
        end

        if (psum_is_zero) begin
            float_out = {1'b0, {5'b00000}, {10'b0000000000}};
        end else if (fp_exp > FP_EXP_MAX_UNBIASED) begin // overflow, clip to max
            float_out = {psum_sign, {5'b11110}, {10'b1111111111}};
        end else if (fp_exp < 1) begin // underflow, clip to 0
            float_out = {1'b0, {5'b00000}, {10'b0000000000}};
        end else begin
            float_out = {psum_sign, fp_exp[FP_EXP_WIDTH-1:0], fp_mant};
        end
    end
endmodule

module Scale_MX (
    input psum_is_zero,
    input psum_sign,
    input signed [FP_EXP_WIDTH:0] psum_exp,
    input [FP_MANT_WIDTH-1:0] psum_mant,
    input [4:0] scale_x,
    input [4:0] scale_w,
    output reg [15:0] float_out
);
    reg signed [5:0] scale_x_exp, scale_w_exp;
    reg signed [5:0] exp_sum; // add one bit for overflow
    reg [18:0] product;
    reg signed [FP_EXP_WIDTH:0] fp_exp; // add one bit for overflow
    reg [FP_MANT_WIDTH-1:0] fp_mant;
    reg round;
    always @(*) begin
        scale_x_exp = {1'b0, scale_x}; // biased
        scale_w_exp = {1'b0, scale_w}; // biased
        exp_sum = scale_x_exp + scale_w_exp + psum_exp - SCALE_EXP_BIAS;
        product = 0;
        fp_exp = exp_sum;
        fp_mant = psum_mant;

        if (psum_is_zero) begin
            float_out = {1'b0, {5'b00000}, {10'b0000000000}};
        end else if (fp_exp > FP_EXP_MAX_UNBIASED) begin // overflow, clip to max
            float_out = {psum_sign, {5'b11110}, {10'b1111111111}};
        end else if (fp_exp < 1) begin // underflow, clip to 0
            float_out = {1'b0, {5'b00000}, {10'b0000000000}};
        end else begin
            float_out = {psum_sign, fp_exp[FP_EXP_WIDTH-1:0], fp_mant};
        end
    end
endmodule

