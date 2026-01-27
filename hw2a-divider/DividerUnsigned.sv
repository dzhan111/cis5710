/* David Zhan 63555686 */

`timescale 1ns / 1ns

// quotient = dividend / divisor

module DividerUnsigned (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);
    wire [31:0] dividend_pipe  [0:32];
    wire [31:0] remainder_pipe [0:32];
    wire [31:0] quotient_pipe  [0:32];

    assign dividend_pipe[0]  = i_dividend;
    assign remainder_pipe[0] = 32'b0;
    assign quotient_pipe[0]  = 32'b0;

    genvar k;
    generate
        for (k = 0; k < 32; k = k + 1) begin : gen_div
            DividerOneIter u_iter (
                .i_dividend  (dividend_pipe[k]),
                .i_divisor   (i_divisor),
                .i_remainder (remainder_pipe[k]),
                .i_quotient  (quotient_pipe[k]),
                .o_dividend  (dividend_pipe[k+1]),
                .o_remainder (remainder_pipe[k+1]),
                .o_quotient  (quotient_pipe[k+1])
            );
        end
    endgenerate

    assign o_remainder = remainder_pipe[32];
    assign o_quotient  = quotient_pipe[32];


endmodule


module DividerOneIter (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    input  wire [31:0] i_remainder,
    input  wire [31:0] i_quotient,
    output wire [31:0] o_dividend,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);
  /*
    for (int i = 0; i < 32; i++) {
        remainder = (remainder << 1) | ((dividend >> 31) & 0x1);
        if (remainder < divisor) {
            quotient = (quotient << 1);
        } else {
            quotient = (quotient << 1) | 0x1;
            remainder = remainder - divisor;
        }
        dividend = dividend << 1;
    }
    */

    // TODO: your code here
    wire [31:0] rem_shift = (i_remainder << 1) | {31'b0, i_dividend[31]};

    wire take = ($unsigned(rem_shift) >= $unsigned(i_divisor));
    
    assign o_quotient = (i_quotient << 1) | {31'b0, take};
    assign o_remainder = take ? (rem_shift - i_divisor) : rem_shift;
    assign o_dividend = (i_dividend << 1);


endmodule
