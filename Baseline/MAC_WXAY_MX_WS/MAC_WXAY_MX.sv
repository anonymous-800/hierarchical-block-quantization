`timescale 1ns / 1ps
`include "params.vh"

// Parameterized MAC for MX

module WXAY_MAC_MX (
    input                   clk,
    input  [Y*B-1:0]        act_vec,
    input  [X*B-1:0]        wgt_vec,
    input  [4:0]            scale_x,
    input  [4:0]            scale_w,
    input  [15:0]           fp16_psum_in,
    input                   propagate_wgt, // signal to indicate weight propagation in systolic array

    output reg [X*B-1:0]    wgt_vec_reg, // weight stationary, used as reg and propagating element at the same time
    output reg [4:0]        scale_w_reg, // weight stationary, used as reg and propagating element at the same time
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
        .scale_w(scale_w_reg),
        .float_out(scaled_psum)
    );
    assign scaled_psum_debug = scaled_psum;

    FP16_ADDER_clk fp16_adder_clk (
        .clk(clk),
        .psum_in(fp16_psum_in),
        .scaled_psum(scaled_psum),
        .psum_out(fp16_psum_out)
    );

    // systolic array pipeline
    always @(posedge clk) begin
        if (propagate_wgt) begin
            wgt_vec_reg <= wgt_vec;
            scale_w_reg <= scale_w;
        end
    end

endmodule
