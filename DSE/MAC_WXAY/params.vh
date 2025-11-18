`ifndef PARAMS_VH
`define PARAMS_VH

// PE and Multipliers
parameter integer X = 4;  // 3, 4, 5, 6, 7, 8
parameter integer Y = 8;  // 4, 5, 6, 7, 8
parameter integer B = 32; // 4, 8, 16, 32, 64, 128
parameter PRODUCT_WIDTH = (X-2)+(Y-2)+5;
parameter LEVEL = $clog2(B); // level of adder tree inside multiplier

// Sub-Block Parameters
parameter integer SUB_B = 16;
parameter integer NUM_SUB_B = B/SUB_B;  
parameter SUB_BLOCK_LEVEL = $clog2(SUB_B);

// Scaling Modules (DEQUANT)
parameter SCALE_EXP_BIAS = 15; // bias for the exponent in nvfp format
parameter FP_EXP_MAX_UNBIASED = 30; // 30 = 15 + 15
parameter FP_EXP_WIDTH = 5;
parameter FP_MANT_WIDTH = 10;
parameter FIXED_WIDTH = PRODUCT_WIDTH + LEVEL; // width of fixed point psum
parameter FIXED_SCALE = X-3 + Y-3; // implicit scale of fixed point input (shift left by FIXED_SCALE)

// FP16_ACCUM
parameter BITWIDTH = 16;
parameter EXP = 5;
parameter EXP_B = 15;
parameter MANT = 10;
parameter EX_BIT = 2;

`endif