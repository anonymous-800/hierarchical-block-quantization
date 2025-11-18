`timescale 1ns / 1ps
`include "params.vh"

// Parameterized MAC
// Only support B = 4, 8, 16, 32, 64, 128
// activation bit (X) = 4, 5, 6, 7, 8, ...
module WXAY_MAC (
    input                   clk,
    input                   reset_accum,
    input                   drain,
    input  [Y*B-1:0]        act_vec,
    input  [X*B-1:0]        wgt_vec,
    input                   nv_mode,
    input  [7:0]            scale_x,
    input  [7:0]            scale_w,
    input  [15:0]           fp16_psum_in,

    output reg              drain_out,
    output reg [Y*B-1:0]    act_vec_out,
    output reg [X*B-1:0]    wgt_vec_out,
    output [7:0]            scale_x_out,
    output [7:0]            scale_w_out,
    output [15:0]           fp16_psum_out,

    output [PRODUCT_WIDTH+LEVEL-1:0] psum_debug,
    output [15:0]                    scaled_psum_debug
);
    

    wire [PRODUCT_WIDTH+LEVEL-1:0] psum;
    wire [15:0] scaled_psum;

    FP_WXAY_vector mac_vec (
        .clk(clk),
        .ACT(act_vec),
        .WEIGHT(wgt_vec),
        .PSUM(psum)
    );
    assign psum_debug = psum;

    FX2FP_Scale scaling (
        .clk(clk),
        .psum_fixed_in(psum),
        .scale_x(scale_x),
        .scale_w(scale_w),
        .nv_mode(nv_mode),
        .scale_x_out(scale_x_out),
        .scale_w_out(scale_w_out),
        .float_out(scaled_psum)
    );
    assign scaled_psum_debug = scaled_psum;

    FP16_ACCUM fp16_accum (
        .clk(clk),
        .drain(drain),
        .reset_accum(reset_accum),
        .psum_prev(fp16_psum_in),
        .scaled_psum(scaled_psum),
        .psum_out(fp16_psum_out)
    );

    // systolic array pipeline
    always @(posedge clk) begin
        act_vec_out <= act_vec;
        wgt_vec_out <= wgt_vec;
        drain_out <= drain;
    end

endmodule

module WXAY_MAC_NV (
    input                   clk,
    input                   reset_accum,
    input                   drain,
    input  [Y*B-1:0]        act_vec,
    input  [X*B-1:0]        wgt_vec,
    input  [7:0]            scale_x,
    input  [7:0]            scale_w,
    input  [15:0]           fp16_psum_in,

    output reg              drain_out,
    output reg [Y*B-1:0]    act_vec_out,
    output reg [X*B-1:0]    wgt_vec_out,
    output [7:0]            scale_x_out,
    output [7:0]            scale_w_out,
    output [15:0]           fp16_psum_out,

    output [PRODUCT_WIDTH+LEVEL-1:0] psum_debug,
    output [15:0]                    scaled_psum_debug
);

    wire [PRODUCT_WIDTH+LEVEL-1:0] psum;
    wire [15:0] scaled_psum;

    FP_WXAY_vector mac_vec (
        .clk(clk),
        .ACT(act_vec),
        .WEIGHT(wgt_vec),
        .PSUM(psum)
    );
    assign psum_debug = psum;

    FX2FP_Scale_NV scaling (
        .clk(clk),
        .psum_fixed_in(psum),
        .scale_x(scale_x),
        .scale_w(scale_w),
        .scale_x_out(scale_x_out),
        .scale_w_out(scale_w_out),
        .float_out(scaled_psum)
    );
    assign scaled_psum_debug = scaled_psum;

    FP16_ACCUM fp16_accum (
        .clk(clk),
        .drain(drain),
        .reset_accum(reset_accum),
        .psum_prev(fp16_psum_in),
        .scaled_psum(scaled_psum),
        .psum_out(fp16_psum_out)
    );

    // systolic array pipeline
    always @(posedge clk) begin
        act_vec_out <= act_vec;
        wgt_vec_out <= wgt_vec;
        drain_out <= drain;
    end

endmodule

module WXAY_MAC_MX (
    input                   clk,
    input                   reset_accum,
    input                   drain,
    input  [Y*B-1:0]        act_vec,
    input  [X*B-1:0]        wgt_vec,
    input  [4:0]            scale_x,
    input  [4:0]            scale_w,
    input  [15:0]           fp16_psum_in,

    output reg              drain_out,
    output reg [Y*B-1:0]    act_vec_out,
    output reg [X*B-1:0]    wgt_vec_out,
    output [4:0]            scale_x_out,
    output [4:0]            scale_w_out,
    output [15:0]           fp16_psum_out,

    output [PRODUCT_WIDTH+LEVEL-1:0] psum_debug,
    output [15:0]                    scaled_psum_debug
);

    wire [PRODUCT_WIDTH+LEVEL-1:0] psum;
    wire [15:0] scaled_psum;

    FP_WXAY_vector mac_vec (
        .clk(clk),
        .ACT(act_vec),
        .WEIGHT(wgt_vec),
        .PSUM(psum)
    );
    assign psum_debug = psum;

    FX2FP_Scale_MX scaling (
        .clk(clk),
        .psum_fixed_in(psum),
        .scale_x(scale_x),
        .scale_w(scale_w),
        .scale_x_out(scale_x_out),
        .scale_w_out(scale_w_out),
        .float_out(scaled_psum)
    );
    assign scaled_psum_debug = scaled_psum;

    FP16_ACCUM fp16_accum (
        .clk(clk),
        .drain(drain),
        .reset_accum(reset_accum),
        .psum_prev(fp16_psum_in),
        .scaled_psum(scaled_psum),
        .psum_out(fp16_psum_out)
    );

    // systolic array pipeline
    always @(posedge clk) begin
        act_vec_out <= act_vec;
        wgt_vec_out <= wgt_vec;
        drain_out <= drain;
    end

endmodule
