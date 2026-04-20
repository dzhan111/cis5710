
/* INSERT NAME AND PENNKEY HERE */

`timescale 1ns / 1ns

// quotient = dividend / divisor

module DividerUnsignedPipelined (
    input wire clk, rst, stall,
    input  wire  [31:0] i_dividend,
    input  wire  [31:0] i_divisor,
    output logic [31:0] o_remainder,
    output logic [31:0] o_quotient
);

  // 8 pipeline stages of 4 iterations each = 32 total iterations
  // 7 inter-stage pipeline registers → result ready 8 cycles after inputs
  //
  // Use per-stage wires (not shared 2D arrays) so Verilator sees no
  // false circular dependencies across pipeline register boundaries.

  // Stage 0: purely combinatorial, fed from module inputs
  wire [31:0] s0_dividend [0:4];
  wire [31:0] s0_remainder[0:4];
  wire [31:0] s0_quotient [0:4];

  assign s0_dividend[0]  = i_dividend;
  assign s0_remainder[0] = 32'd0;
  assign s0_quotient[0]  = 32'd0;

  genvar k;
  generate
    for (k = 0; k < 4; k++) begin : s0_iters
      divu_1iter u_s0 (
        .i_dividend (s0_dividend[k]),  .i_divisor(i_divisor),
        .i_remainder(s0_remainder[k]), .i_quotient(s0_quotient[k]),
        .o_dividend (s0_dividend[k+1]),
        .o_remainder(s0_remainder[k+1]), .o_quotient(s0_quotient[k+1])
      );
    end
  endgenerate

  // Pipeline register 0
  logic [31:0] r0_dividend, r0_remainder, r0_quotient, r0_divisor;
  always_ff @(posedge clk) begin
    if (rst) begin
      r0_dividend  <= 0; r0_remainder <= 0; r0_quotient <= 0; r0_divisor <= 0;
    end else if (!stall) begin
      r0_dividend  <= s0_dividend[4];  r0_remainder <= s0_remainder[4];
      r0_quotient  <= s0_quotient[4];  r0_divisor   <= i_divisor;
    end
  end

  // Stage 1
  wire [31:0] s1_dividend [0:4];
  wire [31:0] s1_remainder[0:4];
  wire [31:0] s1_quotient [0:4];

  assign s1_dividend[0]  = r0_dividend;
  assign s1_remainder[0] = r0_remainder;
  assign s1_quotient[0]  = r0_quotient;

  generate
    for (k = 0; k < 4; k++) begin : s1_iters
      divu_1iter u_s1 (
        .i_dividend (s1_dividend[k]),  .i_divisor(r0_divisor),
        .i_remainder(s1_remainder[k]), .i_quotient(s1_quotient[k]),
        .o_dividend (s1_dividend[k+1]),
        .o_remainder(s1_remainder[k+1]), .o_quotient(s1_quotient[k+1])
      );
    end
  endgenerate

  // Pipeline register 1
  logic [31:0] r1_dividend, r1_remainder, r1_quotient, r1_divisor;
  always_ff @(posedge clk) begin
    if (rst) begin
      r1_dividend  <= 0; r1_remainder <= 0; r1_quotient <= 0; r1_divisor <= 0;
    end else if (!stall) begin
      r1_dividend  <= s1_dividend[4];  r1_remainder <= s1_remainder[4];
      r1_quotient  <= s1_quotient[4];  r1_divisor   <= r0_divisor;
    end
  end

  // Stage 2
  wire [31:0] s2_dividend [0:4];
  wire [31:0] s2_remainder[0:4];
  wire [31:0] s2_quotient [0:4];

  assign s2_dividend[0]  = r1_dividend;
  assign s2_remainder[0] = r1_remainder;
  assign s2_quotient[0]  = r1_quotient;

  generate
    for (k = 0; k < 4; k++) begin : s2_iters
      divu_1iter u_s2 (
        .i_dividend (s2_dividend[k]),  .i_divisor(r1_divisor),
        .i_remainder(s2_remainder[k]), .i_quotient(s2_quotient[k]),
        .o_dividend (s2_dividend[k+1]),
        .o_remainder(s2_remainder[k+1]), .o_quotient(s2_quotient[k+1])
      );
    end
  endgenerate

  // Pipeline register 2
  logic [31:0] r2_dividend, r2_remainder, r2_quotient, r2_divisor;
  always_ff @(posedge clk) begin
    if (rst) begin
      r2_dividend  <= 0; r2_remainder <= 0; r2_quotient <= 0; r2_divisor <= 0;
    end else if (!stall) begin
      r2_dividend  <= s2_dividend[4];  r2_remainder <= s2_remainder[4];
      r2_quotient  <= s2_quotient[4];  r2_divisor   <= r1_divisor;
    end
  end

  // Stage 3
  wire [31:0] s3_dividend [0:4];
  wire [31:0] s3_remainder[0:4];
  wire [31:0] s3_quotient [0:4];

  assign s3_dividend[0]  = r2_dividend;
  assign s3_remainder[0] = r2_remainder;
  assign s3_quotient[0]  = r2_quotient;

  generate
    for (k = 0; k < 4; k++) begin : s3_iters
      divu_1iter u_s3 (
        .i_dividend (s3_dividend[k]),  .i_divisor(r2_divisor),
        .i_remainder(s3_remainder[k]), .i_quotient(s3_quotient[k]),
        .o_dividend (s3_dividend[k+1]),
        .o_remainder(s3_remainder[k+1]), .o_quotient(s3_quotient[k+1])
      );
    end
  endgenerate

  // Pipeline register 3
  logic [31:0] r3_dividend, r3_remainder, r3_quotient, r3_divisor;
  always_ff @(posedge clk) begin
    if (rst) begin
      r3_dividend  <= 0; r3_remainder <= 0; r3_quotient <= 0; r3_divisor <= 0;
    end else if (!stall) begin
      r3_dividend  <= s3_dividend[4];  r3_remainder <= s3_remainder[4];
      r3_quotient  <= s3_quotient[4];  r3_divisor   <= r2_divisor;
    end
  end

  // Stage 4
  wire [31:0] s4_dividend [0:4];
  wire [31:0] s4_remainder[0:4];
  wire [31:0] s4_quotient [0:4];

  assign s4_dividend[0]  = r3_dividend;
  assign s4_remainder[0] = r3_remainder;
  assign s4_quotient[0]  = r3_quotient;

  generate
    for (k = 0; k < 4; k++) begin : s4_iters
      divu_1iter u_s4 (
        .i_dividend (s4_dividend[k]),  .i_divisor(r3_divisor),
        .i_remainder(s4_remainder[k]), .i_quotient(s4_quotient[k]),
        .o_dividend (s4_dividend[k+1]),
        .o_remainder(s4_remainder[k+1]), .o_quotient(s4_quotient[k+1])
      );
    end
  endgenerate

  // Pipeline register 4
  logic [31:0] r4_dividend, r4_remainder, r4_quotient, r4_divisor;
  always_ff @(posedge clk) begin
    if (rst) begin
      r4_dividend  <= 0; r4_remainder <= 0; r4_quotient <= 0; r4_divisor <= 0;
    end else if (!stall) begin
      r4_dividend  <= s4_dividend[4];  r4_remainder <= s4_remainder[4];
      r4_quotient  <= s4_quotient[4];  r4_divisor   <= r3_divisor;
    end
  end

  // Stage 5
  wire [31:0] s5_dividend [0:4];
  wire [31:0] s5_remainder[0:4];
  wire [31:0] s5_quotient [0:4];

  assign s5_dividend[0]  = r4_dividend;
  assign s5_remainder[0] = r4_remainder;
  assign s5_quotient[0]  = r4_quotient;

  generate
    for (k = 0; k < 4; k++) begin : s5_iters
      divu_1iter u_s5 (
        .i_dividend (s5_dividend[k]),  .i_divisor(r4_divisor),
        .i_remainder(s5_remainder[k]), .i_quotient(s5_quotient[k]),
        .o_dividend (s5_dividend[k+1]),
        .o_remainder(s5_remainder[k+1]), .o_quotient(s5_quotient[k+1])
      );
    end
  endgenerate

  // Pipeline register 5
  logic [31:0] r5_dividend, r5_remainder, r5_quotient, r5_divisor;
  always_ff @(posedge clk) begin
    if (rst) begin
      r5_dividend  <= 0; r5_remainder <= 0; r5_quotient <= 0; r5_divisor <= 0;
    end else if (!stall) begin
      r5_dividend  <= s5_dividend[4];  r5_remainder <= s5_remainder[4];
      r5_quotient  <= s5_quotient[4];  r5_divisor   <= r4_divisor;
    end
  end

  // Stage 6
  wire [31:0] s6_dividend [0:4];
  wire [31:0] s6_remainder[0:4];
  wire [31:0] s6_quotient [0:4];

  assign s6_dividend[0]  = r5_dividend;
  assign s6_remainder[0] = r5_remainder;
  assign s6_quotient[0]  = r5_quotient;

  generate
    for (k = 0; k < 4; k++) begin : s6_iters
      divu_1iter u_s6 (
        .i_dividend (s6_dividend[k]),  .i_divisor(r5_divisor),
        .i_remainder(s6_remainder[k]), .i_quotient(s6_quotient[k]),
        .o_dividend (s6_dividend[k+1]),
        .o_remainder(s6_remainder[k+1]), .o_quotient(s6_quotient[k+1])
      );
    end
  endgenerate

  // Pipeline register 6
  logic [31:0] r6_dividend, r6_remainder, r6_quotient, r6_divisor;
  always_ff @(posedge clk) begin
    if (rst) begin
      r6_dividend  <= 0; r6_remainder <= 0; r6_quotient <= 0; r6_divisor <= 0;
    end else if (!stall) begin
      r6_dividend  <= s6_dividend[4];  r6_remainder <= s6_remainder[4];
      r6_quotient  <= s6_quotient[4];  r6_divisor   <= r5_divisor;
    end
  end

  // Stage 7 (final, no register after)
  wire [31:0] s7_dividend [0:4];
  wire [31:0] s7_remainder[0:4];
  wire [31:0] s7_quotient [0:4];

  assign s7_dividend[0]  = r6_dividend;
  assign s7_remainder[0] = r6_remainder;
  assign s7_quotient[0]  = r6_quotient;

  generate
    for (k = 0; k < 4; k++) begin : s7_iters
      divu_1iter u_s7 (
        .i_dividend (s7_dividend[k]),  .i_divisor(r6_divisor),
        .i_remainder(s7_remainder[k]), .i_quotient(s7_quotient[k]),
        .o_dividend (s7_dividend[k+1]),
        .o_remainder(s7_remainder[k+1]), .o_quotient(s7_quotient[k+1])
      );
    end
  endgenerate

  // Output from final stage
  assign o_quotient  = s7_quotient[4];
  assign o_remainder = s7_remainder[4];

endmodule

module divu_1iter (
    input  wire  [31:0] i_dividend,
    input  wire  [31:0] i_divisor,
    input  wire  [31:0] i_remainder,
    input  wire  [31:0] i_quotient,
    output logic [31:0] o_dividend,
    output logic [31:0] o_remainder,
    output logic [31:0] o_quotient
);

    wire [31:0] next_remainder;
    assign next_remainder = (i_remainder << 1) | ((i_dividend >> 31) & 32'd1);

    wire lt;
    assign lt = (next_remainder < i_divisor);

    assign o_quotient = lt ? (i_quotient << 1) : ((i_quotient << 1) | 32'd1);
    assign o_remainder = lt ? (next_remainder) : (next_remainder - i_divisor);

    assign o_dividend = i_dividend << 1;

endmodule
