module MyClockGen (
	input_clk_25MHz,
	clk_proc,
	locked
);
	input input_clk_25MHz;
	output wire clk_proc;
	output wire locked;
	wire clkfb;
	(* FREQUENCY_PIN_CLKI = "25" *) (* FREQUENCY_PIN_CLKOP = "10" *) (* ICP_CURRENT = "12" *) (* LPF_RESISTOR = "8" *) (* MFG_ENABLE_FILTEROPAMP = "1" *) (* MFG_GMCREF_SEL = "2" *) EHXPLLL #(
		.PLLRST_ENA("DISABLED"),
		.INTFB_WAKE("DISABLED"),
		.STDBY_ENABLE("DISABLED"),
		.DPHASE_SOURCE("DISABLED"),
		.OUTDIVIDER_MUXA("DIVA"),
		.OUTDIVIDER_MUXB("DIVB"),
		.OUTDIVIDER_MUXC("DIVC"),
		.OUTDIVIDER_MUXD("DIVD"),
		.CLKI_DIV(5),
		.CLKOP_ENABLE("ENABLED"),
		.CLKOP_DIV(60),
		.CLKOP_CPHASE(30),
		.CLKOP_FPHASE(0),
		.FEEDBK_PATH("INT_OP"),
		.CLKFB_DIV(2)
	) pll_i(
		.RST(1'b0),
		.STDBY(1'b0),
		.CLKI(input_clk_25MHz),
		.CLKOP(clk_proc),
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
module Disasm (
	insn,
	disasm
);
	parameter signed [7:0] PREFIX = "D";
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
		rs1_data = (rs1 == 5'd0 ? 32'd0 : regs[rs1]);
		rs2_data = (rs2 == 5'd0 ? 32'd0 : regs[rs2]);
	end
	always @(posedge clk)
		if (rst)
			for (i = 0; i < NumRegs; i = i + 1)
				regs[i] <= 32'd0;
		else begin
			if (we && (rd != 5'd0))
				regs[rd] <= rd_data;
			regs[5'd0] <= 32'd0;
		end
	initial _sv2v_0 = 0;
endmodule
module DatapathPipelined (
	clk,
	rst,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem,
	halt,
	trace_completed_pc,
	trace_completed_insn,
	trace_completed_cycle_status
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	output wire [31:0] pc_to_imem;
	input wire [31:0] insn_from_imem;
	output wire [31:0] addr_to_dmem;
	input wire [31:0] load_data_from_dmem;
	output wire [31:0] store_data_to_dmem;
	output wire [3:0] store_we_to_dmem;
	output wire halt;
	output wire [31:0] trace_completed_pc;
	output wire [31:0] trace_completed_insn;
	output wire [31:0] trace_completed_cycle_status;
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
	wire [31:0] f_insn;
	reg [31:0] f_cycle_status;
	reg x_branch_taken;
	reg [31:0] f_pc_branch_decision;
	wire pipeline_stall;
	wire load_use_stall;
	always @(posedge clk)
		if (rst) begin
			f_pc_current <= 32'd0;
			f_cycle_status <= 32'd1;
		end
		else if (x_branch_taken) begin
			f_cycle_status <= 32'd1;
			f_pc_current <= f_pc_branch_decision;
		end
		else if (pipeline_stall) begin
			f_cycle_status <= 32'd1;
			f_pc_current <= f_pc_current;
		end
		else begin
			f_cycle_status <= 32'd1;
			f_pc_current <= f_pc_current + 4;
		end
	assign pc_to_imem = f_pc_current;
	assign f_insn = insn_from_imem;
	wire [255:0] f_disasm;
	Disasm #(.PREFIX("F")) disasm_0fetch(
		.insn(f_insn),
		.disasm(f_disasm)
	);
	reg [95:0] decode_state;
	always @(posedge clk)
		if (rst)
			decode_state <= 96'h000000000000000000000004;
		else if (x_branch_taken)
			decode_state <= 96'h000000000000000000000008;
		else if (pipeline_stall)
			decode_state <= decode_state;
		else
			decode_state <= {f_pc_current, f_insn, f_cycle_status};
	wire [255:0] d_disasm;
	Disasm #(.PREFIX("D")) disasm_1decode(
		.insn(decode_state[63-:32]),
		.disasm(d_disasm)
	);
	wire [6:0] d_insn_funct7 = decode_state[63:57];
	wire [4:0] d_insn_rs2 = decode_state[56:52];
	wire [4:0] d_insn_rs1 = decode_state[51:47];
	wire [2:0] d_insn_funct3 = decode_state[46:44];
	wire [4:0] d_insn_rd = decode_state[43:39];
	wire [6:0] d_insn_opcode = decode_state[38:32];
	wire [31:0] d_rs1_data_raw;
	wire [31:0] d_rs2_data_raw;
	reg [31:0] d_rs1_data;
	reg [31:0] d_rs2_data;
	reg [191:0] execute_state;
	reg [177:0] memory_state;
	reg [133:0] writeback_state;
	RegFile rf(
		.clk(clk),
		.rst(rst),
		.we(writeback_state[37]),
		.rd(writeback_state[36-:5]),
		.rd_data(writeback_state[31-:32]),
		.rs1(d_insn_rs1),
		.rs2(d_insn_rs2),
		.rs1_data(d_rs1_data_raw),
		.rs2_data(d_rs2_data_raw)
	);
	reg x_we;
	localparam signed [31:0] DVS = 16;
	reg [4:0] div_pipe_rd [0:15];
	reg div_pipe_valid [0:15];
	reg [31:0] div_pipe_rs1 [0:15];
	reg [31:0] div_pipe_rs2 [0:15];
	reg div_pipe_is_div [0:15];
	reg div_pipe_is_divu [0:15];
	reg div_pipe_is_rem [0:15];
	reg div_pipe_is_remu [0:15];
	reg [31:0] div_pipe_pc [0:15];
	reg [31:0] div_pipe_insn [0:15];
	reg [31:0] div_pipe_cstat [0:15];
	wire d_reads_rs1_h = (((d_insn_opcode == OpcodeLui) || (d_insn_opcode == OpcodeAuipc)) || (d_insn_opcode == OpcodeJal) ? 1'b0 : 1'b1);
	wire d_reads_rs2_h = (d_insn_opcode == OpcodeRegReg) || (d_insn_opcode == OpcodeBranch);
	wire d_decode_is_div_h = (((decode_state[63-:32] != 32'd0) && (decode_state[38:32] == OpcodeRegReg)) && (decode_state[63:57] == 7'd1)) && ((((decode_state[46:44] == 3'b100) || (decode_state[46:44] == 3'b101)) || (decode_state[46:44] == 3'b110)) || (decode_state[46:44] == 3'b111));
	wire x_is_load_h = (execute_state[159-:32] != 32'd0) && (execute_state[70-:7] == OpcodeLoad);
	assign load_use_stall = (x_is_load_h && (execute_state[75-:5] != 5'd0)) && ((d_reads_rs1_h && (d_insn_rs1 == execute_state[75-:5])) || (d_reads_rs2_h && (d_insn_rs2 == execute_state[75-:5])));
	reg div_stall_raw;
	reg div_any_inflight;
	reg div_nondiv_stall;
	always @(*) begin
		if (_sv2v_0)
			;
		div_stall_raw = 1'b0;
		div_any_inflight = 1'b0;
		begin : sv2v_autoblock_1
			reg signed [31:0] hk;
			for (hk = 0; hk < DVS; hk = hk + 1)
				if (div_pipe_valid[hk])
					div_any_inflight = 1'b1;
		end
		if (d_reads_rs1_h && (d_insn_rs1 != 5'd0)) begin
			if (d_decode_is_div_h) begin : sv2v_autoblock_2
				reg signed [31:0] hi;
				for (hi = 0; hi < DVS; hi = hi + 1)
					if (div_pipe_valid[hi] && (div_pipe_rd[hi] == d_insn_rs1))
						div_stall_raw = 1'b1;
			end
			else begin : sv2v_autoblock_3
				reg signed [31:0] hi;
				for (hi = 0; hi < 15; hi = hi + 1)
					if (div_pipe_valid[hi] && (div_pipe_rd[hi] == d_insn_rs1))
						div_stall_raw = 1'b1;
			end
		end
		if (d_reads_rs2_h && (d_insn_rs2 != 5'd0)) begin
			if (d_decode_is_div_h) begin : sv2v_autoblock_4
				reg signed [31:0] hj;
				for (hj = 0; hj < DVS; hj = hj + 1)
					if (div_pipe_valid[hj] && (div_pipe_rd[hj] == d_insn_rs2))
						div_stall_raw = 1'b1;
			end
			else begin : sv2v_autoblock_5
				reg signed [31:0] hj;
				for (hj = 0; hj < 15; hj = hj + 1)
					if (div_pipe_valid[hj] && (div_pipe_rd[hj] == d_insn_rs2))
						div_stall_raw = 1'b1;
			end
		end
		div_nondiv_stall = ((div_any_inflight && !div_pipe_valid[15]) && (decode_state[63-:32] != 32'd0)) && !d_decode_is_div_h;
	end
	wire x_is_div_h = (((execute_state[159-:32] != 32'd0) && (execute_state[70-:7] == OpcodeRegReg)) && (execute_state[159:153] == 7'd1)) && ((((execute_state[142:140] == 3'b100) || (execute_state[142:140] == 3'b101)) || (execute_state[142:140] == 3'b110)) || (execute_state[142:140] == 3'b111));
	wire div_out_valid = div_pipe_valid[15];
	wire div_mem_conflict = (div_out_valid && (execute_state[159-:32] != 32'd0)) && !x_is_div_h;
	wire div_stall = 1'b0;
	assign pipeline_stall = ((load_use_stall || div_stall_raw) || div_nondiv_stall) || div_mem_conflict;
	reg [31:0] ex_bubble_status;
	always @(*) begin
		if (_sv2v_0)
			;
		if (load_use_stall && (div_stall_raw || div_nondiv_stall))
			ex_bubble_status = 32'd16 | 32'd2;
		else if (load_use_stall)
			ex_bubble_status = 32'd16;
		else if (div_stall_raw || div_nondiv_stall)
			ex_bubble_status = 32'd2;
		else
			ex_bubble_status = 32'd1;
	end
	wire d_decode_is_div = d_decode_is_div_h;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(posedge clk)
		if (rst) begin
			execute_state <= 192'h000000000000000000000004000000000000000000000000;
			begin : sv2v_autoblock_6
				reg signed [31:0] di;
				for (di = 0; di < DVS; di = di + 1)
					begin
						div_pipe_rd[di] <= 5'd0;
						div_pipe_valid[di] <= 1'b0;
						div_pipe_rs1[di] <= 32'd0;
						div_pipe_rs2[di] <= 32'd0;
						div_pipe_is_div[di] <= 1'b0;
						div_pipe_is_divu[di] <= 1'b0;
						div_pipe_is_rem[di] <= 1'b0;
						div_pipe_is_remu[di] <= 1'b0;
						div_pipe_pc[di] <= 32'd0;
						div_pipe_insn[di] <= 32'd0;
						div_pipe_cstat[di] <= 32'd1;
					end
			end
		end
		else if (x_branch_taken) begin
			execute_state <= 192'h000000000000000000000008000000000000000000000000;
			begin : sv2v_autoblock_7
				reg signed [31:0] di;
				for (di = 0; di < DVS; di = di + 1)
					begin
						div_pipe_rd[di] <= 5'd0;
						div_pipe_valid[di] <= 1'b0;
						div_pipe_rs1[di] <= 32'd0;
						div_pipe_rs2[di] <= 32'd0;
						div_pipe_is_div[di] <= 1'b0;
						div_pipe_is_divu[di] <= 1'b0;
						div_pipe_is_rem[di] <= 1'b0;
						div_pipe_is_remu[di] <= 1'b0;
						div_pipe_pc[di] <= 32'd0;
						div_pipe_insn[di] <= 32'd0;
						div_pipe_cstat[di] <= 32'd1;
					end
			end
		end
		else if ((load_use_stall || div_stall_raw) || div_nondiv_stall) begin
			execute_state <= {64'h0000000000000000, ex_bubble_status, 96'h000000000000000000000000};
			begin : sv2v_autoblock_8
				reg signed [31:0] di;
				for (di = 15; di > 0; di = di - 1)
					begin
						div_pipe_rd[di] <= div_pipe_rd[di - 1];
						div_pipe_valid[di] <= div_pipe_valid[di - 1];
						div_pipe_rs1[di] <= div_pipe_rs1[di - 1];
						div_pipe_rs2[di] <= div_pipe_rs2[di - 1];
						div_pipe_is_div[di] <= div_pipe_is_div[di - 1];
						div_pipe_is_divu[di] <= div_pipe_is_divu[di - 1];
						div_pipe_is_rem[di] <= div_pipe_is_rem[di - 1];
						div_pipe_is_remu[di] <= div_pipe_is_remu[di - 1];
						div_pipe_pc[di] <= div_pipe_pc[di - 1];
						div_pipe_insn[di] <= div_pipe_insn[di - 1];
						div_pipe_cstat[di] <= div_pipe_cstat[di - 1];
					end
			end
			div_pipe_rd[0] <= 5'd0;
			div_pipe_valid[0] <= 1'b0;
			div_pipe_rs1[0] <= 32'd0;
			div_pipe_rs2[0] <= 32'd0;
			div_pipe_is_div[0] <= 1'b0;
			div_pipe_is_divu[0] <= 1'b0;
			div_pipe_is_rem[0] <= 1'b0;
			div_pipe_is_remu[0] <= 1'b0;
			div_pipe_pc[0] <= 32'd0;
			div_pipe_insn[0] <= 32'd0;
			div_pipe_cstat[0] <= 32'd1;
		end
		else if (div_mem_conflict) begin
			execute_state <= execute_state;
			begin : sv2v_autoblock_9
				reg signed [31:0] di;
				for (di = 15; di > 0; di = di - 1)
					begin
						div_pipe_rd[di] <= div_pipe_rd[di - 1];
						div_pipe_valid[di] <= div_pipe_valid[di - 1];
						div_pipe_rs1[di] <= div_pipe_rs1[di - 1];
						div_pipe_rs2[di] <= div_pipe_rs2[di - 1];
						div_pipe_is_div[di] <= div_pipe_is_div[di - 1];
						div_pipe_is_divu[di] <= div_pipe_is_divu[di - 1];
						div_pipe_is_rem[di] <= div_pipe_is_rem[di - 1];
						div_pipe_is_remu[di] <= div_pipe_is_remu[di - 1];
						div_pipe_pc[di] <= div_pipe_pc[di - 1];
						div_pipe_insn[di] <= div_pipe_insn[di - 1];
						div_pipe_cstat[di] <= div_pipe_cstat[di - 1];
					end
			end
			div_pipe_rd[0] <= 5'd0;
			div_pipe_valid[0] <= 1'b0;
			div_pipe_rs1[0] <= 32'd0;
			div_pipe_rs2[0] <= 32'd0;
			div_pipe_is_div[0] <= 1'b0;
			div_pipe_is_divu[0] <= 1'b0;
			div_pipe_is_rem[0] <= 1'b0;
			div_pipe_is_remu[0] <= 1'b0;
			div_pipe_pc[0] <= 32'd0;
			div_pipe_insn[0] <= 32'd0;
			div_pipe_cstat[0] <= 32'd1;
		end
		else begin
			execute_state <= {sv2v_cast_32(decode_state[95-:32]), sv2v_cast_32(decode_state[63-:32]), sv2v_cast_32(decode_state[31-:32]), d_insn_funct7, d_insn_rs2, d_insn_rs1, d_insn_funct3, d_insn_rd, d_insn_opcode, d_rs1_data, d_rs2_data};
			begin : sv2v_autoblock_10
				reg signed [31:0] di;
				for (di = 15; di > 0; di = di - 1)
					begin
						div_pipe_rd[di] <= div_pipe_rd[di - 1];
						div_pipe_valid[di] <= div_pipe_valid[di - 1];
						div_pipe_rs1[di] <= div_pipe_rs1[di - 1];
						div_pipe_rs2[di] <= div_pipe_rs2[di - 1];
						div_pipe_is_div[di] <= div_pipe_is_div[di - 1];
						div_pipe_is_divu[di] <= div_pipe_is_divu[di - 1];
						div_pipe_is_rem[di] <= div_pipe_is_rem[di - 1];
						div_pipe_is_remu[di] <= div_pipe_is_remu[di - 1];
						div_pipe_pc[di] <= div_pipe_pc[di - 1];
						div_pipe_insn[di] <= div_pipe_insn[di - 1];
						div_pipe_cstat[di] <= div_pipe_cstat[di - 1];
					end
			end
			if (d_decode_is_div) begin
				div_pipe_valid[0] <= 1'b1;
				div_pipe_rd[0] <= d_insn_rd;
				div_pipe_rs1[0] <= d_rs1_data;
				div_pipe_rs2[0] <= d_rs2_data;
				div_pipe_pc[0] <= decode_state[95-:32];
				div_pipe_insn[0] <= decode_state[63-:32];
				div_pipe_cstat[0] <= decode_state[31-:32];
				div_pipe_is_div[0] <= decode_state[46:44] == 3'b100;
				div_pipe_is_divu[0] <= decode_state[46:44] == 3'b101;
				div_pipe_is_rem[0] <= decode_state[46:44] == 3'b110;
				div_pipe_is_remu[0] <= decode_state[46:44] == 3'b111;
			end
			else begin
				div_pipe_valid[0] <= 1'b0;
				div_pipe_rd[0] <= 5'd0;
				div_pipe_rs1[0] <= 32'd0;
				div_pipe_rs2[0] <= 32'd0;
				div_pipe_pc[0] <= 32'd0;
				div_pipe_insn[0] <= 32'd0;
				div_pipe_cstat[0] <= 32'd1;
				div_pipe_is_div[0] <= 1'b0;
				div_pipe_is_divu[0] <= 1'b0;
				div_pipe_is_rem[0] <= 1'b0;
				div_pipe_is_remu[0] <= 1'b0;
			end
		end
	wire [255:0] x_disasm;
	Disasm #(.PREFIX("X")) disasm_1execute(
		.insn(execute_state[159-:32]),
		.disasm(x_disasm)
	);
	wire [31:0] x_imm_u = {execute_state[159:140], 12'b000000000000};
	wire [11:0] x_imm_s;
	assign x_imm_s[11:5] = execute_state[95-:7];
	assign x_imm_s[4:0] = execute_state[75-:5];
	wire [11:0] x_imm_i;
	assign x_imm_i = execute_state[159:148];
	wire [4:0] x_imm_shamt = execute_state[152:148];
	reg [31:0] x_cla_a;
	reg [31:0] x_cla_b;
	reg x_cla_cin;
	wire [31:0] x_cla_sum;
	wire [12:0] x_imm_b;
	assign {x_imm_b[12], x_imm_b[10:5]} = execute_state[95-:7];
	assign {x_imm_b[4:1], x_imm_b[11]} = execute_state[75-:5];
	assign x_imm_b[0] = 1'b0;
	wire [20:0] x_imm_j;
	assign {x_imm_j[20], x_imm_j[10:1], x_imm_j[11], x_imm_j[19:12], x_imm_j[0]} = {execute_state[159:140], 1'b0};
	wire [31:0] x_imm_i_sext = {{20 {x_imm_i[11]}}, x_imm_i[11:0]};
	wire [31:0] x_imm_s_sext = {{20 {x_imm_s[11]}}, x_imm_s[11:0]};
	wire [31:0] x_imm_b_sext = {{19 {x_imm_b[12]}}, x_imm_b[12:0]};
	wire [31:0] x_imm_j_sext = {{11 {x_imm_j[20]}}, x_imm_j[20:0]};
	CarryLookaheadAdder cla32(
		.a(x_cla_a),
		.b(x_cla_b),
		.cin(x_cla_cin),
		.sum(x_cla_sum)
	);
	reg x_illegal_insn;
	reg [4:0] x_rd;
	reg [4:0] x_rs1;
	reg [4:0] x_rs2;
	reg [31:0] x_wdata;
	reg [31:0] x_rs1_data;
	reg [31:0] x_rs2_data;
	always @(*) begin
		if (_sv2v_0)
			;
		x_rs1_data = execute_state[63-:32];
		x_rs2_data = execute_state[31-:32];
		if ((memory_state[81] && (memory_state[80-:5] != 5'd0)) && (memory_state[80-:5] == execute_state[83-:5]))
			x_rs1_data = memory_state[75-:32];
		else if ((writeback_state[37] && (writeback_state[36-:5] != 5'd0)) && (writeback_state[36-:5] == execute_state[83-:5]))
			x_rs1_data = writeback_state[31-:32];
		if ((memory_state[81] && (memory_state[80-:5] != 5'd0)) && (memory_state[80-:5] == execute_state[88-:5]))
			x_rs2_data = memory_state[75-:32];
		else if ((writeback_state[37] && (writeback_state[36-:5] != 5'd0)) && (writeback_state[36-:5] == execute_state[88-:5]))
			x_rs2_data = writeback_state[31-:32];
	end
	wire [31:0] x_ls_addr = x_rs1_data + x_imm_i_sext;
	wire [31:0] x_ls_addr_s = x_rs1_data + x_imm_s_sext;
	wire insn_lui = execute_state[70-:7] == OpcodeLui;
	wire insn_auipc = execute_state[70-:7] == OpcodeAuipc;
	wire insn_jal = execute_state[70-:7] == OpcodeJal;
	wire insn_jalr = execute_state[70-:7] == OpcodeJalr;
	wire insn_beq = (execute_state[70-:7] == OpcodeBranch) && (execute_state[142:140] == 3'b000);
	wire insn_bne = (execute_state[70-:7] == OpcodeBranch) && (execute_state[142:140] == 3'b001);
	wire insn_blt = (execute_state[70-:7] == OpcodeBranch) && (execute_state[142:140] == 3'b100);
	wire insn_bge = (execute_state[70-:7] == OpcodeBranch) && (execute_state[142:140] == 3'b101);
	wire insn_bltu = (execute_state[70-:7] == OpcodeBranch) && (execute_state[142:140] == 3'b110);
	wire insn_bgeu = (execute_state[70-:7] == OpcodeBranch) && (execute_state[142:140] == 3'b111);
	wire insn_lb = (execute_state[70-:7] == OpcodeLoad) && (execute_state[142:140] == 3'b000);
	wire insn_lh = (execute_state[70-:7] == OpcodeLoad) && (execute_state[142:140] == 3'b001);
	wire insn_lw = (execute_state[70-:7] == OpcodeLoad) && (execute_state[142:140] == 3'b010);
	wire insn_lbu = (execute_state[70-:7] == OpcodeLoad) && (execute_state[142:140] == 3'b100);
	wire insn_lhu = (execute_state[70-:7] == OpcodeLoad) && (execute_state[142:140] == 3'b101);
	wire insn_sb = (execute_state[70-:7] == OpcodeStore) && (execute_state[142:140] == 3'b000);
	wire insn_sh = (execute_state[70-:7] == OpcodeStore) && (execute_state[142:140] == 3'b001);
	wire insn_sw = (execute_state[70-:7] == OpcodeStore) && (execute_state[142:140] == 3'b010);
	wire insn_addi = (execute_state[70-:7] == OpcodeRegImm) && (execute_state[142:140] == 3'b000);
	wire insn_slti = (execute_state[70-:7] == OpcodeRegImm) && (execute_state[142:140] == 3'b010);
	wire insn_sltiu = (execute_state[70-:7] == OpcodeRegImm) && (execute_state[142:140] == 3'b011);
	wire insn_xori = (execute_state[70-:7] == OpcodeRegImm) && (execute_state[142:140] == 3'b100);
	wire insn_ori = (execute_state[70-:7] == OpcodeRegImm) && (execute_state[142:140] == 3'b110);
	wire insn_andi = (execute_state[70-:7] == OpcodeRegImm) && (execute_state[142:140] == 3'b111);
	wire insn_slli = ((execute_state[70-:7] == OpcodeRegImm) && (execute_state[142:140] == 3'b001)) && (execute_state[159:153] == 7'd0);
	wire insn_srli = ((execute_state[70-:7] == OpcodeRegImm) && (execute_state[142:140] == 3'b101)) && (execute_state[159:153] == 7'd0);
	wire insn_srai = ((execute_state[70-:7] == OpcodeRegImm) && (execute_state[142:140] == 3'b101)) && (execute_state[159:153] == 7'b0100000);
	wire insn_add = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b000)) && (execute_state[159:153] == 7'd0);
	wire insn_sub = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b000)) && (execute_state[159:153] == 7'b0100000);
	wire insn_sll = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b001)) && (execute_state[159:153] == 7'd0);
	wire insn_slt = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b010)) && (execute_state[159:153] == 7'd0);
	wire insn_sltu = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b011)) && (execute_state[159:153] == 7'd0);
	wire insn_xor = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b100)) && (execute_state[159:153] == 7'd0);
	wire insn_srl = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b101)) && (execute_state[159:153] == 7'd0);
	wire insn_sra = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b101)) && (execute_state[159:153] == 7'b0100000);
	wire insn_or = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b110)) && (execute_state[159:153] == 7'd0);
	wire insn_and = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[142:140] == 3'b111)) && (execute_state[159:153] == 7'd0);
	wire insn_mul = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[159:153] == 7'd1)) && (execute_state[142:140] == 3'b000);
	wire insn_mulh = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[159:153] == 7'd1)) && (execute_state[142:140] == 3'b001);
	wire insn_mulhsu = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[159:153] == 7'd1)) && (execute_state[142:140] == 3'b010);
	wire insn_mulhu = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[159:153] == 7'd1)) && (execute_state[142:140] == 3'b011);
	wire insn_div = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[159:153] == 7'd1)) && (execute_state[142:140] == 3'b100);
	wire insn_divu = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[159:153] == 7'd1)) && (execute_state[142:140] == 3'b101);
	wire insn_rem = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[159:153] == 7'd1)) && (execute_state[142:140] == 3'b110);
	wire insn_remu = ((execute_state[70-:7] == OpcodeRegReg) && (execute_state[159:153] == 7'd1)) && (execute_state[142:140] == 3'b111);
	wire insn_ecall = (execute_state[70-:7] == OpcodeEnviron) && (execute_state[159:135] == 25'd0);
	wire insn_fence = execute_state[70-:7] == OpcodeMiscMem;
	function automatic signed [63:0] sv2v_cast_64_signed;
		input reg signed [63:0] inp;
		sv2v_cast_64_signed = inp;
	endfunction
	wire signed [63:0] x_mulh_full = sv2v_cast_64_signed($signed(x_rs1_data)) * sv2v_cast_64_signed($signed(x_rs2_data));
	wire [63:0] x_mulhsu_full = $signed({{32 {x_rs1_data[31]}}, x_rs1_data}) * $signed({32'b00000000000000000000000000000000, x_rs2_data});
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	wire [63:0] x_mulhu_wide = sv2v_cast_64(x_rs1_data) * sv2v_cast_64(x_rs2_data);
	always @(*) begin
		if (_sv2v_0)
			;
		x_illegal_insn = 1'b0;
		x_branch_taken = 1'b0;
		x_rs1 = execute_state[83-:5];
		x_rs2 = execute_state[88-:5];
		x_rd = execute_state[75-:5];
		x_we = 1'b0;
		x_wdata = 32'd0;
		x_cla_a = 32'd0;
		x_cla_b = 32'd0;
		x_cla_cin = 1'b0;
		f_pc_branch_decision = execute_state[191-:32] + 32'd4;
		case (execute_state[70-:7])
			OpcodeLui: begin
				x_we = 1'b1;
				x_wdata = x_imm_u;
			end
			OpcodeAuipc: begin
				x_we = 1'b1;
				x_wdata = execute_state[191-:32] + x_imm_u;
			end
			OpcodeRegImm: begin
				x_we = 1'b1;
				if (insn_addi) begin
					x_cla_a = x_rs1_data;
					x_cla_b = x_imm_i_sext;
					x_cla_cin = 1'b0;
					x_wdata = x_cla_sum;
				end
				else if (insn_slti)
					x_wdata = ($signed(x_rs1_data) < $signed(x_imm_i_sext) ? 32'd1 : 32'd0);
				else if (insn_sltiu)
					x_wdata = (x_rs1_data < x_imm_i_sext ? 32'd1 : 32'd0);
				else if (insn_xori)
					x_wdata = x_rs1_data ^ x_imm_i_sext;
				else if (insn_ori)
					x_wdata = x_rs1_data | x_imm_i_sext;
				else if (insn_andi)
					x_wdata = x_rs1_data & x_imm_i_sext;
				else if (insn_slli)
					x_wdata = x_rs1_data << x_imm_shamt;
				else if (insn_srli)
					x_wdata = x_rs1_data >> x_imm_shamt;
				else if (insn_srai)
					x_wdata = $signed(x_rs1_data) >>> x_imm_shamt;
				else
					x_illegal_insn = 1'b1;
			end
			OpcodeRegReg: begin
				x_we = 1'b1;
				if (insn_add) begin
					x_cla_a = x_rs1_data;
					x_cla_b = x_rs2_data;
					x_cla_cin = 1'b0;
					x_wdata = x_cla_sum;
				end
				else if (insn_sub) begin
					x_cla_a = x_rs1_data;
					x_cla_b = ~x_rs2_data;
					x_cla_cin = 1'b1;
					x_wdata = x_cla_sum;
				end
				else if (insn_sll)
					x_wdata = x_rs1_data << x_rs2_data[4:0];
				else if (insn_slt)
					x_wdata = ($signed(x_rs1_data) < $signed(x_rs2_data) ? 32'd1 : 32'd0);
				else if (insn_sltu)
					x_wdata = (x_rs1_data < x_rs2_data ? 32'd1 : 32'd0);
				else if (insn_xor)
					x_wdata = x_rs1_data ^ x_rs2_data;
				else if (insn_srl)
					x_wdata = x_rs1_data >> x_rs2_data[4:0];
				else if (insn_sra)
					x_wdata = $signed(x_rs1_data) >>> x_rs2_data[4:0];
				else if (insn_or)
					x_wdata = x_rs1_data | x_rs2_data;
				else if (insn_and)
					x_wdata = x_rs1_data & x_rs2_data;
				else if (insn_mul)
					x_wdata = x_rs1_data * x_rs2_data;
				else if (insn_mulh)
					x_wdata = x_mulh_full[63:32];
				else if (insn_mulhsu)
					x_wdata = x_mulhsu_full[63:32];
				else if (insn_mulhu)
					x_wdata = x_mulhu_wide[63:32];
				else if (((insn_div || insn_divu) || insn_rem) || insn_remu)
					x_we = 1'b0;
				else
					x_illegal_insn = 1'b1;
			end
			OpcodeLoad: begin
				x_we = 1'b1;
				x_wdata = {x_ls_addr[31:2], 2'b00};
			end
			OpcodeStore: begin
				x_we = 1'b0;
				x_wdata = {x_ls_addr_s[31:2], 2'b00};
			end
			OpcodeJal: begin
				x_we = 1'b1;
				x_wdata = execute_state[191-:32] + 32'd4;
				x_branch_taken = 1'b1;
				f_pc_branch_decision = execute_state[191-:32] + x_imm_j_sext;
			end
			OpcodeJalr: begin
				x_we = 1'b1;
				x_wdata = execute_state[191-:32] + 32'd4;
				x_branch_taken = 1'b1;
				f_pc_branch_decision = (x_rs1_data + x_imm_i_sext) & ~32'b00000000000000000000000000000001;
			end
			OpcodeBranch: begin
				if (insn_beq)
					x_branch_taken = x_rs1_data == x_rs2_data;
				else if (insn_bne)
					x_branch_taken = x_rs1_data != x_rs2_data;
				else if (insn_blt)
					x_branch_taken = $signed(x_rs1_data) < $signed(x_rs2_data);
				else if (insn_bge)
					x_branch_taken = $signed(x_rs1_data) >= $signed(x_rs2_data);
				else if (insn_bltu)
					x_branch_taken = x_rs1_data < x_rs2_data;
				else if (insn_bgeu)
					x_branch_taken = x_rs1_data >= x_rs2_data;
				else
					x_illegal_insn = 1'b1;
				if (!x_illegal_insn) begin
					if (x_branch_taken)
						f_pc_branch_decision = execute_state[191-:32] + x_imm_b_sext;
				end
			end
			OpcodeEnviron:
				;
			default: x_illegal_insn = 1'b1;
		endcase
	end
	wire d_fwd_mem_ok = (memory_state[81] && (memory_state[80-:5] != 5'd0)) && !memory_state[43];
	wire d_fwd_ex_ok = ((execute_state[159-:32] != 32'd0) && x_we) && (execute_state[70-:7] != OpcodeLoad);
	always @(*) begin
		if (_sv2v_0)
			;
		d_rs1_data = d_rs1_data_raw;
		d_rs2_data = d_rs2_data_raw;
		if (d_insn_rs1 != 5'd0) begin
			if (d_fwd_ex_ok && (execute_state[75-:5] == d_insn_rs1))
				d_rs1_data = x_wdata;
			else if (d_fwd_mem_ok && (memory_state[80-:5] == d_insn_rs1))
				d_rs1_data = memory_state[75-:32];
			else if ((writeback_state[37] && (writeback_state[36-:5] != 5'd0)) && (writeback_state[36-:5] == d_insn_rs1))
				d_rs1_data = writeback_state[31-:32];
		end
		if (d_insn_rs2 != 5'd0) begin
			if (d_fwd_ex_ok && (execute_state[75-:5] == d_insn_rs2))
				d_rs2_data = x_wdata;
			else if (d_fwd_mem_ok && (memory_state[80-:5] == d_insn_rs2))
				d_rs2_data = memory_state[75-:32];
			else if ((writeback_state[37] && (writeback_state[36-:5] != 5'd0)) && (writeback_state[36-:5] == d_insn_rs2))
				d_rs2_data = writeback_state[31-:32];
		end
	end
	wire [31:0] d_div_rs1_abs = (d_rs1_data[31] ? ~d_rs1_data + 32'd1 : d_rs1_data);
	wire [31:0] d_div_rs2_abs = (d_rs2_data[31] ? ~d_rs2_data + 32'd1 : d_rs2_data);
	wire div_issue_this_cycle = ((d_decode_is_div && !pipeline_stall) && !x_branch_taken) && !rst;
	reg [31:0] div_i_dividend;
	reg [31:0] div_i_divisor;
	always @(*) begin
		if (_sv2v_0)
			;
		div_i_dividend = 32'd0;
		div_i_divisor = 32'd1;
		if (div_issue_this_cycle) begin
			if ((decode_state[46:44] == 3'b100) || (decode_state[46:44] == 3'b110)) begin
				div_i_dividend = d_div_rs1_abs;
				div_i_divisor = d_div_rs2_abs;
			end
			else begin
				div_i_dividend = d_rs1_data;
				div_i_divisor = d_rs2_data;
			end
		end
	end
	wire [31:0] div_o_quotient;
	wire [31:0] div_o_remainder;
	DividerUnsignedPipelined divider(
		.clk(clk),
		.rst(rst),
		.stall(div_stall),
		.i_dividend(div_i_dividend),
		.i_divisor(div_i_divisor),
		.o_quotient(div_o_quotient),
		.o_remainder(div_o_remainder)
	);
	reg [31:0] div_o_quotient_r;
	reg [31:0] div_o_remainder_r;
	always @(posedge clk)
		if (rst) begin
			div_o_quotient_r <= 32'd0;
			div_o_remainder_r <= 32'd0;
		end
		else if (!div_stall) begin
			div_o_quotient_r <= div_o_quotient;
			div_o_remainder_r <= div_o_remainder;
		end
	reg [31:0] div_m_wdata;
	always @(*) begin
		if (_sv2v_0)
			;
		div_m_wdata = 32'd0;
		if (div_pipe_valid[15]) begin
			if (div_pipe_is_div[15]) begin
				if (div_pipe_rs2[15] == 32'd0)
					div_m_wdata = 32'hffffffff;
				else if ((div_pipe_rs1[15] == 32'h80000000) && (div_pipe_rs2[15] == 32'hffffffff))
					div_m_wdata = 32'h80000000;
				else if (div_pipe_rs1[15][31] ^ div_pipe_rs2[15][31])
					div_m_wdata = ~div_o_quotient_r + 32'd1;
				else
					div_m_wdata = div_o_quotient_r;
			end
			else if (div_pipe_is_divu[15]) begin
				if (div_pipe_rs2[15] == 32'd0)
					div_m_wdata = 32'hffffffff;
				else
					div_m_wdata = div_o_quotient_r;
			end
			else if (div_pipe_is_rem[15]) begin
				if (div_pipe_rs2[15] == 32'd0)
					div_m_wdata = div_pipe_rs1[15];
				else if ((div_pipe_rs1[15] == 32'h80000000) && (div_pipe_rs2[15] == 32'hffffffff))
					div_m_wdata = 32'd0;
				else if (div_pipe_rs1[15][31])
					div_m_wdata = ~div_o_remainder_r + 32'd1;
				else
					div_m_wdata = div_o_remainder_r;
			end
			else if (div_pipe_rs2[15] == 32'd0)
				div_m_wdata = div_pipe_rs1[15];
			else
				div_m_wdata = div_o_remainder_r;
		end
	end
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	always @(posedge clk)
		if (rst)
			memory_state <= 178'h000000000000000000000001000000000000000000000;
		else if (div_pipe_valid[15])
			memory_state <= {div_pipe_pc[15], div_pipe_insn[15], div_pipe_cstat[15], div_pipe_rd[15] != 5'd0, div_pipe_rd[15], div_m_wdata, 44'h00000000000};
		else if (x_is_div_h)
			memory_state <= 178'h000000000000000000000000800000000000000000000;
		else
			memory_state <= {sv2v_cast_32(execute_state[191-:32]), sv2v_cast_32(execute_state[159-:32]), sv2v_cast_32(execute_state[127-:32]), x_we, sv2v_cast_5(execute_state[75-:5]), x_wdata, execute_state[70-:7] == OpcodeLoad, execute_state[70-:7] == OpcodeStore, sv2v_cast_3(execute_state[78-:3]), x_rs2_data, sv2v_cast_5(execute_state[88-:5]), (execute_state[70-:7] == OpcodeLoad ? x_ls_addr[1:0] : x_ls_addr_s[1:0])};
	wire [255:0] m_disasm;
	Disasm #(.PREFIX("M")) disasm_1memory(
		.insn(memory_state[145-:32]),
		.disasm(m_disasm)
	);
	reg [31:0] wb_rd_data_mux;
	always @(*) begin
		if (_sv2v_0)
			;
		wb_rd_data_mux = memory_state[75-:32];
		if (memory_state[43])
			(* full_case, parallel_case *)
			case (memory_state[41-:3])
				3'b000: wb_rd_data_mux = {{24 {load_data_from_dmem[(memory_state[1-:2] * 8) + 7]}}, load_data_from_dmem[memory_state[1-:2] * 8+:8]};
				3'b001: wb_rd_data_mux = {{16 {load_data_from_dmem[(memory_state[1-:2] * 8) + 15]}}, load_data_from_dmem[memory_state[1-:2] * 8+:16]};
				3'b010: wb_rd_data_mux = load_data_from_dmem;
				3'b100: wb_rd_data_mux = {24'd0, load_data_from_dmem[memory_state[1-:2] * 8+:8]};
				3'b101: wb_rd_data_mux = {16'd0, load_data_from_dmem[memory_state[1-:2] * 8+:16]};
				default: wb_rd_data_mux = memory_state[75-:32];
			endcase
	end
	reg [31:0] m_wm_store_data;
	always @(*) begin
		if (_sv2v_0)
			;
		m_wm_store_data = memory_state[38-:32];
		if ((writeback_state[37] && (writeback_state[36-:5] != 5'd0)) && (writeback_state[36-:5] == memory_state[6-:5]))
			m_wm_store_data = writeback_state[31-:32];
	end
	always @(posedge clk)
		if (rst)
			writeback_state <= 134'h0000000000000000000000010000000000;
		else
			writeback_state <= {sv2v_cast_32(memory_state[177-:32]), sv2v_cast_32(memory_state[145-:32]), sv2v_cast_32(memory_state[113-:32]), memory_state[81], sv2v_cast_5(memory_state[80-:5]), wb_rd_data_mux};
	wire [255:0] w_disasm;
	Disasm #(.PREFIX("W")) disasm_1writeback(
		.insn(writeback_state[101-:32]),
		.disasm(w_disasm)
	);
	reg [31:0] store_data_next;
	reg [31:0] addr_to_dmem_next;
	reg [3:0] store_we_next;
	always @(*) begin
		if (_sv2v_0)
			;
		addr_to_dmem_next = 32'd0;
		store_we_next = 4'd0;
		store_data_next = 32'd0;
		if (memory_state[43])
			addr_to_dmem_next = memory_state[75-:32];
		else if (memory_state[42]) begin
			addr_to_dmem_next = memory_state[75-:32];
			(* full_case, parallel_case *)
			case (memory_state[41-:3])
				3'b000: begin
					store_we_next = 4'b0001 << memory_state[1-:2];
					store_data_next = {24'd0, m_wm_store_data[7:0]} << (memory_state[1-:2] * 8);
				end
				3'b001: begin
					store_we_next = 4'b0011 << memory_state[1-:2];
					store_data_next = {16'd0, m_wm_store_data[15:0]} << (memory_state[1-:2] * 8);
				end
				3'b010: begin
					store_we_next = 4'b1111;
					store_data_next = m_wm_store_data;
				end
				default: begin
					store_we_next = 4'd0;
					store_data_next = 32'd0;
				end
			endcase
		end
	end
	assign addr_to_dmem = addr_to_dmem_next;
	assign store_data_to_dmem = store_data_next;
	assign store_we_to_dmem = store_we_next;
	assign halt = writeback_state[101-:32] == 32'h00000073;
	assign trace_completed_pc = writeback_state[133-:32];
	assign trace_completed_insn = writeback_state[101-:32];
	assign trace_completed_cycle_status = writeback_state[69-:32];
	initial _sv2v_0 = 0;
endmodule
module MemorySingleCycle (
	rst,
	clk,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem
);
	reg _sv2v_0;
	parameter signed [31:0] NUM_WORDS = 512;
	input wire rst;
	input wire clk;
	input wire [31:0] pc_to_imem;
	output reg [31:0] insn_from_imem;
	input wire [31:0] addr_to_dmem;
	output reg [31:0] load_data_from_dmem;
	input wire [31:0] store_data_to_dmem;
	input wire [3:0] store_we_to_dmem;
	reg [31:0] mem_array [0:NUM_WORDS - 1];
	initial $readmemh("mem_initial_contents.hex", mem_array);
	always @(*)
		if (_sv2v_0)
			;
	localparam signed [31:0] AddrMsb = $clog2(NUM_WORDS) + 1;
	localparam signed [31:0] AddrLsb = 2;
	always @(negedge clk)
		if (rst)
			;
		else
			insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
	always @(negedge clk)
		if (rst)
			;
		else begin
			if (store_we_to_dmem[0])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
			if (store_we_to_dmem[1])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
			if (store_we_to_dmem[2])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
			if (store_we_to_dmem[3])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
			load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype none
module txuartlite (
	i_clk,
	i_reset,
	i_wr,
	i_data,
	o_uart_tx,
	o_busy
);
	parameter [4:0] TIMING_BITS = 5'd24;
	localparam TB = TIMING_BITS;
	parameter [TB - 1:0] CLOCKS_PER_BAUD = 217;
	input wire i_clk;
	input wire i_reset;
	input wire i_wr;
	input wire [7:0] i_data;
	output reg o_uart_tx;
	output wire o_busy;
	localparam [3:0] TXUL_BIT_ZERO = 4'h0;
	localparam [3:0] TXUL_STOP = 4'h8;
	localparam [3:0] TXUL_IDLE = 4'hf;
	reg [TB - 1:0] baud_counter;
	reg [3:0] state;
	reg [7:0] lcl_data;
	reg r_busy;
	reg zero_baud_counter;
	initial r_busy = 1'b1;
	initial state = TXUL_IDLE;
	always @(posedge i_clk)
		if (i_reset) begin
			r_busy <= 1'b1;
			state <= TXUL_IDLE;
		end
		else if (!zero_baud_counter)
			r_busy <= 1'b1;
		else if (state > TXUL_STOP) begin
			state <= TXUL_IDLE;
			r_busy <= 1'b0;
			if (i_wr && !r_busy) begin
				r_busy <= 1'b1;
				state <= TXUL_BIT_ZERO;
			end
		end
		else begin
			r_busy <= 1'b1;
			if (state <= TXUL_STOP)
				state <= state + 1'b1;
			else
				state <= TXUL_IDLE;
		end
	assign o_busy = r_busy;
	initial lcl_data = 8'hff;
	always @(posedge i_clk)
		if (i_reset)
			lcl_data <= 8'hff;
		else if (i_wr && !r_busy)
			lcl_data <= i_data;
		else if (zero_baud_counter)
			lcl_data <= {1'b1, lcl_data[7:1]};
	initial o_uart_tx = 1'b1;
	always @(posedge i_clk)
		if (i_reset)
			o_uart_tx <= 1'b1;
		else if (i_wr && !r_busy)
			o_uart_tx <= 1'b0;
		else if (zero_baud_counter)
			o_uart_tx <= lcl_data[0];
	initial zero_baud_counter = 1'b1;
	initial baud_counter = 0;
	always @(posedge i_clk)
		if (i_reset) begin
			zero_baud_counter <= 1'b1;
			baud_counter <= 0;
		end
		else begin
			zero_baud_counter <= baud_counter == 1;
			if (state == TXUL_IDLE) begin
				baud_counter <= 0;
				zero_baud_counter <= 1'b1;
				if (i_wr && !r_busy) begin
					baud_counter <= CLOCKS_PER_BAUD - 1'b1;
					zero_baud_counter <= 1'b0;
				end
			end
			else if (!zero_baud_counter)
				baud_counter <= baud_counter - 1'b1;
			else if (state > TXUL_STOP) begin
				baud_counter <= 0;
				zero_baud_counter <= 1'b1;
			end
			else if (state == TXUL_STOP)
				baud_counter <= CLOCKS_PER_BAUD - 2;
			else
				baud_counter <= CLOCKS_PER_BAUD - 1'b1;
		end
endmodule
`default_nettype none
module rxuartlite (
	i_clk,
	i_reset,
	i_uart_rx,
	o_wr,
	o_data
);
	parameter TIMER_BITS = 10;
	parameter [TIMER_BITS - 1:0] CLOCKS_PER_BAUD = 217;
	localparam TB = TIMER_BITS;
	localparam [3:0] RXUL_BIT_ZERO = 4'h0;
	localparam [3:0] RXUL_BIT_ONE = 4'h1;
	localparam [3:0] RXUL_BIT_TWO = 4'h2;
	localparam [3:0] RXUL_BIT_THREE = 4'h3;
	localparam [3:0] RXUL_BIT_FOUR = 4'h4;
	localparam [3:0] RXUL_BIT_FIVE = 4'h5;
	localparam [3:0] RXUL_BIT_SIX = 4'h6;
	localparam [3:0] RXUL_BIT_SEVEN = 4'h7;
	localparam [3:0] RXUL_STOP = 4'h8;
	localparam [3:0] RXUL_WAIT = 4'h9;
	localparam [3:0] RXUL_IDLE = 4'hf;
	input wire i_clk;
	input wire i_reset;
	input wire i_uart_rx;
	output reg o_wr;
	output reg [7:0] o_data;
	wire [TB - 1:0] half_baud;
	reg [3:0] state;
	assign half_baud = {1'b0, CLOCKS_PER_BAUD[TB - 1:1]};
	reg [TB - 1:0] baud_counter;
	reg zero_baud_counter;
	reg q_uart;
	reg qq_uart;
	reg ck_uart;
	reg [TB - 1:0] chg_counter;
	reg half_baud_time;
	reg [7:0] data_reg;
	initial q_uart = 1'b1;
	initial qq_uart = 1'b1;
	initial ck_uart = 1'b1;
	always @(posedge i_clk)
		if (i_reset)
			{ck_uart, qq_uart, q_uart} <= 3'b111;
		else
			{ck_uart, qq_uart, q_uart} <= {qq_uart, q_uart, i_uart_rx};
	initial chg_counter = {TB {1'b1}};
	always @(posedge i_clk)
		if (i_reset)
			chg_counter <= {TB {1'b1}};
		else if (qq_uart != ck_uart)
			chg_counter <= 0;
		else if (chg_counter != {TB {1'b1}})
			chg_counter <= chg_counter + 1;
	initial half_baud_time = 0;
	always @(posedge i_clk)
		if (i_reset)
			half_baud_time <= 0;
		else
			half_baud_time <= !ck_uart && (chg_counter >= (half_baud - (1'b1 + 1'b1)));
	initial state = RXUL_IDLE;
	always @(posedge i_clk)
		if (i_reset)
			state <= RXUL_IDLE;
		else if (state == RXUL_IDLE) begin
			state <= RXUL_IDLE;
			if (!ck_uart && half_baud_time)
				state <= RXUL_BIT_ZERO;
		end
		else if ((state >= RXUL_WAIT) && ck_uart)
			state <= RXUL_IDLE;
		else if (zero_baud_counter) begin
			if (state <= RXUL_STOP)
				state <= state + 1;
		end
	always @(posedge i_clk)
		if (zero_baud_counter && (state != RXUL_STOP))
			data_reg <= {qq_uart, data_reg[7:1]};
	initial o_wr = 1'b0;
	initial o_data = 8'h00;
	always @(posedge i_clk)
		if (i_reset) begin
			o_wr <= 1'b0;
			o_data <= 8'h00;
		end
		else if ((zero_baud_counter && (state == RXUL_STOP)) && ck_uart) begin
			o_wr <= 1'b1;
			o_data <= data_reg;
		end
		else
			o_wr <= 1'b0;
	initial baud_counter = 0;
	always @(posedge i_clk)
		if (i_reset)
			baud_counter <= 0;
		else if (((state == RXUL_IDLE) && !ck_uart) && half_baud_time)
			baud_counter <= CLOCKS_PER_BAUD - 1'b1;
		else if (state == RXUL_WAIT)
			baud_counter <= 0;
		else if (zero_baud_counter && (state < RXUL_STOP))
			baud_counter <= CLOCKS_PER_BAUD - 1'b1;
		else if (!zero_baud_counter)
			baud_counter <= baud_counter - 1'b1;
	initial zero_baud_counter = 1'b1;
	always @(posedge i_clk)
		if (i_reset)
			zero_baud_counter <= 1'b1;
		else if (((state == RXUL_IDLE) && !ck_uart) && half_baud_time)
			zero_baud_counter <= 1'b0;
		else if (state == RXUL_WAIT)
			zero_baud_counter <= 1'b1;
		else if (zero_baud_counter && (state < RXUL_STOP))
			zero_baud_counter <= 1'b0;
		else if (baud_counter == 1)
			zero_baud_counter <= 1'b1;
endmodule
module SystemDemo (
	external_clk_25MHz,
	ftdi_txd,
	btn,
	led,
	ftdi_rxd,
	wifi_gpio0
);
	input external_clk_25MHz;
	input ftdi_txd;
	input [6:0] btn;
	output wire [7:0] led;
	output wire ftdi_rxd;
	output wire wifi_gpio0;
	localparam signed [31:0] MmapOutput = 32'hff001000;
	localparam signed [31:0] MmapInput = 32'hff002000;
	wire clk_proc;
	wire clk_locked;
	MyClockGen clock_gen(
		.input_clk_25MHz(external_clk_25MHz),
		.clk_proc(clk_proc),
		.locked(clk_locked)
	);
	wire [7:0] rx_data;
	wire rx_ready;
	wire [7:0] data2cpu_uart;
	wire [7:0] data2cpu_cpu;
	assign data2cpu_uart = (rx_ready ? rx_data : 8'h00);
	assign led = data2cpu_cpu;
	wire [7:0] tx_data;
	wire tx_ready;
	wire tx_busy;
	wire [7:0] data2uart_cpu;
	wire [7:0] data2uart_uart;
	assign tx_ready = !tx_busy;
	assign tx_data = data2uart_uart;
	rxuartlite uart_receive(
		.i_clk(external_clk_25MHz),
		.i_reset(1'b0),
		.i_uart_rx(ftdi_txd),
		.o_wr(rx_ready),
		.o_data(rx_data)
	);
	wire [31:0] mem_data_addr;
	wire [31:0] mem_data_to_write;
	wire [3:0] mem_data_we;
	DP16KD #(
		.DATA_WIDTH_A(9),
		.DATA_WIDTH_B(9),
		.REGMODE_A("NOREG"),
		.REGMODE_B("NOREG"),
		.RESETMODE("SYNC"),
		.ASYNC_RESET_RELEASE("SYNC"),
		.WRITEMODE_A("NORMAL"),
		.WRITEMODE_B("NORMAL")
	) uart2cpu(
		.ADA13(1'b0),
		.ADA12(1'b0),
		.ADA11(1'b0),
		.ADA10(1'b0),
		.ADA9(1'b0),
		.ADA8(1'b0),
		.ADA7(1'b0),
		.ADA6(1'b0),
		.ADA5(1'b0),
		.ADA4(1'b0),
		.ADA3(1'b0),
		.ADA2(1'b0),
		.ADA1(1'b0),
		.ADA0(1'b0),
		.DIA8(1'b0),
		.DIA7(data2cpu_uart[7]),
		.DIA6(data2cpu_uart[6]),
		.DIA5(data2cpu_uart[5]),
		.DIA4(data2cpu_uart[4]),
		.DIA3(data2cpu_uart[3]),
		.DIA2(data2cpu_uart[2]),
		.DIA1(data2cpu_uart[1]),
		.DIA0(data2cpu_uart[0]),
		.CEA(1'b1),
		.OCEA(1'b1),
		.CLKA(external_clk_25MHz),
		.WEA(rx_ready),
		.RSTA(1'b0),
		.ADB13(1'b0),
		.ADB12(1'b0),
		.ADB11(1'b0),
		.ADB10(1'b0),
		.ADB9(1'b0),
		.ADB8(1'b0),
		.ADB7(1'b0),
		.ADB6(1'b0),
		.ADB5(1'b0),
		.ADB4(1'b0),
		.ADB3(1'b0),
		.ADB2(1'b0),
		.ADB1(1'b0),
		.ADB0(1'b0),
		.DIB8(1'b0),
		.DIB7(mem_data_to_write[7]),
		.DIB6(mem_data_to_write[6]),
		.DIB5(mem_data_to_write[5]),
		.DIB4(mem_data_to_write[4]),
		.DIB3(mem_data_to_write[3]),
		.DIB2(mem_data_to_write[2]),
		.DIB1(mem_data_to_write[1]),
		.DIB0(mem_data_to_write[0]),
		.DOB8(),
		.DOB7(data2cpu_cpu[7]),
		.DOB6(data2cpu_cpu[6]),
		.DOB5(data2cpu_cpu[5]),
		.DOB4(data2cpu_cpu[4]),
		.DOB3(data2cpu_cpu[3]),
		.DOB2(data2cpu_cpu[2]),
		.DOB1(data2cpu_cpu[1]),
		.DOB0(data2cpu_cpu[0]),
		.CEB(1'b1),
		.OCEB(1'b1),
		.CLKB(clk_proc),
		.WEB((mem_data_addr == MmapInput) && |mem_data_we),
		.RSTB(1'b0)
	);
	txuartlite uart_transmit(
		.i_clk(external_clk_25MHz),
		.i_reset(1'b0),
		.i_wr(tx_ready),
		.i_data(tx_data),
		.o_uart_tx(ftdi_rxd),
		.o_busy(tx_busy)
	);
	DP16KD #(
		.DATA_WIDTH_A(9),
		.DATA_WIDTH_B(9),
		.REGMODE_A("NOREG"),
		.REGMODE_B("NOREG"),
		.RESETMODE("SYNC"),
		.ASYNC_RESET_RELEASE("SYNC"),
		.WRITEMODE_A("NORMAL"),
		.WRITEMODE_B("NORMAL")
	) cpu2uart(
		.ADA13(1'b0),
		.ADA12(1'b0),
		.ADA11(1'b0),
		.ADA10(1'b0),
		.ADA9(1'b0),
		.ADA8(1'b0),
		.ADA7(1'b0),
		.ADA6(1'b0),
		.ADA5(1'b0),
		.ADA4(1'b0),
		.ADA3(1'b0),
		.ADA2(1'b0),
		.ADA1(1'b0),
		.ADA0(1'b0),
		.DIA8(1'b0),
		.DIA7(data2uart_cpu[7]),
		.DIA6(data2uart_cpu[6]),
		.DIA5(data2uart_cpu[5]),
		.DIA4(data2uart_cpu[4]),
		.DIA3(data2uart_cpu[3]),
		.DIA2(data2uart_cpu[2]),
		.DIA1(data2uart_cpu[1]),
		.DIA0(data2uart_cpu[0]),
		.CEA(1'b1),
		.OCEA(1'b1),
		.CLKA(clk_proc),
		.WEA((mem_data_addr == MmapOutput) && |mem_data_we),
		.RSTA(1'b0),
		.ADB13(1'b0),
		.ADB12(1'b0),
		.ADB11(1'b0),
		.ADB10(1'b0),
		.ADB9(1'b0),
		.ADB8(1'b0),
		.ADB7(1'b0),
		.ADB6(1'b0),
		.ADB5(1'b0),
		.ADB4(1'b0),
		.ADB3(1'b0),
		.ADB2(1'b0),
		.ADB1(1'b0),
		.ADB0(1'b0),
		.DOB8(),
		.DOB7(data2uart_uart[7]),
		.DOB6(data2uart_uart[6]),
		.DOB5(data2uart_uart[5]),
		.DOB4(data2uart_uart[4]),
		.DOB3(data2uart_uart[3]),
		.DOB2(data2uart_uart[2]),
		.DOB1(data2uart_uart[1]),
		.DOB0(data2uart_uart[0]),
		.CEB(1'b1),
		.OCEB(1'b1),
		.CLKB(external_clk_25MHz),
		.WEB(1'b0),
		.RSTB(1'b0)
	);
	wire [31:0] pc_to_imem;
	wire [31:0] insn_from_imem;
	wire [31:0] mem_data_loaded_value;
	wire [31:0] trace_completed_pc;
	wire [31:0] trace_completed_insn;
	wire [31:0] trace_completed_cycle_status;
	assign data2uart_cpu = mem_data_to_write[7:0];
	MemorySingleCycle #(.NUM_WORDS(1024)) memory(
		.rst(!clk_locked),
		.clk(clk_proc),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.load_data_from_dmem(mem_data_loaded_value),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem((mem_data_addr == MmapOutput ? 4'd0 : mem_data_we))
	);
	DatapathPipelined datapath(
		.clk(clk_proc),
		.rst(!clk_locked),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we),
		.load_data_from_dmem((mem_data_addr == MmapInput ? {24'd0, data2cpu_cpu} : mem_data_loaded_value)),
		.halt(),
		.trace_completed_pc(trace_completed_pc),
		.trace_completed_insn(trace_completed_insn),
		.trace_completed_cycle_status(trace_completed_cycle_status)
	);
endmodule