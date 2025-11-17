/*
    FP16 adder & accumulator
*/

module FP16_ADDER (
    input                 ADD2SUB,
    input  [BITWIDTH-1:0] IN1,
    input  [BITWIDTH-1:0] IN2,
    output [BITWIDTH-1:0] OUT
);

    // Wires and registers
    wire [BITWIDTH-1:0] a = IN1;
    wire [BITWIDTH-1:0] b = IN2;
    reg  [BITWIDTH-1:0] result;
    assign OUT = result;

    wire sign_a = a[BITWIDTH-1];
    wire sign_b = ADD2SUB ? ~b[BITWIDTH-1] : b[BITWIDTH-1];
    wire [EXP-1:0] exp_a = a[BITWIDTH-2 : BITWIDTH-1-EXP];
    wire [EXP-1:0] exp_b = b[BITWIDTH-2 : BITWIDTH-1-EXP];

    reg  [EXP-1:0] exponent_large, exponent_small;
    reg  [MANT:0]  mant_a, mant_b; // includes hidden 1-bit
    reg  [MANT:0]  mantissa_large, mantissa_small;
    reg  signed [MANT+1:0]  mantissa_small_signed;
    reg  signed [MANT+1+EX_BIT:0] mantissa_small_shifted, mantissa_small_shifted_real;
    reg  [MANT+1+EX_BIT:0] mantissa_sum, mantissa_a, mantissa_b;
    reg  signed [MANT+2+EX_BIT:0] mantissa_sum_sign;
    reg  [EXP-1:0] exponent_diff;
    reg  sign_large, sign_small, sign_result, sign_result_final;
    reg  signed [EXP+1:0] exponent_result;
    reg  [EXP:0] exponent_result_final;
    reg  [MANT+EX_BIT+1:0] mantissa_result1, mantissa_result2, mantissa_result;

    // 4-bit blocks for normalization
    wire [3:0] mant_split [0:2];
    assign mant_split[2] = mantissa_sum[MANT+EX_BIT+1 : MANT+EX_BIT-2];
    assign mant_split[1] = mantissa_sum[MANT+EX_BIT-3 : MANT+EX_BIT-6];
    assign mant_split[0] = mantissa_sum[MANT+EX_BIT-7 : MANT+EX_BIT-10];

    wire [0:2] GLDONE;
    assign GLDONE[2] = (mant_split[2] != 4'b0000);
    assign GLDONE[1] = (mant_split[1] != 4'b0000);
    assign GLDONE[0] = (mant_split[0] != 4'b0000);

    reg [3:0] FLDONE;
    reg [1:0] MUX1, MUX2;
    reg [2:0] rounded_sum;

    // Determine normalization shift
    always @(*) begin
        if (GLDONE[2]) begin
            FLDONE <= mant_split[2];
            MUX1   <= 2'b00;
        end else if (GLDONE[1]) begin
            FLDONE <= mant_split[1];
            MUX1   <= 2'b01;
        end else if (GLDONE[0]) begin
            FLDONE <= mant_split[0];
            MUX1   <= 2'b10;
        end else begin
            // all zero => use bottom bits
            FLDONE <= {mantissa_sum[0], 3'b000};
            MUX1   <= 2'b11;
        end

        if (FLDONE[3])      MUX2 <= 2'd0;
        else if (FLDONE[2]) MUX2 <= 2'd1;
        else if (FLDONE[1]) MUX2 <= 2'd2;
        else                MUX2 <= 2'd3;
    end

    // Main combinational block
    always @(*) begin
        // Ignore subnormal: if exponent=0, treat mantissa as 0
        mant_a = (exp_a == 0) ? 0 : {1'b1, a[MANT-1:0]};
        mant_b = (exp_b == 0) ? 0 : {1'b1, b[MANT-1:0]};

        // Compare (exponent + mant) to find which is bigger
        if (a[BITWIDTH-2:0] > b[BITWIDTH-2:0]) begin
            exponent_large = exp_a;
            exponent_small = exp_b;
            mantissa_large = mant_a;
            mantissa_small = mant_b;
            sign_large     = sign_a;
            sign_small     = sign_b;
        end else begin
            exponent_large = exp_b;
            exponent_small = exp_a;
            mantissa_large = mant_b;
            mantissa_small = mant_a;
            sign_large     = sign_b;
            sign_small     = sign_a;
        end

        exponent_diff = exponent_large - exponent_small;
        if (sign_large == sign_small) mantissa_small_signed = mantissa_small;
        else                          mantissa_small_signed = -mantissa_small;        

        mantissa_small_shifted_real = {mantissa_small_signed, 2'b00} ;
        mantissa_small_shifted = mantissa_small_shifted_real >>> exponent_diff;

        // Add or subtract based on signs
        mantissa_a = {mantissa_large, 2'b00};
        mantissa_b = mantissa_small_shifted;


        mantissa_sum_sign = mantissa_a + mantissa_b;
        sign_result       = sign_large;

        // Simple rounding
        if (mantissa_sum_sign[MANT+1+EX_BIT])
            rounded_sum = {mantissa_sum_sign[2], 2'b00};
        else if (mantissa_sum_sign[MANT+1+EX_BIT-1])
            rounded_sum = {1'b0, mantissa_sum_sign[1], 1'b0};
        else if (mantissa_sum_sign[MANT+1+EX_BIT-2])
            rounded_sum = {1'b0, 1'b0, mantissa_sum_sign[0]};
        else
            rounded_sum = 3'b000;

        mantissa_sum = mantissa_sum_sign[MANT+1+EX_BIT : 0] + rounded_sum;

        // Normalization: shift based on MUX1 and MUX2
        case (MUX1)
            2'b00: mantissa_result1 = mantissa_sum << 0;
            2'b01: mantissa_result1 = mantissa_sum << 4;
            2'b10: mantissa_result1 = mantissa_sum << 8;
            default: mantissa_result1 = mantissa_sum << 12;
        endcase

        mantissa_result2 = mantissa_result1 << MUX2;
        exponent_result  = exponent_large + 1 - (MUX1 << 2) - MUX2;

        // Check underflow/overflow
        if ((exponent_result <= 0) || ((MUX1 == 2'b11) && (MUX2 != 0))) begin
            mantissa_result = 0;
            sign_result_final = 0;
            exponent_result_final = 0;
        end else if (exponent_result >= 63) begin
            mantissa_result = 0;
            sign_result_final = sign_result;
            exponent_result_final = 6'b111111;
        end else begin
            mantissa_result = mantissa_result2;
            sign_result_final = sign_result;
            exponent_result_final = exponent_result;
        end

        // Reconstruct final FP16
        result = {
            sign_result_final,
            exponent_result_final[EXP-1:0],
            mantissa_result[MANT+EX_BIT : 1+EX_BIT]
        };
    end

endmodule

module FP16_ACCUM (
    input  clk,
    input  drain,
    input  reset_accum,
    input  [BITWIDTH-1:0] psum_prev, // systolic array drain port
    input  [BITWIDTH-1:0] scaled_psum,
    output [BITWIDTH-1:0] psum_out
);
    reg [BITWIDTH-1:0] fp_adder_in2, fp_adder_out;
    reg [BITWIDTH-1:0] fp_accum_r, fp_accum_w;
    assign psum_out = fp_accum_r;

    FP16_ADDER fp16_adder (
        .ADD2SUB(1'b0),
        .IN1(fp_accum_r),
        .IN2(fp_adder_in2),
        .OUT(fp_adder_out)
    );

    always @(*) begin
        if (reset_accum) begin
            fp_accum_w = 0;
            fp_adder_in2 = 0;
        end
        else if (drain) begin // during draining, turn off adder & pass down prev psum
            fp_accum_w = psum_prev;
            fp_adder_in2 = 0;
        end
        else begin
            fp_accum_w = fp_adder_out;
            fp_adder_in2 = scaled_psum;
        end
    end
    always @(posedge clk) begin
        if (reset_accum) begin
            fp_accum_r <= 0;
        end
        else begin
            fp_accum_r <= fp_accum_w;
        end
    end

endmodule

module FP16_ADDER_clk (
    input  clk,
    input  [BITWIDTH-1:0] psum_in, // from the psum buffer
    input  [BITWIDTH-1:0] scaled_psum,
    output reg [BITWIDTH-1:0] psum_out
);
    wire [BITWIDTH-1:0] fp_adder_out;

    FP16_ADDER fp16_adder (
        .ADD2SUB(1'b0),
        .IN1(psum_in),
        .IN2(scaled_psum),
        .OUT(fp_adder_out)
    );

    always @(posedge clk) begin
        psum_out <= fp_adder_out;
    end

endmodule