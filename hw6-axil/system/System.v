`default_nettype none
module MyClockGen (
	input_clk_25MHz,
	clk_125MHz,
	clk_25MHz,
	clk_proc,
	locked
);
	input input_clk_25MHz;
	output wire clk_125MHz;
	output wire clk_25MHz;
	output wire clk_proc;
	output wire locked;
	wire clkfb;
	(* FREQUENCY_PIN_CLKI = "25" *) (* FREQUENCY_PIN_CLKOP = "125" *) (* FREQUENCY_PIN_CLKOS = "25" *) (* FREQUENCY_PIN_CLKOS2 = "20.1613" *) (* ICP_CURRENT = "12" *) (* LPF_RESISTOR = "8" *) (* MFG_ENABLE_FILTEROPAMP = "1" *) (* MFG_GMCREF_SEL = "2" *) EHXPLLL #(
		.PLLRST_ENA("DISABLED"),
		.INTFB_WAKE("DISABLED"),
		.STDBY_ENABLE("DISABLED"),
		.DPHASE_SOURCE("DISABLED"),
		.OUTDIVIDER_MUXA("DIVA"),
		.OUTDIVIDER_MUXB("DIVB"),
		.OUTDIVIDER_MUXC("DIVC"),
		.OUTDIVIDER_MUXD("DIVD"),
		.CLKI_DIV(1),
		.CLKOP_ENABLE("ENABLED"),
		.CLKOP_DIV(5),
		.CLKOP_CPHASE(2),
		.CLKOP_FPHASE(0),
		.CLKOS_ENABLE("ENABLED"),
		.CLKOS_DIV(25),
		.CLKOS_CPHASE(2),
		.CLKOS_FPHASE(0),
		.CLKOS2_ENABLE("ENABLED"),
		.CLKOS2_DIV(31),
		.CLKOS2_CPHASE(2),
		.CLKOS2_FPHASE(0),
		.FEEDBK_PATH("INT_OP"),
		.CLKFB_DIV(5)
	) pll_i(
		.RST(1'b0),
		.STDBY(1'b0),
		.CLKI(input_clk_25MHz),
		.CLKOP(clk_125MHz),
		.CLKOS(clk_25MHz),
		.CLKOS2(clk_proc),
		.CLKFB(clkfb),
		.CLKINTFB(clkfb),
		.PHASESEL0(1'b0),
		.PHASESEL1(1'b0),
		.PHASEDIR(1'b1),
		.PHASESTEP(1'b1),
		.PHASELOADREG(1'b1),
		.PLLWAKESYNC(1'b0),
		.ENCLKOP(1'b0),
		.LOCK(locked)
	);
endmodule
module gp1 (
	a,
	b,
	g,
	p
);
	input wire a;
	input wire b;
	output wire g;
	output wire p;
	assign g = a & b;
	assign p = a | b;
endmodule
module gp4 (
	gin,
	pin,
	cin,
	gout,
	pout,
	cout
);
	input wire [3:0] gin;
	input wire [3:0] pin;
	input wire cin;
	output wire gout;
	output wire pout;
	output wire [2:0] cout;
	wire c1;
	wire c2;
	wire c3;
	assign c1 = gin[0] | (pin[0] & cin);
	assign c2 = (gin[1] | (pin[1] & gin[0])) | ((pin[1] & pin[0]) & cin);
	assign c3 = ((gin[2] | (pin[2] & gin[1])) | ((pin[2] & pin[1]) & gin[0])) | (((pin[2] & pin[1]) & pin[0]) & cin);
	assign cout = {c3, c2, c1};
	assign pout = &pin;
	assign gout = ((gin[3] | (pin[3] & gin[2])) | ((pin[3] & pin[2]) & gin[1])) | (((pin[3] & pin[2]) & pin[1]) & gin[0]);
endmodule
module gp8 (
	gin,
	pin,
	cin,
	gout,
	pout,
	cout
);
	input wire [7:0] gin;
	input wire [7:0] pin;
	input wire cin;
	output wire gout;
	output wire pout;
	output wire [6:0] cout;
	wire g_lo;
	wire p_lo;
	wire [2:0] c_lo;
	gp4 u_lo(
		.gin(gin[3:0]),
		.pin(pin[3:0]),
		.cin(cin),
		.gout(g_lo),
		.pout(p_lo),
		.cout(c_lo)
	);
	wire c4;
	assign c4 = g_lo | (p_lo & cin);
	wire g_hi;
	wire p_hi;
	wire [2:0] c_hi;
	gp4 u_hi(
		.gin(gin[7:4]),
		.pin(pin[7:4]),
		.cin(c4),
		.gout(g_hi),
		.pout(p_hi),
		.cout(c_hi)
	);
	assign pout = p_hi & p_lo;
	assign gout = g_hi | (p_hi & g_lo);
	assign cout = {c_hi[2], c_hi[1], c_hi[0], c4, c_lo[2], c_lo[1], c_lo[0]};
endmodule
module CarryLookaheadAdder (
	a,
	b,
	cin,
	sum
);
	input wire [31:0] a;
	input wire [31:0] b;
	input wire cin;
	output wire [31:0] sum;
	wire [31:0] g;
	wire [31:0] p;
	wire [31:0] axb;
	assign axb = a ^ b;
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < 32; _gv_i_1 = _gv_i_1 + 1) begin : GP_BITS
			localparam i = _gv_i_1;
			gp1 u_gp1(
				.a(a[i]),
				.b(b[i]),
				.g(g[i]),
				.p(p[i])
			);
		end
	endgenerate
	wire [6:0] c1_7;
	wire [6:0] c9_15;
	wire [6:0] c17_23;
	wire [6:0] c25_31;
	wire g0;
	wire p0;
	wire g1;
	wire p1;
	wire g2;
	wire p2;
	wire g3;
	wire p3;
	gp8 u0(
		.gin(g[7:0]),
		.pin(p[7:0]),
		.cin(cin),
		.gout(g0),
		.pout(p0),
		.cout(c1_7)
	);
	wire c8;
	assign c8 = g0 | (p0 & cin);
	gp8 u1(
		.gin(g[15:8]),
		.pin(p[15:8]),
		.cin(c8),
		.gout(g1),
		.pout(p1),
		.cout(c9_15)
	);
	wire c16;
	assign c16 = g1 | (p1 & c8);
	gp8 u2(
		.gin(g[23:16]),
		.pin(p[23:16]),
		.cin(c16),
		.gout(g2),
		.pout(p2),
		.cout(c17_23)
	);
	wire c24;
	assign c24 = g2 | (p2 & c16);
	gp8 u3(
		.gin(g[31:24]),
		.pin(p[31:24]),
		.cin(c24),
		.gout(g3),
		.pout(p3),
		.cout(c25_31)
	);
	wire [31:0] c;
	assign c[0] = cin;
	assign c[7:1] = c1_7[6:0];
	assign c[8] = c8;
	assign c[15:9] = c9_15[6:0];
	assign c[16] = c16;
	assign c[23:17] = c17_23[6:0];
	assign c[24] = c24;
	assign c[31:25] = c25_31[6:0];
	assign sum = axb ^ c;
endmodule
module DividerUnsignedPipelined (
	clk,
	rst,
	stall,
	i_dividend,
	i_divisor,
	o_remainder,
	o_quotient
);
	input wire clk;
	input wire rst;
	input wire stall;
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	wire [31:0] s0_dividend [0:4];
	wire [31:0] s0_remainder [0:4];
	wire [31:0] s0_quotient [0:4];
	assign s0_dividend[0] = i_dividend;
	assign s0_remainder[0] = 32'd0;
	assign s0_quotient[0] = 32'd0;
	genvar _gv_k_1;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : s0_iters
			localparam k = _gv_k_1;
			divu_1iter u_s0(
				.i_dividend(s0_dividend[k]),
				.i_divisor(i_divisor),
				.i_remainder(s0_remainder[k]),
				.i_quotient(s0_quotient[k]),
				.o_dividend(s0_dividend[k + 1]),
				.o_remainder(s0_remainder[k + 1]),
				.o_quotient(s0_quotient[k + 1])
			);
		end
	endgenerate
	reg [31:0] r0_dividend;
	reg [31:0] r0_remainder;
	reg [31:0] r0_quotient;
	reg [31:0] r0_divisor;
	always @(posedge clk)
		if (rst) begin
			r0_dividend <= 0;
			r0_remainder <= 0;
			r0_quotient <= 0;
			r0_divisor <= 0;
		end
		else if (!stall) begin
			r0_dividend <= s0_dividend[4];
			r0_remainder <= s0_remainder[4];
			r0_quotient <= s0_quotient[4];
			r0_divisor <= i_divisor;
		end
	wire [31:0] s1_dividend [0:4];
	wire [31:0] s1_remainder [0:4];
	wire [31:0] s1_quotient [0:4];
	assign s1_dividend[0] = r0_dividend;
	assign s1_remainder[0] = r0_remainder;
	assign s1_quotient[0] = r0_quotient;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : s1_iters
			localparam k = _gv_k_1;
			divu_1iter u_s1(
				.i_dividend(s1_dividend[k]),
				.i_divisor(r0_divisor),
				.i_remainder(s1_remainder[k]),
				.i_quotient(s1_quotient[k]),
				.o_dividend(s1_dividend[k + 1]),
				.o_remainder(s1_remainder[k + 1]),
				.o_quotient(s1_quotient[k + 1])
			);
		end
	endgenerate
	reg [31:0] r1_dividend;
	reg [31:0] r1_remainder;
	reg [31:0] r1_quotient;
	reg [31:0] r1_divisor;
	always @(posedge clk)
		if (rst) begin
			r1_dividend <= 0;
			r1_remainder <= 0;
			r1_quotient <= 0;
			r1_divisor <= 0;
		end
		else if (!stall) begin
			r1_dividend <= s1_dividend[4];
			r1_remainder <= s1_remainder[4];
			r1_quotient <= s1_quotient[4];
			r1_divisor <= r0_divisor;
		end
	wire [31:0] s2_dividend [0:4];
	wire [31:0] s2_remainder [0:4];
	wire [31:0] s2_quotient [0:4];
	assign s2_dividend[0] = r1_dividend;
	assign s2_remainder[0] = r1_remainder;
	assign s2_quotient[0] = r1_quotient;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : s2_iters
			localparam k = _gv_k_1;
			divu_1iter u_s2(
				.i_dividend(s2_dividend[k]),
				.i_divisor(r1_divisor),
				.i_remainder(s2_remainder[k]),
				.i_quotient(s2_quotient[k]),
				.o_dividend(s2_dividend[k + 1]),
				.o_remainder(s2_remainder[k + 1]),
				.o_quotient(s2_quotient[k + 1])
			);
		end
	endgenerate
	reg [31:0] r2_dividend;
	reg [31:0] r2_remainder;
	reg [31:0] r2_quotient;
	reg [31:0] r2_divisor;
	always @(posedge clk)
		if (rst) begin
			r2_dividend <= 0;
			r2_remainder <= 0;
			r2_quotient <= 0;
			r2_divisor <= 0;
		end
		else if (!stall) begin
			r2_dividend <= s2_dividend[4];
			r2_remainder <= s2_remainder[4];
			r2_quotient <= s2_quotient[4];
			r2_divisor <= r1_divisor;
		end
	wire [31:0] s3_dividend [0:4];
	wire [31:0] s3_remainder [0:4];
	wire [31:0] s3_quotient [0:4];
	assign s3_dividend[0] = r2_dividend;
	assign s3_remainder[0] = r2_remainder;
	assign s3_quotient[0] = r2_quotient;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : s3_iters
			localparam k = _gv_k_1;
			divu_1iter u_s3(
				.i_dividend(s3_dividend[k]),
				.i_divisor(r2_divisor),
				.i_remainder(s3_remainder[k]),
				.i_quotient(s3_quotient[k]),
				.o_dividend(s3_dividend[k + 1]),
				.o_remainder(s3_remainder[k + 1]),
				.o_quotient(s3_quotient[k + 1])
			);
		end
	endgenerate
	reg [31:0] r3_dividend;
	reg [31:0] r3_remainder;
	reg [31:0] r3_quotient;
	reg [31:0] r3_divisor;
	always @(posedge clk)
		if (rst) begin
			r3_dividend <= 0;
			r3_remainder <= 0;
			r3_quotient <= 0;
			r3_divisor <= 0;
		end
		else if (!stall) begin
			r3_dividend <= s3_dividend[4];
			r3_remainder <= s3_remainder[4];
			r3_quotient <= s3_quotient[4];
			r3_divisor <= r2_divisor;
		end
	wire [31:0] s4_dividend [0:4];
	wire [31:0] s4_remainder [0:4];
	wire [31:0] s4_quotient [0:4];
	assign s4_dividend[0] = r3_dividend;
	assign s4_remainder[0] = r3_remainder;
	assign s4_quotient[0] = r3_quotient;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : s4_iters
			localparam k = _gv_k_1;
			divu_1iter u_s4(
				.i_dividend(s4_dividend[k]),
				.i_divisor(r3_divisor),
				.i_remainder(s4_remainder[k]),
				.i_quotient(s4_quotient[k]),
				.o_dividend(s4_dividend[k + 1]),
				.o_remainder(s4_remainder[k + 1]),
				.o_quotient(s4_quotient[k + 1])
			);
		end
	endgenerate
	reg [31:0] r4_dividend;
	reg [31:0] r4_remainder;
	reg [31:0] r4_quotient;
	reg [31:0] r4_divisor;
	always @(posedge clk)
		if (rst) begin
			r4_dividend <= 0;
			r4_remainder <= 0;
			r4_quotient <= 0;
			r4_divisor <= 0;
		end
		else if (!stall) begin
			r4_dividend <= s4_dividend[4];
			r4_remainder <= s4_remainder[4];
			r4_quotient <= s4_quotient[4];
			r4_divisor <= r3_divisor;
		end
	wire [31:0] s5_dividend [0:4];
	wire [31:0] s5_remainder [0:4];
	wire [31:0] s5_quotient [0:4];
	assign s5_dividend[0] = r4_dividend;
	assign s5_remainder[0] = r4_remainder;
	assign s5_quotient[0] = r4_quotient;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : s5_iters
			localparam k = _gv_k_1;
			divu_1iter u_s5(
				.i_dividend(s5_dividend[k]),
				.i_divisor(r4_divisor),
				.i_remainder(s5_remainder[k]),
				.i_quotient(s5_quotient[k]),
				.o_dividend(s5_dividend[k + 1]),
				.o_remainder(s5_remainder[k + 1]),
				.o_quotient(s5_quotient[k + 1])
			);
		end
	endgenerate
	reg [31:0] r5_dividend;
	reg [31:0] r5_remainder;
	reg [31:0] r5_quotient;
	reg [31:0] r5_divisor;
	always @(posedge clk)
		if (rst) begin
			r5_dividend <= 0;
			r5_remainder <= 0;
			r5_quotient <= 0;
			r5_divisor <= 0;
		end
		else if (!stall) begin
			r5_dividend <= s5_dividend[4];
			r5_remainder <= s5_remainder[4];
			r5_quotient <= s5_quotient[4];
			r5_divisor <= r4_divisor;
		end
	wire [31:0] s6_dividend [0:4];
	wire [31:0] s6_remainder [0:4];
	wire [31:0] s6_quotient [0:4];
	assign s6_dividend[0] = r5_dividend;
	assign s6_remainder[0] = r5_remainder;
	assign s6_quotient[0] = r5_quotient;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : s6_iters
			localparam k = _gv_k_1;
			divu_1iter u_s6(
				.i_dividend(s6_dividend[k]),
				.i_divisor(r5_divisor),
				.i_remainder(s6_remainder[k]),
				.i_quotient(s6_quotient[k]),
				.o_dividend(s6_dividend[k + 1]),
				.o_remainder(s6_remainder[k + 1]),
				.o_quotient(s6_quotient[k + 1])
			);
		end
	endgenerate
	reg [31:0] r6_dividend;
	reg [31:0] r6_remainder;
	reg [31:0] r6_quotient;
	reg [31:0] r6_divisor;
	always @(posedge clk)
		if (rst) begin
			r6_dividend <= 0;
			r6_remainder <= 0;
			r6_quotient <= 0;
			r6_divisor <= 0;
		end
		else if (!stall) begin
			r6_dividend <= s6_dividend[4];
			r6_remainder <= s6_remainder[4];
			r6_quotient <= s6_quotient[4];
			r6_divisor <= r5_divisor;
		end
	wire [31:0] s7_dividend [0:4];
	wire [31:0] s7_remainder [0:4];
	wire [31:0] s7_quotient [0:4];
	assign s7_dividend[0] = r6_dividend;
	assign s7_remainder[0] = r6_remainder;
	assign s7_quotient[0] = r6_quotient;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : s7_iters
			localparam k = _gv_k_1;
			divu_1iter u_s7(
				.i_dividend(s7_dividend[k]),
				.i_divisor(r6_divisor),
				.i_remainder(s7_remainder[k]),
				.i_quotient(s7_quotient[k]),
				.o_dividend(s7_dividend[k + 1]),
				.o_remainder(s7_remainder[k + 1]),
				.o_quotient(s7_quotient[k + 1])
			);
		end
	endgenerate
	assign o_quotient = s7_quotient[4];
	assign o_remainder = s7_remainder[4];
endmodule
module divu_1iter (
	i_dividend,
	i_divisor,
	i_remainder,
	i_quotient,
	o_dividend,
	o_remainder,
	o_quotient
);
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	input wire [31:0] i_remainder;
	input wire [31:0] i_quotient;
	output wire [31:0] o_dividend;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	wire [31:0] next_remainder;
	assign next_remainder = (i_remainder << 1) | ((i_dividend >> 31) & 32'd1);
	wire lt;
	assign lt = next_remainder < i_divisor;
	assign o_quotient = (lt ? i_quotient << 1 : (i_quotient << 1) | 32'd1);
	assign o_remainder = (lt ? next_remainder : next_remainder - i_divisor);
	assign o_dividend = i_dividend << 1;
endmodule
`default_nettype none
`default_nettype none
module skidbuffer (
	i_clk,
	i_reset,
	i_valid,
	o_ready,
	i_data,
	o_valid,
	i_ready,
	o_data
);
	parameter [0:0] OPT_LOWPOWER = 0;
	parameter [0:0] OPT_OUTREG = 1;
	parameter [0:0] OPT_PASSTHROUGH = 0;
	parameter DW = 8;
	parameter [0:0] OPT_INITIAL = 1'b1;
	input wire i_clk;
	input wire i_reset;
	input wire i_valid;
	output wire o_ready;
	input wire [DW - 1:0] i_data;
	output wire o_valid;
	input wire i_ready;
	output reg [DW - 1:0] o_data;
	wire [DW - 1:0] w_data;
	generate
		if (OPT_PASSTHROUGH) begin : PASSTHROUGH
			assign {o_valid, o_ready} = {i_valid, i_ready};
			always @(*)
				if (!i_valid && OPT_LOWPOWER)
					o_data = 0;
				else
					o_data = i_data;
			assign w_data = 0;
			wire unused_passthrough;
			assign unused_passthrough = &{1'b0, i_clk, i_reset};
		end
		else begin : LOGIC
			reg r_valid;
			reg [DW - 1:0] r_data;
			initial if (OPT_INITIAL)
				r_valid = 0;
			always @(posedge i_clk)
				if (i_reset)
					r_valid <= 0;
				else if ((i_valid && o_ready) && (o_valid && !i_ready))
					r_valid <= 1;
				else if (i_ready)
					r_valid <= 0;
			initial if (OPT_INITIAL)
				r_data = 0;
			always @(posedge i_clk)
				if (OPT_LOWPOWER && i_reset)
					r_data <= 0;
				else if (OPT_LOWPOWER && (!o_valid || i_ready))
					r_data <= 0;
				else if (((!OPT_LOWPOWER || !OPT_OUTREG) || i_valid) && o_ready)
					r_data <= i_data;
			assign w_data = r_data;
			assign o_ready = !r_valid;
			if (!OPT_OUTREG) begin : NET_OUTPUT
				assign o_valid = !i_reset && (i_valid || r_valid);
				always @(*)
					if (r_valid)
						o_data = r_data;
					else if (!OPT_LOWPOWER || i_valid)
						o_data = i_data;
					else
						o_data = 0;
			end
			else begin : REG_OUTPUT
				reg ro_valid;
				initial if (OPT_INITIAL)
					ro_valid = 0;
				always @(posedge i_clk)
					if (i_reset)
						ro_valid <= 0;
					else if (!o_valid || i_ready)
						ro_valid <= i_valid || r_valid;
				assign o_valid = ro_valid;
				initial if (OPT_INITIAL)
					o_data = 0;
				always @(posedge i_clk)
					if (OPT_LOWPOWER && i_reset)
						o_data <= 0;
					else if (!o_valid || i_ready) begin
						if (r_valid)
							o_data <= r_data;
						else if (!OPT_LOWPOWER || i_valid)
							o_data <= i_data;
						else
							o_data <= 0;
					end
			end
		end
	endgenerate
	wire unused;
	assign unused = &{1'b0, w_data};
endmodule
module Disasm (
	insn,
	disasm
);
	parameter PREFIX = "D";
	input wire [31:0] insn;
	output wire [255:0] disasm;
endmodule
module RegFile (
	rd,
	rd_data,
	rs1,
	rs1_data,
	rs2,
	rs2_data,
	clk,
	we,
	rst
);
	reg _sv2v_0;
	input wire [4:0] rd;
	input wire [31:0] rd_data;
	input wire [4:0] rs1;
	output reg [31:0] rs1_data;
	input wire [4:0] rs2;
	output reg [31:0] rs2_data;
	input wire clk;
	input wire we;
	input wire rst;
	localparam signed [31:0] NumRegs = 32;
	reg [31:0] regs [0:31];
	integer i;
	always @(*) begin
		if (_sv2v_0)
			;
		rs1_data = (rs1 == 0 ? 0 : regs[rs1]);
		rs2_data = (rs2 == 0 ? 0 : regs[rs2]);
	end
	always @(posedge clk)
		if (rst)
			for (i = 0; i < NumRegs; i = i + 1)
				regs[i] <= 0;
		else begin
			if (we && (rd != 0))
				regs[rd] <= rd_data;
			regs[0] <= 0;
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype none
module SystemResourceCheck (
	external_clk_25MHz,
	btn,
	led
);
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output wire [7:0] led;
	wire clk;
	wire clk_locked;
	wire ignore0;
	wire ignore1;
	MyClockGen clock_gen(
		.input_clk_25MHz(external_clk_25MHz),
		.clk_125MHz(ignore0),
		.clk_25MHz(ignore1),
		.clk_proc(clk),
		.locked(clk_locked)
	);
	wire rst = !clk_locked;
	generate
		if (1) begin : axil_mem_ro
			localparam signed [31:0] ADDR_WIDTH = 32;
			localparam signed [31:0] DATA_WIDTH = 32;
			wire ARREADY;
			wire ARVALID;
			wire [31:0] ARADDR;
			wire [2:0] ARPROT;
			wire RREADY;
			wire RVALID;
			wire [31:0] RDATA;
			wire [1:0] RRESP;
			wire AWREADY;
			wire AWVALID;
			wire [31:0] AWADDR;
			wire [2:0] AWPROT;
			wire WREADY;
			wire WVALID;
			wire [31:0] WDATA;
			wire [3:0] WSTRB;
			wire BREADY;
			wire BVALID;
			wire [1:0] BRESP;
		end
		if (1) begin : axil_mem_rw
			localparam signed [31:0] ADDR_WIDTH = 32;
			localparam signed [31:0] DATA_WIDTH = 32;
			wire ARREADY;
			wire ARVALID;
			wire [31:0] ARADDR;
			wire [2:0] ARPROT;
			wire RREADY;
			wire RVALID;
			wire [31:0] RDATA;
			wire [1:0] RRESP;
			wire AWREADY;
			wire AWVALID;
			wire [31:0] AWADDR;
			wire [2:0] AWPROT;
			wire WREADY;
			wire WVALID;
			wire [31:0] WDATA;
			wire [3:0] WSTRB;
			wire BREADY;
			wire BVALID;
			wire [1:0] BRESP;
		end
	endgenerate
	localparam _param_F80E1_OPT_SKIDBUFFER = 1;
	localparam _param_F80E1_OPT_LOWPOWER = 0;
	localparam _param_F80E1_NUM_WORDS = 128;
	generate
		if (1) begin : memory
			localparam [0:0] OPT_SKIDBUFFER = _param_F80E1_OPT_SKIDBUFFER;
			localparam [0:0] OPT_LOWPOWER = _param_F80E1_OPT_LOWPOWER;
			localparam NUM_WORDS = _param_F80E1_NUM_WORDS;
			wire ACLK;
			wire ARESETn;
			localparam ADDRLSB = 2;
			wire i_reset = !ARESETn;
			wire axil_write_ready;
			wire [29:0] awskd_addr;
			wire [31:0] wskd_data;
			wire [3:0] wskd_strb;
			reg axil_bvalid;
			wire axil_read_ready;
			wire [29:0] arskd_addr;
			reg [31:0] axil_read_data;
			reg axil_read_valid;
			wire t_axil_read_ready;
			wire [29:0] t_arskd_addr;
			reg [31:0] t_axil_read_data;
			reg t_axil_read_valid;
			localparam signed [31:0] AddrLsb = 2;
			localparam signed [31:0] AddrMsb = 8;
			reg [31:0] mem_array [0:127];
			if (OPT_SKIDBUFFER) begin : SKIDBUFFER_WRITE
				wire awskd_valid;
				wire wskd_valid;
				skidbuffer #(
					.OPT_OUTREG(0),
					.OPT_LOWPOWER(OPT_LOWPOWER),
					.DW(30)
				) axilawskid(
					.i_clk(ACLK),
					.i_reset(i_reset),
					.i_valid(SystemResourceCheck.axil_mem_rw.AWVALID),
					.o_ready(SystemResourceCheck.axil_mem_rw.AWREADY),
					.i_data(SystemResourceCheck.axil_mem_rw.AWADDR[31:ADDRLSB]),
					.o_valid(awskd_valid),
					.i_ready(axil_write_ready),
					.o_data(awskd_addr)
				);
				skidbuffer #(
					.OPT_OUTREG(0),
					.OPT_LOWPOWER(OPT_LOWPOWER),
					.DW(36)
				) axilwskid(
					.i_clk(ACLK),
					.i_reset(i_reset),
					.i_valid(SystemResourceCheck.axil_mem_rw.WVALID),
					.o_ready(SystemResourceCheck.axil_mem_rw.WREADY),
					.i_data({SystemResourceCheck.axil_mem_rw.WDATA, SystemResourceCheck.axil_mem_rw.WSTRB}),
					.o_valid(wskd_valid),
					.i_ready(axil_write_ready),
					.o_data({wskd_data, wskd_strb})
				);
				assign axil_write_ready = (awskd_valid && wskd_valid) && (!SystemResourceCheck.axil_mem_rw.BVALID || SystemResourceCheck.axil_mem_rw.BREADY);
			end
			else begin : SIMPLE_WRITES
				reg axil_awready;
				initial axil_awready = 1'b0;
				always @(posedge ACLK)
					if (!ARESETn)
						axil_awready <= 1'b0;
					else
						axil_awready <= (!axil_awready && (SystemResourceCheck.axil_mem_rw.AWVALID && SystemResourceCheck.axil_mem_rw.WVALID)) && (!SystemResourceCheck.axil_mem_rw.BVALID || SystemResourceCheck.axil_mem_rw.BREADY);
				assign SystemResourceCheck.axil_mem_rw.AWREADY = axil_awready;
				assign SystemResourceCheck.axil_mem_rw.WREADY = axil_awready;
				assign awskd_addr = SystemResourceCheck.axil_mem_rw.AWADDR[31:ADDRLSB];
				assign wskd_data = SystemResourceCheck.axil_mem_rw.WDATA;
				assign wskd_strb = SystemResourceCheck.axil_mem_rw.WSTRB;
				assign axil_write_ready = axil_awready;
			end
			initial axil_bvalid = 0;
			always @(posedge ACLK)
				if (i_reset)
					axil_bvalid <= 0;
				else if (axil_write_ready)
					axil_bvalid <= 1;
				else if (SystemResourceCheck.axil_mem_rw.BREADY)
					axil_bvalid <= 0;
			assign SystemResourceCheck.axil_mem_rw.BVALID = axil_bvalid;
			assign SystemResourceCheck.axil_mem_rw.BRESP = 2'b00;
			if (OPT_SKIDBUFFER) begin : SKIDBUFFER_READ
				wire arskd_valid;
				skidbuffer #(
					.OPT_OUTREG(0),
					.OPT_LOWPOWER(OPT_LOWPOWER),
					.DW(30)
				) axilarskid(
					.i_clk(ACLK),
					.i_reset(i_reset),
					.i_valid(SystemResourceCheck.axil_mem_rw.ARVALID),
					.o_ready(SystemResourceCheck.axil_mem_rw.ARREADY),
					.i_data(SystemResourceCheck.axil_mem_rw.ARADDR[31:ADDRLSB]),
					.o_valid(arskd_valid),
					.i_ready(axil_read_ready),
					.o_data(arskd_addr)
				);
				assign axil_read_ready = arskd_valid && (!axil_read_valid || SystemResourceCheck.axil_mem_rw.RREADY);
			end
			else begin : SIMPLE_READS
				reg axil_arready;
				always @(*) axil_arready = !SystemResourceCheck.axil_mem_rw.RVALID;
				assign arskd_addr = SystemResourceCheck.axil_mem_rw.ARADDR[31:ADDRLSB];
				assign SystemResourceCheck.axil_mem_rw.ARREADY = axil_arready;
				assign axil_read_ready = SystemResourceCheck.axil_mem_rw.ARVALID && SystemResourceCheck.axil_mem_rw.ARREADY;
			end
			initial axil_read_valid = 1'b0;
			always @(posedge ACLK)
				if (i_reset)
					axil_read_valid <= 1'b0;
				else if (axil_read_ready)
					axil_read_valid <= 1'b1;
				else if (SystemResourceCheck.axil_mem_rw.RREADY)
					axil_read_valid <= 1'b0;
			assign SystemResourceCheck.axil_mem_rw.RVALID = axil_read_valid;
			assign SystemResourceCheck.axil_mem_rw.RDATA = axil_read_data;
			assign SystemResourceCheck.axil_mem_rw.RRESP = 2'b00;
			if (OPT_SKIDBUFFER) begin : T_SKIDBUFFER_READ
				wire t_arskd_valid;
				skidbuffer #(
					.OPT_OUTREG(0),
					.OPT_LOWPOWER(OPT_LOWPOWER),
					.DW(30)
				) axilarskid(
					.i_clk(ACLK),
					.i_reset(i_reset),
					.i_valid(SystemResourceCheck.axil_mem_ro.ARVALID),
					.o_ready(SystemResourceCheck.axil_mem_ro.ARREADY),
					.i_data(SystemResourceCheck.axil_mem_ro.ARADDR[31:ADDRLSB]),
					.o_valid(t_arskd_valid),
					.i_ready(t_axil_read_ready),
					.o_data(t_arskd_addr)
				);
				assign t_axil_read_ready = t_arskd_valid && (!t_axil_read_valid || SystemResourceCheck.axil_mem_ro.RREADY);
			end
			else begin : T_SIMPLE_READS
				reg t_axil_arready;
				always @(*) t_axil_arready = !SystemResourceCheck.axil_mem_ro.RVALID;
				assign t_arskd_addr = SystemResourceCheck.axil_mem_ro.ARADDR[31:ADDRLSB];
				assign SystemResourceCheck.axil_mem_ro.ARREADY = t_axil_arready;
				assign t_axil_read_ready = SystemResourceCheck.axil_mem_ro.ARVALID && SystemResourceCheck.axil_mem_ro.ARREADY;
			end
			initial t_axil_read_valid = 1'b0;
			always @(posedge ACLK)
				if (i_reset)
					t_axil_read_valid <= 1'b0;
				else if (t_axil_read_ready)
					t_axil_read_valid <= 1'b1;
				else if (SystemResourceCheck.axil_mem_ro.RREADY)
					t_axil_read_valid <= 1'b0;
			assign SystemResourceCheck.axil_mem_ro.RVALID = t_axil_read_valid;
			assign SystemResourceCheck.axil_mem_ro.RDATA = t_axil_read_data;
			assign SystemResourceCheck.axil_mem_ro.RRESP = 2'b00;
			always @(posedge ACLK)
				if (i_reset)
					;
				else if (axil_write_ready) begin
					if (wskd_strb[0])
						mem_array[awskd_addr[6:0]][7:0] <= wskd_data[7:0];
					if (wskd_strb[1])
						mem_array[awskd_addr[6:0]][15:8] <= wskd_data[15:8];
					if (wskd_strb[2])
						mem_array[awskd_addr[6:0]][23:16] <= wskd_data[23:16];
					if (wskd_strb[3])
						mem_array[awskd_addr[6:0]][31:24] <= wskd_data[31:24];
				end
			initial begin
				axil_read_data = 0;
				t_axil_read_data = 0;
			end
			always @(posedge ACLK) begin
				if (!SystemResourceCheck.axil_mem_rw.RVALID || SystemResourceCheck.axil_mem_rw.RREADY)
					axil_read_data <= mem_array[arskd_addr[6:0]];
				if (!SystemResourceCheck.axil_mem_ro.RVALID || SystemResourceCheck.axil_mem_ro.RREADY)
					t_axil_read_data <= mem_array[t_arskd_addr[6:0]];
			end
		end
	endgenerate
	assign memory.ACLK = clk;
	assign memory.ARESETn = ~rst;
	wire [31:0] trace_completed_pc;
	wire [31:0] trace_completed_insn;
	wire [31:0] trace_completed_cycle_status;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	generate
		if (1) begin : datapath
			reg _sv2v_0;
			wire clk;
			wire rst;
			wire halt;
			wire [31:0] trace_completed_pc;
			wire [31:0] trace_completed_insn;
			wire [31:0] trace_completed_cycle_status;
			localparam [6:0] OpcodeLoad = 7'b0000011;
			localparam [6:0] OpcodeStore = 7'b0100011;
			localparam [6:0] OpcodeBranch = 7'b1100011;
			localparam [6:0] OpcodeJalr = 7'b1100111;
			localparam [6:0] OpcodeMiscMem = 7'b0001111;
			localparam [6:0] OpcodeJal = 7'b1101111;
			localparam [6:0] OpcodeRegImm = 7'b0010011;
			localparam [6:0] OpcodeRegReg = 7'b0110011;
			localparam [6:0] OpcodeEnviron = 7'b1110011;
			localparam [6:0] OpcodeAuipc = 7'b0010111;
			localparam [6:0] OpcodeLui = 7'b0110111;
			reg [31:0] cycles_current;
			always @(posedge clk)
				if (rst)
					cycles_current <= 0;
				else
					cycles_current <= cycles_current + 1;
			reg [31:0] f_pc_current;
			reg [31:0] f_pc_branch_decision;
			reg [31:0] f_cycle_status;
			reg [64:0] g_state;
			reg [96:0] d_state;
			reg [192:0] x_state;
			reg [140:0] m_state;
			reg [134:0] w_state;
			reg x_branch_taken;
			reg x_we;
			wire pipeline_stall;
			reg [31:0] x_wdata;
			reg [31:0] x_rs1_data;
			reg [31:0] x_rs2_data;
			reg x_illegal_insn;
			reg [31:0] x_load_addr_raw;
			reg [31:0] x_store_addr_raw;
			reg [1:0] x_store_byte_off;
			reg [63:0] x_mulh_ss;
			reg [63:0] x_mulh_su;
			reg [63:0] x_mulh_uu;
			wire [6:0] d_funct7 = d_state[64:58];
			wire [4:0] d_rs2 = d_state[57:53];
			wire [4:0] d_rs1 = d_state[52:48];
			wire [4:0] d_rd = d_state[44:40];
			wire [2:0] d_funct3 = d_state[47:45];
			wire [6:0] d_opcode = d_state[39:33];
			wire d_reads_rs1 = ((d_opcode != OpcodeLui) && (d_opcode != OpcodeAuipc)) && (d_opcode != OpcodeJal);
			wire d_reads_rs2 = ((d_opcode == OpcodeRegReg) || (d_opcode == OpcodeBranch)) || (d_opcode == OpcodeStore);
			wire d_is_div = ((d_state[0] && (d_opcode == OpcodeRegReg)) && (d_state[64:58] == 7'd1)) && d_funct3[2];
			wire x_is_load = x_state[96] && (x_state[70-:7] == OpcodeLoad);
			wire load_use_stall = (x_is_load && (x_state[75-:5] != 0)) && ((d_reads_rs1 && (d_rs1 == x_state[75-:5])) || (d_reads_rs2 && (d_rs2 == x_state[75-:5])));
			localparam signed [31:0] DVS = 8;
			reg [4:0] div_pipe_rd [0:7];
			reg div_pipe_valid [0:7];
			reg div_pipe_is_div [0:7];
			reg div_pipe_is_divu [0:7];
			reg div_pipe_is_rem [0:7];
			reg div_pipe_is_remu [0:7];
			reg div_pipe_vinsn [0:7];
			reg [31:0] div_pipe_rs1 [0:7];
			reg [31:0] div_pipe_rs2 [0:7];
			reg [31:0] div_pipe_pc [0:7];
			reg [31:0] div_pipe_insn [0:7];
			reg [31:0] div_pipe_cstat [0:7];
			reg div_stall_raw;
			reg div_nondiv_stall;
			reg div_any_inflight;
			always @(*) begin
				if (_sv2v_0)
					;
				div_stall_raw = 0;
				div_any_inflight = 0;
				begin : sv2v_autoblock_1
					reg signed [31:0] i;
					for (i = 0; i < DVS; i = i + 1)
						if (div_pipe_valid[i])
							div_any_inflight = 1;
				end
				if (d_reads_rs1 && (d_rs1 != 0)) begin : sv2v_autoblock_2
					reg signed [31:0] i;
					for (i = 0; i < (d_is_div ? DVS : 7); i = i + 1)
						if (div_pipe_valid[i] && (div_pipe_rd[i] == d_rs1))
							div_stall_raw = 1;
				end
				if (d_reads_rs2 && (d_rs2 != 0)) begin : sv2v_autoblock_3
					reg signed [31:0] i;
					for (i = 0; i < (d_is_div ? DVS : 7); i = i + 1)
						if (div_pipe_valid[i] && (div_pipe_rd[i] == d_rs2))
							div_stall_raw = 1;
				end
				div_nondiv_stall = ((div_any_inflight && !div_pipe_valid[7]) && d_state[0]) && !d_is_div;
			end
			wire x_is_div = ((x_state[96] && (x_state[70-:7] == OpcodeRegReg)) && (x_state[160:154] == 7'd1)) && x_state[143:141][2];
			wire div_mem_conflict = (div_pipe_valid[7] && x_state[96]) && !x_is_div;
			assign pipeline_stall = ((load_use_stall || div_stall_raw) || div_nondiv_stall) || div_mem_conflict;
			assign SystemResourceCheck.axil_mem_ro.ARPROT = 3'b000;
			assign SystemResourceCheck.axil_mem_ro.ARADDR = {f_pc_current[31:2], 2'b00};
			assign SystemResourceCheck.axil_mem_ro.ARVALID = (!rst && !pipeline_stall) && !x_branch_taken;
			assign SystemResourceCheck.axil_mem_ro.RREADY = !rst && !pipeline_stall;
			assign SystemResourceCheck.axil_mem_ro.AWVALID = 1'b0;
			assign SystemResourceCheck.axil_mem_ro.AWADDR = 32'd0;
			assign SystemResourceCheck.axil_mem_ro.AWPROT = 3'd0;
			assign SystemResourceCheck.axil_mem_ro.WVALID = 1'b0;
			assign SystemResourceCheck.axil_mem_ro.WDATA = 32'd0;
			assign SystemResourceCheck.axil_mem_ro.WSTRB = 4'd0;
			assign SystemResourceCheck.axil_mem_ro.BREADY = 1'b1;
			wire g_req_fire = SystemResourceCheck.axil_mem_ro.ARVALID && SystemResourceCheck.axil_mem_ro.ARREADY;
			wire g_rsp_fire = SystemResourceCheck.axil_mem_ro.RVALID && SystemResourceCheck.axil_mem_ro.RREADY;
			wire [31:0] d_rs1_raw;
			wire [31:0] d_rs2_raw;
			reg [31:0] d_rs1_data;
			reg [31:0] d_rs2_data;
			RegFile rf(
				.rd(w_state[36-:5]),
				.rd_data(w_state[31-:32]),
				.rs1(d_rs1),
				.rs1_data(d_rs1_raw),
				.rs2(d_rs2),
				.rs2_data(d_rs2_raw),
				.clk(clk),
				.we(w_state[38] && w_state[37]),
				.rst(rst)
			);
			wire d_fwd_ex = ((x_state[96] && x_we) && (x_state[75-:5] != 0)) && (x_state[70-:7] != OpcodeLoad);
			wire d_fwd_mem = ((m_state[44] && m_state[43]) && (m_state[42-:5] != 0)) && !m_state[5];
			always @(*) begin
				if (_sv2v_0)
					;
				d_rs1_data = d_rs1_raw;
				d_rs2_data = d_rs2_raw;
				if (d_rs1 != 0) begin
					if (d_fwd_ex && (x_state[75-:5] == d_rs1))
						d_rs1_data = x_wdata;
					else if (d_fwd_mem && (m_state[42-:5] == d_rs1))
						d_rs1_data = m_state[37-:32];
					else if ((w_state[38] && w_state[37]) && (w_state[36-:5] == d_rs1))
						d_rs1_data = w_state[31-:32];
				end
				if (d_rs2 != 0) begin
					if (d_fwd_ex && (x_state[75-:5] == d_rs2))
						d_rs2_data = x_wdata;
					else if (d_fwd_mem && (m_state[42-:5] == d_rs2))
						d_rs2_data = m_state[37-:32];
					else if ((w_state[38] && w_state[37]) && (w_state[36-:5] == d_rs2))
						d_rs2_data = w_state[31-:32];
				end
			end
			reg [31:0] x_cla_a;
			reg [31:0] x_cla_b;
			reg x_cla_cin;
			wire [31:0] x_cla_sum;
			CarryLookaheadAdder cla32(
				.a(x_cla_a),
				.b(x_cla_b),
				.cin(x_cla_cin),
				.sum(x_cla_sum)
			);
			wire [11:0] x_imm_i = x_state[160:149];
			wire [11:0] x_imm_s = {x_state[95-:7], x_state[75-:5]};
			wire [4:0] x_shamt = x_state[153:149];
			wire [12:0] x_imm_b = {x_state[95], x_state[71], x_state[94:89], x_state[75:72], 1'b0};
			wire [20:0] x_imm_j = {x_state[160], x_state[148:141], x_state[149], x_state[159:150], 1'b0};
			wire [31:0] x_imm_u = {x_state[160:141], 12'b000000000000};
			wire [31:0] x_imm_i_sext = {{20 {x_imm_i[11]}}, x_imm_i};
			wire [31:0] x_imm_s_sext = {{20 {x_imm_s[11]}}, x_imm_s};
			wire [31:0] x_imm_b_sext = {{19 {x_imm_b[12]}}, x_imm_b};
			wire [31:0] x_imm_j_sext = {{11 {x_imm_j[20]}}, x_imm_j};
			always @(*) begin
				if (_sv2v_0)
					;
				x_load_addr_raw = x_rs1_data + x_imm_i_sext;
				x_store_addr_raw = x_rs1_data + x_imm_s_sext;
				x_store_byte_off = x_store_addr_raw[1:0];
				x_mulh_ss = $signed({{32 {x_rs1_data[31]}}, x_rs1_data}) * $signed({{32 {x_rs2_data[31]}}, x_rs2_data});
				x_mulh_su = $signed({{32 {x_rs1_data[31]}}, x_rs1_data}) * $signed({32'b00000000000000000000000000000000, x_rs2_data});
				x_mulh_uu = {32'b00000000000000000000000000000000, x_rs1_data} * {32'b00000000000000000000000000000000, x_rs2_data};
			end
			always @(*) begin
				if (_sv2v_0)
					;
				x_rs1_data = x_state[63-:32];
				x_rs2_data = x_state[31-:32];
				if ((((m_state[44] && m_state[43]) && !m_state[5]) && (m_state[42-:5] != 0)) && (m_state[42-:5] == x_state[83-:5]))
					x_rs1_data = m_state[37-:32];
				else if (((w_state[38] && w_state[37]) && (w_state[36-:5] != 0)) && (w_state[36-:5] == x_state[83-:5]))
					x_rs1_data = w_state[31-:32];
				if ((((m_state[44] && m_state[43]) && !m_state[5]) && (m_state[42-:5] != 0)) && (m_state[42-:5] == x_state[88-:5]))
					x_rs2_data = m_state[37-:32];
				else if (((w_state[38] && w_state[37]) && (w_state[36-:5] != 0)) && (w_state[36-:5] == x_state[88-:5]))
					x_rs2_data = w_state[31-:32];
			end
			reg dmem_issue_load;
			reg dmem_issue_store;
			reg [31:0] dmem_addr;
			reg [31:0] dmem_wdata_x;
			reg [3:0] dmem_wstrb_x;
			always @(*) begin
				if (_sv2v_0)
					;
				x_we = 0;
				x_wdata = 0;
				x_illegal_insn = 0;
				x_branch_taken = 0;
				f_pc_branch_decision = x_state[192-:32] + 4;
				dmem_issue_load = 0;
				dmem_issue_store = 0;
				dmem_addr = 0;
				dmem_wdata_x = 0;
				dmem_wstrb_x = 0;
				x_cla_a = 0;
				x_cla_b = 0;
				x_cla_cin = 0;
				(* full_case, parallel_case *)
				case (x_state[70-:7])
					OpcodeLui: begin
						x_we = 1;
						x_wdata = x_imm_u;
					end
					OpcodeAuipc: begin
						x_we = 1;
						x_wdata = x_state[192-:32] + x_imm_u;
					end
					OpcodeRegImm: begin
						x_we = 1;
						if (x_state[78-:3] == 3'b000) begin
							x_cla_a = x_rs1_data;
							x_cla_b = x_imm_i_sext;
							x_wdata = x_cla_sum;
						end
						else if (x_state[78-:3] == 3'b010)
							x_wdata = ($signed(x_rs1_data) < $signed(x_imm_i_sext) ? 32'd1 : 32'd0);
						else if (x_state[78-:3] == 3'b011)
							x_wdata = (x_rs1_data < x_imm_i_sext ? 32'd1 : 32'd0);
						else if (x_state[78-:3] == 3'b100)
							x_wdata = x_rs1_data ^ x_imm_i_sext;
						else if (x_state[78-:3] == 3'b110)
							x_wdata = x_rs1_data | x_imm_i_sext;
						else if (x_state[78-:3] == 3'b111)
							x_wdata = x_rs1_data & x_imm_i_sext;
						else if ((x_state[78-:3] == 3'b001) && (x_state[95-:7] == 0))
							x_wdata = x_rs1_data << x_shamt;
						else if ((x_state[78-:3] == 3'b101) && (x_state[95-:7] == 0))
							x_wdata = x_rs1_data >> x_shamt;
						else if ((x_state[78-:3] == 3'b101) && (x_state[95-:7] == 7'b0100000))
							x_wdata = $signed(x_rs1_data) >>> x_shamt;
						else
							x_illegal_insn = 1;
					end
					OpcodeRegReg: begin
						x_we = 1;
						if ((x_state[95-:7] == 0) && (x_state[78-:3] == 3'b000)) begin
							x_cla_a = x_rs1_data;
							x_cla_b = x_rs2_data;
							x_wdata = x_cla_sum;
						end
						else if ((x_state[95-:7] == 7'b0100000) && (x_state[78-:3] == 3'b000)) begin
							x_cla_a = x_rs1_data;
							x_cla_b = ~x_rs2_data;
							x_cla_cin = 1;
							x_wdata = x_cla_sum;
						end
						else if ((x_state[95-:7] == 0) && (x_state[78-:3] == 3'b001))
							x_wdata = x_rs1_data << x_rs2_data[4:0];
						else if ((x_state[95-:7] == 0) && (x_state[78-:3] == 3'b010))
							x_wdata = ($signed(x_rs1_data) < $signed(x_rs2_data) ? 32'd1 : 32'd0);
						else if ((x_state[95-:7] == 0) && (x_state[78-:3] == 3'b011))
							x_wdata = (x_rs1_data < x_rs2_data ? 32'd1 : 32'd0);
						else if ((x_state[95-:7] == 0) && (x_state[78-:3] == 3'b100))
							x_wdata = x_rs1_data ^ x_rs2_data;
						else if ((x_state[95-:7] == 0) && (x_state[78-:3] == 3'b101))
							x_wdata = x_rs1_data >> x_rs2_data[4:0];
						else if ((x_state[95-:7] == 7'b0100000) && (x_state[78-:3] == 3'b101))
							x_wdata = $signed(x_rs1_data) >>> x_rs2_data[4:0];
						else if ((x_state[95-:7] == 0) && (x_state[78-:3] == 3'b110))
							x_wdata = x_rs1_data | x_rs2_data;
						else if ((x_state[95-:7] == 0) && (x_state[78-:3] == 3'b111))
							x_wdata = x_rs1_data & x_rs2_data;
						else if ((x_state[95-:7] == 7'd1) && (x_state[78-:3] == 3'b000))
							x_wdata = x_rs1_data * x_rs2_data;
						else if ((x_state[95-:7] == 7'd1) && (x_state[78-:3] == 3'b001))
							x_wdata = x_mulh_ss[63:32];
						else if ((x_state[95-:7] == 7'd1) && (x_state[78-:3] == 3'b010))
							x_wdata = x_mulh_su[63:32];
						else if ((x_state[95-:7] == 7'd1) && (x_state[78-:3] == 3'b011))
							x_wdata = x_mulh_uu[63:32];
						else if ((x_state[95-:7] == 7'd1) && x_state[78])
							x_we = 0;
						else
							x_illegal_insn = 1;
					end
					OpcodeLoad: begin
						x_we = 1;
						x_wdata = {x_load_addr_raw[31:2], 2'b00};
						dmem_issue_load = x_state[96];
						dmem_addr = {x_load_addr_raw[31:2], 2'b00};
					end
					OpcodeStore: begin
						dmem_issue_store = x_state[96];
						dmem_addr = {x_store_addr_raw[31:2], 2'b00};
						case (x_state[78-:3])
							3'b000: begin
								dmem_wstrb_x = 4'b0001 << x_store_byte_off;
								dmem_wdata_x = {24'd0, x_rs2_data[7:0]} << (x_store_byte_off * 8);
							end
							3'b001: begin
								dmem_wstrb_x = 4'b0011 << x_store_byte_off;
								dmem_wdata_x = {16'd0, x_rs2_data[15:0]} << (x_store_byte_off * 8);
							end
							3'b010: begin
								dmem_wstrb_x = 4'b1111;
								dmem_wdata_x = x_rs2_data;
							end
							default: x_illegal_insn = 1;
						endcase
					end
					OpcodeJal: begin
						x_we = 1;
						x_wdata = x_state[192-:32] + 4;
						x_branch_taken = 1;
						f_pc_branch_decision = x_state[192-:32] + x_imm_j_sext;
					end
					OpcodeJalr: begin
						x_we = 1;
						x_wdata = x_state[192-:32] + 4;
						x_branch_taken = 1;
						f_pc_branch_decision = (x_rs1_data + x_imm_i_sext) & ~32'd1;
					end
					OpcodeBranch: begin
						if (x_state[78-:3] == 3'b000)
							x_branch_taken = x_rs1_data == x_rs2_data;
						else if (x_state[78-:3] == 3'b001)
							x_branch_taken = x_rs1_data != x_rs2_data;
						else if (x_state[78-:3] == 3'b100)
							x_branch_taken = $signed(x_rs1_data) < $signed(x_rs2_data);
						else if (x_state[78-:3] == 3'b101)
							x_branch_taken = $signed(x_rs1_data) >= $signed(x_rs2_data);
						else if (x_state[78-:3] == 3'b110)
							x_branch_taken = x_rs1_data < x_rs2_data;
						else if (x_state[78-:3] == 3'b111)
							x_branch_taken = x_rs1_data >= x_rs2_data;
						else
							x_illegal_insn = 1;
						if (x_branch_taken && !x_illegal_insn)
							f_pc_branch_decision = x_state[192-:32] + x_imm_b_sext;
					end
					OpcodeEnviron:
						;
					OpcodeMiscMem:
						;
					default: x_illegal_insn = 1;
				endcase
			end
			assign SystemResourceCheck.axil_mem_rw.ARPROT = 3'b000;
			assign SystemResourceCheck.axil_mem_rw.ARADDR = dmem_addr;
			assign SystemResourceCheck.axil_mem_rw.ARVALID = dmem_issue_load;
			assign SystemResourceCheck.axil_mem_rw.RREADY = 1'b1;
			assign SystemResourceCheck.axil_mem_rw.AWPROT = 3'b000;
			assign SystemResourceCheck.axil_mem_rw.AWADDR = dmem_addr;
			assign SystemResourceCheck.axil_mem_rw.AWVALID = dmem_issue_store;
			assign SystemResourceCheck.axil_mem_rw.WDATA = dmem_wdata_x;
			assign SystemResourceCheck.axil_mem_rw.WSTRB = dmem_wstrb_x;
			assign SystemResourceCheck.axil_mem_rw.WVALID = dmem_issue_store;
			assign SystemResourceCheck.axil_mem_rw.BREADY = 1'b1;
			wire [31:0] d_div_rs1_abs = (d_rs1_data[31] ? ~d_rs1_data + 1 : d_rs1_data);
			wire [31:0] d_div_rs2_abs = (d_rs2_data[31] ? ~d_rs2_data + 1 : d_rs2_data);
			wire div_issue = ((d_is_div && !pipeline_stall) && !x_branch_taken) && !rst;
			reg [31:0] div_i_dividend;
			reg [31:0] div_i_divisor;
			always @(*) begin
				if (_sv2v_0)
					;
				div_i_dividend = 0;
				div_i_divisor = 1;
				if (div_issue) begin
					if ((d_funct3 == 3'b100) || (d_funct3 == 3'b110)) begin
						div_i_dividend = d_div_rs1_abs;
						div_i_divisor = d_div_rs2_abs;
					end
					else begin
						div_i_dividend = d_rs1_data;
						div_i_divisor = d_rs2_data;
					end
				end
			end
			wire [31:0] div_o_q;
			wire [31:0] div_o_r;
			DividerUnsignedPipelined divider(
				.clk(clk),
				.rst(rst),
				.stall(1'b0),
				.i_dividend(div_i_dividend),
				.i_divisor(div_i_divisor),
				.o_quotient(div_o_q),
				.o_remainder(div_o_r)
			);
			reg [31:0] div_q_r;
			reg [31:0] div_r_r;
			always @(posedge clk)
				if (rst) begin
					div_q_r <= 0;
					div_r_r <= 0;
				end
				else begin
					div_q_r <= div_o_q;
					div_r_r <= div_o_r;
				end
			reg [31:0] div_wdata;
			always @(*) begin
				if (_sv2v_0)
					;
				div_wdata = 0;
				if (div_pipe_valid[7]) begin
					if (div_pipe_is_div[7]) begin
						if (div_pipe_rs2[7] == 0)
							div_wdata = 32'hffffffff;
						else if ((div_pipe_rs1[7] == 32'h80000000) && (div_pipe_rs2[7] == 32'hffffffff))
							div_wdata = 32'h80000000;
						else if (div_pipe_rs1[7][31] ^ div_pipe_rs2[7][31])
							div_wdata = ~div_q_r + 1;
						else
							div_wdata = div_q_r;
					end
					else if (div_pipe_is_divu[7]) begin
						if (div_pipe_rs2[7] == 0)
							div_wdata = 32'hffffffff;
						else
							div_wdata = div_q_r;
					end
					else if (div_pipe_is_rem[7]) begin
						if (div_pipe_rs2[7] == 0)
							div_wdata = div_pipe_rs1[7];
						else if ((div_pipe_rs1[7] == 32'h80000000) && (div_pipe_rs2[7] == 32'hffffffff))
							div_wdata = 0;
						else if (div_pipe_rs1[7][31])
							div_wdata = ~div_r_r + 1;
						else
							div_wdata = div_r_r;
					end
					else if (div_pipe_rs2[7] == 0)
						div_wdata = div_pipe_rs1[7];
					else
						div_wdata = div_r_r;
				end
			end
			wire [31:0] m_load_data_q = SystemResourceCheck.axil_mem_rw.RDATA;
			always @(posedge clk)
				if (rst) begin
					f_pc_current <= 0;
					f_cycle_status <= 32'd1;
					g_state <= 65'h00000000000000008;
					d_state <= 97'h0000000000000000000000008;
					x_state <= 193'h0000000000000000000000008000000000000000000000000;
					m_state <= 141'h000000000000000000000000800000000000;
					w_state <= 135'h0000000000000000000000020000000000;
					begin : sv2v_autoblock_4
						reg signed [31:0] i;
						for (i = 0; i < DVS; i = i + 1)
							begin
								div_pipe_rd[i] <= 0;
								div_pipe_valid[i] <= 0;
								div_pipe_rs1[i] <= 0;
								div_pipe_rs2[i] <= 0;
								div_pipe_is_div[i] <= 0;
								div_pipe_is_divu[i] <= 0;
								div_pipe_is_rem[i] <= 0;
								div_pipe_is_remu[i] <= 0;
								div_pipe_pc[i] <= 0;
								div_pipe_insn[i] <= 0;
								div_pipe_vinsn[i] <= 0;
								div_pipe_cstat[i] <= 32'd1;
							end
					end
				end
				else begin
					if (x_branch_taken)
						f_pc_current <= f_pc_branch_decision;
					else if (!pipeline_stall)
						f_pc_current <= f_pc_current + 4;
					f_cycle_status <= 32'd1;
					if (x_branch_taken)
						g_state <= 65'h00000000000000010;
					else if (g_req_fire)
						g_state <= {f_pc_current, f_cycle_status, 1'd1};
					if (x_branch_taken)
						d_state <= 97'h0000000000000000000000010;
					else if (!pipeline_stall && g_rsp_fire)
						d_state <= {sv2v_cast_32(g_state[64-:32]), sv2v_cast_32(SystemResourceCheck.axil_mem_ro.RDATA), sv2v_cast_32(g_state[32-:32]), g_state[0]};
					else if (pipeline_stall)
						d_state <= d_state;
					begin : sv2v_autoblock_5
						reg signed [31:0] i;
						for (i = 7; i > 0; i = i - 1)
							begin
								div_pipe_rd[i] <= div_pipe_rd[i - 1];
								div_pipe_valid[i] <= div_pipe_valid[i - 1];
								div_pipe_rs1[i] <= div_pipe_rs1[i - 1];
								div_pipe_rs2[i] <= div_pipe_rs2[i - 1];
								div_pipe_is_div[i] <= div_pipe_is_div[i - 1];
								div_pipe_is_divu[i] <= div_pipe_is_divu[i - 1];
								div_pipe_is_rem[i] <= div_pipe_is_rem[i - 1];
								div_pipe_is_remu[i] <= div_pipe_is_remu[i - 1];
								div_pipe_pc[i] <= div_pipe_pc[i - 1];
								div_pipe_insn[i] <= div_pipe_insn[i - 1];
								div_pipe_vinsn[i] <= div_pipe_vinsn[i - 1];
								div_pipe_cstat[i] <= div_pipe_cstat[i - 1];
							end
					end
					if ((d_is_div && !pipeline_stall) && !x_branch_taken) begin
						div_pipe_valid[0] <= 1;
						div_pipe_rd[0] <= d_rd;
						div_pipe_rs1[0] <= d_rs1_data;
						div_pipe_rs2[0] <= d_rs2_data;
						div_pipe_pc[0] <= d_state[96-:32];
						div_pipe_insn[0] <= d_state[64-:32];
						div_pipe_vinsn[0] <= d_state[0];
						div_pipe_cstat[0] <= d_state[32-:32];
						div_pipe_is_div[0] <= d_funct3 == 3'b100;
						div_pipe_is_divu[0] <= d_funct3 == 3'b101;
						div_pipe_is_rem[0] <= d_funct3 == 3'b110;
						div_pipe_is_remu[0] <= d_funct3 == 3'b111;
					end
					else begin
						div_pipe_valid[0] <= 0;
						div_pipe_rd[0] <= 0;
						div_pipe_rs1[0] <= 0;
						div_pipe_rs2[0] <= 0;
						div_pipe_pc[0] <= 0;
						div_pipe_insn[0] <= 0;
						div_pipe_vinsn[0] <= 0;
						div_pipe_cstat[0] <= 32'd1;
						div_pipe_is_div[0] <= 0;
						div_pipe_is_divu[0] <= 0;
						div_pipe_is_rem[0] <= 0;
						div_pipe_is_remu[0] <= 0;
					end
					if (x_branch_taken)
						x_state <= 193'h0000000000000000000000010000000000000000000000000;
					else if ((load_use_stall || div_stall_raw) || div_nondiv_stall)
						x_state <= {64'h0000000000000000, (load_use_stall ? 32'd16 : 32'd2), 97'h0000000000000000000000000};
					else if (!div_mem_conflict)
						x_state <= {sv2v_cast_32(d_state[96-:32]), sv2v_cast_32(d_state[64-:32]), sv2v_cast_32(d_state[32-:32]), d_state[0], d_funct7, d_rs2, d_rs1, d_funct3, d_rd, d_opcode, d_rs1_data, d_rs2_data};
					if (div_pipe_valid[7])
						m_state <= {div_pipe_pc[7], div_pipe_insn[7], div_pipe_cstat[7], div_pipe_vinsn[7], div_pipe_rd[7] != 32'sd0, div_pipe_rd[7], div_wdata, 6'h00};
					else if (x_is_div)
						m_state <= 141'h000000000000000000000000400000000000;
					else
						m_state <= {sv2v_cast_32(x_state[192-:32]), sv2v_cast_32(x_state[160-:32]), sv2v_cast_32(x_state[128-:32]), x_state[96], x_we, sv2v_cast_5(x_state[75-:5]), x_wdata, x_state[70-:7] == OpcodeLoad, sv2v_cast_3(x_state[78-:3]), x_load_addr_raw[1:0]};
					w_state <= {sv2v_cast_32(m_state[140-:32]), sv2v_cast_32(m_state[108-:32]), sv2v_cast_32(m_state[76-:32]), m_state[44], m_state[43], sv2v_cast_5(m_state[42-:5]), sv2v_cast_32(m_state[37-:32])};
					if (m_state[44] && m_state[5])
						case (m_state[4-:3])
							3'b000: w_state[31-:32] <= {{24 {m_load_data_q[(m_state[1-:2] * 8) + 7]}}, m_load_data_q[m_state[1-:2] * 8+:8]};
							3'b001: w_state[31-:32] <= {{16 {m_load_data_q[(m_state[1-:2] * 8) + 15]}}, m_load_data_q[m_state[1-:2] * 8+:16]};
							3'b010: w_state[31-:32] <= m_load_data_q;
							3'b100: w_state[31-:32] <= {24'd0, m_load_data_q[m_state[1-:2] * 8+:8]};
							3'b101: w_state[31-:32] <= {16'd0, m_load_data_q[m_state[1-:2] * 8+:16]};
							default:
								;
						endcase
				end
			wire [255:0] g_disasm;
			wire [255:0] d_disasm;
			wire [255:0] x_disasm;
			wire [255:0] m_disasm;
			wire [255:0] w_disasm;
			Disasm #(.PREFIX("G")) dis0(
				.insn(SystemResourceCheck.axil_mem_ro.RDATA),
				.disasm(g_disasm)
			);
			Disasm #(.PREFIX("D")) dis1(
				.insn(d_state[64-:32]),
				.disasm(d_disasm)
			);
			Disasm #(.PREFIX("X")) dis2(
				.insn(x_state[160-:32]),
				.disasm(x_disasm)
			);
			Disasm #(.PREFIX("M")) dis3(
				.insn(m_state[108-:32]),
				.disasm(m_disasm)
			);
			Disasm #(.PREFIX("W")) dis4(
				.insn(w_state[102-:32]),
				.disasm(w_disasm)
			);
			assign halt = w_state[38] && (w_state[102-:32] == 32'h00000073);
			assign trace_completed_pc = (w_state[38] ? w_state[134-:32] : 32'd0);
			assign trace_completed_insn = (w_state[38] ? w_state[102-:32] : 32'd0);
			assign trace_completed_cycle_status = w_state[70-:32];
			initial _sv2v_0 = 0;
		end
	endgenerate
	assign datapath.clk = clk;
	assign datapath.rst = rst;
	assign led[0] = datapath.halt;
	assign trace_completed_pc = datapath.trace_completed_pc;
	assign trace_completed_insn = datapath.trace_completed_insn;
	assign trace_completed_cycle_status = datapath.trace_completed_cycle_status;
endmodule