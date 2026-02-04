`timescale 1ns / 1ps

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits internally would generate a carry-out (independent of cin)
 * @param pout whether these 4 bits internally would propagate an incoming carry from cin
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);

   wire c1,c2,c3;
   assign c1 = gin[0] | (pin[0] & cin);
   assign c2 = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin);
   assign c3 = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0]) | (pin[2] & pin[1] & pin[0] & cin);

   assign cout = {c3, c2, c1};

   // group prop
   assign pout = &pin; 

   //group generate
   assign gout = gin[3] | (pin[3] & gin[2])| (pin[3] & pin[2] & gin[1])| (pin[3] & pin[2] & pin[1] & gin[0]);


endmodule

/** Same as gp4 but for an 8-bit window instead */
module gp8(input wire [7:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [6:0] cout);

   // lower 4 bits (0..3)
   wire g_lo, p_lo;
   wire [2:0] c_lo; // c1..c3
   gp4 u_lo(
     .gin (gin[3:0]),
     .pin (pin[3:0]),
     .cin (cin),
     .gout(g_lo),
     .pout(p_lo),
     .cout(c_lo)
   );

   // carry into bit 4
   wire c4;
   assign c4 = g_lo | (p_lo & cin);

   // upper 4 bits (4..7)
   wire g_hi, p_hi;
   wire [2:0] c_hi; // carries into bits 5..7 (relative to bit4)
   gp4 u_hi(
     .gin (gin[7:4]),
     .pin (pin[7:4]),
     .cin (c4),
     .gout(g_hi),
     .pout(p_hi),
     .cout(c_hi)
   );

   // group propagate/generate for 8 bits
   assign pout = p_hi & p_lo;
   assign gout = g_hi | (p_hi & g_lo);

   // pack carries: cout = {c7,c6,c5,c4,c3,c2,c1}
   // where c1..c3 are from low gp4, c4 computed, c5..c7 from high gp4
   assign cout = {c_hi[2], c_hi[1], c_hi[0], c4, c_lo[2], c_lo[1], c_lo[0]};

endmodule


module CarryLookaheadAdder
  (input wire [31:0]  a, b,
   input wire         cin,
   output wire [31:0] sum);

   wire [31:0] g, p;
   wire [31:0] axb;

   assign axb = a ^ b;

   // per-bit generate/propagate
   genvar i;
   generate
     for (i = 0; i < 32; i = i + 1) begin : GP_BITS
       gp1 u_gp1(.a(a[i]), .b(b[i]), .g(g[i]), .p(p[i]));
     end
   endgenerate

   // 8-bit group carries
   wire [6:0] c1_7,  c9_15,  c17_23, c25_31;
   wire g0, p0, g1, p1, g2, p2, g3, p3;

   // chunk 0: bits 0..7
   gp8 u0(.gin(g[7:0]),   .pin(p[7:0]),   .cin(cin),  .gout(g0), .pout(p0), .cout(c1_7));
   wire c8;
   assign c8 = g0 | (p0 & cin);

   // chunk 1: bits 8..15
   gp8 u1(.gin(g[15:8]),  .pin(p[15:8]),  .cin(c8),   .gout(g1), .pout(p1), .cout(c9_15));
   wire c16;
   assign c16 = g1 | (p1 & c8);

   // chunk 2: bits 16..23
   gp8 u2(.gin(g[23:16]), .pin(p[23:16]), .cin(c16),  .gout(g2), .pout(p2), .cout(c17_23));
   wire c24;
   assign c24 = g2 | (p2 & c16);

   // chunk 3: bits 24..31
   gp8 u3(.gin(g[31:24]), .pin(p[31:24]), .cin(c24),  .gout(g3), .pout(p3), .cout(c25_31));
   // wire c32; // final carry-out if you ever need it
   // assign c32 = g3 | (p3 & c24);

   // build carry-in for each bit
   wire [31:0] c;
   assign c[0]  = cin;
   assign c[7:1]   = c1_7[6:0];
   assign c[8]  = c8;
   assign c[15:9]  = c9_15[6:0];
   assign c[16] = c16;
   assign c[23:17] = c17_23[6:0];
   assign c[24] = c24;
   assign c[31:25] = c25_31[6:0];

   // sum = a ^ b ^ carry_in
   assign sum = axb ^ c;

endmodule
