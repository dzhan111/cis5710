module MyClockGen (
	input_clk_25MHz,
	clk_proc,
	locked
);
	input input_clk_25MHz;
	output wire clk_proc;
	output wire locked;
	wire clkfb;
	(* FREQUENCY_PIN_CLKI = "25" *) (* FREQUENCY_PIN_CLKOP = "20" *) (* ICP_CURRENT = "12" *) (* LPF_RESISTOR = "8" *) (* MFG_ENABLE_FILTEROPAMP = "1" *) (* MFG_GMCREF_SEL = "2" *) EHXPLLL #(
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
		.CLKOP_DIV(30),
		.CLKOP_CPHASE(15),
		.CLKOP_FPHASE(0),
		.FEEDBK_PATH("INT_OP"),
		.CLKFB_DIV(4)
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
	input wire [4:0] rd;
	input wire [31:0] rd_data;
	input wire [4:0] rs1;
	output wire [31:0] rs1_data;
	input wire [4:0] rs2;
	output wire [31:0] rs2_data;
	input wire clk;
	input wire we;
	input wire rst;
	localparam signed [31:0] NumRegs = 32;
	reg [31:0] regs [0:31];
	always @(posedge clk)
		if (rst) begin : sv2v_autoblock_1
			integer i;
			for (i = 0; i < NumRegs; i = i + 1)
				regs[i] <= 0;
		end
		else if (we && (rd != 0))
			regs[rd] <= rd_data;
	assign rs1_data = (rs1 == 0 ? 32'd0 : ((we && (rd != 0)) && (rd == rs1) ? rd_data : regs[rs1]));
	assign rs2_data = (rs2 == 0 ? 32'd0 : ((we && (rd != 0)) && (rd == rs2) ? rd_data : regs[rs2]));
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
	output reg [31:0] addr_to_dmem;
	input wire [31:0] load_data_from_dmem;
	output reg [31:0] store_data_to_dmem;
	output reg [3:0] store_we_to_dmem;
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
	localparam [250:0] BUBBLE_INSN = 251'h000000000000000000000000000000000000000000000000000000000000000;
	reg [31:0] cycles_current;
	always @(posedge clk)
		if (rst)
			cycles_current <= 0;
		else
			cycles_current <= cycles_current + 1;
	reg [31:0] f_pc_current;
	wire [31:0] f_insn;
	reg [31:0] f_cycle_status;
	reg [95:0] decode_state;
	reg [378:0] execute_state;
	reg [378:0] memory_state;
	reg [378:0] writeback_state;
	reg [137:0] div_pipe [0:7];
	reg x_div_launch;
	reg [137:0] x_div_meta;
	wire div_done_valid;
	reg [31:0] div_done_result;
	wire div_pipe_conflict;
	assign div_done_valid = div_pipe[7][137];
	assign div_pipe_conflict = div_done_valid;
	reg load2use_hazard;
	reg x_branchTaken;
	reg [31:0] x_branchTarget;
	always @(posedge clk)
		if (rst) begin
			f_pc_current <= 32'd0;
			f_cycle_status <= 32'd2;
		end
		else begin
			f_cycle_status <= 32'd2;
			if (x_branchTaken)
				f_pc_current <= x_branchTarget;
			else if (load2use_hazard)
				f_pc_current <= f_pc_current;
			else if (div_pipe_conflict)
				f_pc_current <= f_pc_current;
			else
				f_pc_current <= f_pc_current + 4;
		end
	assign pc_to_imem = f_pc_current;
	assign f_insn = insn_from_imem;
	always @(posedge clk)
		if (rst)
			decode_state <= 96'h000000000000000000000001;
		else if (x_branchTaken)
			decode_state <= 96'h000000000000000000000004;
		else if (load2use_hazard)
			decode_state <= decode_state;
		else if (div_pipe_conflict)
			decode_state <= decode_state;
		else
			decode_state <= {f_pc_current, f_insn, f_cycle_status};
	wire [6:0] d_insn_funct7;
	wire [4:0] d_insn_rs2;
	wire [4:0] d_insn_rs1;
	wire [2:0] d_insn_funct3;
	wire [4:0] d_insn_rd;
	wire [6:0] d_insn_opcode;
	wire [11:0] d_imm_i;
	wire [11:0] d_imm_s;
	wire [12:0] d_imm_b;
	wire [20:0] d_imm_j;
	assign {d_insn_funct7, d_insn_rs2, d_insn_rs1, d_insn_funct3, d_insn_rd, d_insn_opcode} = decode_state[63-:32];
	assign d_imm_i = decode_state[63:52];
	assign d_imm_s = {decode_state[63:57], decode_state[43:39]};
	assign d_imm_b = {decode_state[63], decode_state[39], decode_state[62:57], decode_state[43:40], 1'b0};
	assign d_imm_j = {decode_state[63], decode_state[51:44], decode_state[52], decode_state[62:52]};
	wire [31:0] d_imm_i_sext = {{20 {d_imm_i[11]}}, d_imm_i[11:0]};
	wire [31:0] d_imm_s_sext = {{20 {d_imm_s[11]}}, d_imm_s[11:0]};
	wire [31:0] d_imm_b_sext = {{19 {d_imm_b[12]}}, d_imm_b[12:0]};
	wire [31:0] d_imm_j_sext = {{11 {d_imm_j[20]}}, d_imm_j[20:0]};
	wire d_bypassable;
	assign d_bypassable = (((d_insn_rd != 0) && (d_insn_opcode != OpcodeBranch)) && (d_insn_opcode != OpcodeMiscMem)) && (d_insn_opcode != OpcodeEnviron);
	wire [250:0] d_decoded_insn;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	assign d_decoded_insn = {sv2v_cast_32(decode_state[63-:32]), d_insn_rs1, d_insn_rs2, d_insn_rd, d_insn_funct3, d_insn_funct7, d_insn_opcode, d_imm_i, d_imm_i_sext, d_imm_s, d_imm_s_sext, d_imm_b, d_imm_b_sext, d_imm_j, d_imm_j_sext, d_bypassable};
	wire [4:0] rf_rd;
	wire [31:0] rf_rd_data;
	wire [4:0] rf_rs1 = d_insn_rs1;
	wire [31:0] rf_rs1_data;
	wire [4:0] rf_rs2 = d_insn_rs2;
	wire [31:0] rf_rs2_data;
	wire rf_we;
	RegFile rf(
		.rd(rf_rd),
		.rd_data(rf_rd_data),
		.rs1(rf_rs1),
		.rs1_data(rf_rs1_data),
		.rs2(rf_rs2),
		.rs2_data(rf_rs2_data),
		.clk(clk),
		.we(rf_we),
		.rst(rst)
	);
	reg [31:0] d_rs1_data;
	reg [31:0] d_rs2_data;
	reg [31:0] w_value;
	always @(*) begin
		if (_sv2v_0)
			;
		if ((d_insn_rs1 == writeback_state[336-:5]) && writeback_state[128])
			d_rs1_data = w_value;
		else
			d_rs1_data = rf_rs1_data;
		if ((d_insn_rs2 == writeback_state[336-:5]) && (d_insn_rs2 != 0))
			d_rs2_data = w_value;
		else
			d_rs2_data = rf_rs2_data;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		load2use_hazard = 1'b0;
		if ((execute_state[321-:7] == OpcodeLoad) && (execute_state[336-:5] != 5'd0)) begin
			if ((d_insn_rs1 == execute_state[336-:5]) || (d_insn_rs2 == execute_state[336-:5]))
				load2use_hazard = 1'b1;
		end
	end
	always @(posedge clk)
		if (rst)
			execute_state <= {BUBBLE_INSN, 128'h00000000000000010000000000000000};
		else if (x_branchTaken)
			execute_state <= {BUBBLE_INSN, 128'h00000000000000040000000000000000};
		else if (load2use_hazard)
			execute_state <= {BUBBLE_INSN, 128'h00000000000000080000000000000000};
		else if (div_pipe_conflict)
			execute_state <= execute_state;
		else
			execute_state <= {d_decoded_insn, sv2v_cast_32(decode_state[95-:32]), sv2v_cast_32(decode_state[31-:32]), d_rs1_data, d_rs2_data};
	reg [31:0] x_rs1_data;
	reg [31:0] x_rs2_data;
	always @(*) begin
		if (_sv2v_0)
			;
		if ((execute_state[346-:5] == memory_state[336-:5]) && memory_state[128])
			x_rs1_data = memory_state[63-:32];
		else if ((execute_state[346-:5] == writeback_state[336-:5]) && writeback_state[128])
			x_rs1_data = w_value;
		else
			x_rs1_data = execute_state[63-:32];
		if ((execute_state[341-:5] == memory_state[336-:5]) && memory_state[128])
			x_rs2_data = memory_state[63-:32];
		else if ((execute_state[341-:5] == writeback_state[336-:5]) && writeback_state[128])
			x_rs2_data = w_value;
		else
			x_rs2_data = execute_state[31-:32];
	end
	reg [31:0] x_a;
	reg [31:0] x_b;
	wire [31:0] x_sum;
	wire [31:0] x_rem;
	wire [31:0] x_quo;
	reg x_cin;
	CarryLookaheadAdder cla(
		.a(x_a),
		.b(x_b),
		.cin(x_cin),
		.sum(x_sum)
	);
	DividerUnsignedPipelined dv(
		.clk(clk),
		.rst(rst),
		.stall(1'b0),
		.i_dividend(x_a),
		.i_divisor(x_b),
		.o_remainder(x_rem),
		.o_quotient(x_quo)
	);
	reg [31:0] x_result;
	reg x_branchConditional;
	reg [63:0] x_mulfull;
	reg x_illegal_insn;
	always @(*) begin
		if (_sv2v_0)
			;
		x_illegal_insn = 1'b0;
		x_branchConditional = 1'b0;
		x_cin = 1'b0;
		x_result = 32'b00000000000000000000000000000000;
		x_a = 32'b00000000000000000000000000000000;
		x_b = 32'b00000000000000000000000000000001;
		x_mulfull = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		x_branchTaken = 1'b0;
		x_branchTarget = 32'b00000000000000000000000000000000;
		x_div_launch = 1'b0;
		case (execute_state[321-:7])
			OpcodeLui: x_result = {12'b000000000000, execute_state[328-:7], execute_state[341-:5], execute_state[346-:5], execute_state[331-:3]} << 12;
			OpcodeAuipc: x_result = execute_state[127-:32] + ({12'b000000000000, execute_state[328-:7], execute_state[341-:5], execute_state[346-:5], execute_state[331-:3]} << 12);
			OpcodeRegImm:
				case (execute_state[331-:3])
					3'b000: begin
						x_a = x_rs1_data;
						x_b = execute_state[302-:32];
						x_result = x_sum;
					end
					3'b010: x_result = ($signed(x_rs1_data) < $signed(execute_state[302-:32]) ? 1 : 0);
					3'b011: x_result = (x_rs1_data < execute_state[302-:32] ? 1 : 0);
					3'b100: x_result = x_rs1_data ^ execute_state[302-:32];
					3'b110: x_result = x_rs1_data | execute_state[302-:32];
					3'b111: x_result = x_rs1_data & execute_state[302-:32];
					3'b001:
						if (execute_state[328-:7] == 7'b0000000)
							x_result = x_rs1_data << execute_state[307:303];
						else
							x_illegal_insn = 1'b1;
					3'b101:
						if (execute_state[328-:7] == 7'h00)
							x_result = x_rs1_data >> execute_state[307:303];
						else if (execute_state[328-:7] == 7'h20)
							x_result = $signed(x_rs1_data) >>> execute_state[307:303];
						else
							x_illegal_insn = 1'b1;
				endcase
			OpcodeRegReg:
				case (execute_state[331-:3])
					3'b000:
						if (execute_state[328-:7] == 7'h00) begin
							x_a = x_rs1_data;
							x_b = x_rs2_data;
							x_result = x_sum;
						end
						else if (execute_state[328-:7] == 7'h20) begin
							x_a = x_rs1_data;
							x_b = ~x_rs2_data;
							x_cin = 1'b1;
							x_result = x_sum;
						end
						else if (execute_state[328-:7] == 7'h01) begin
							x_mulfull = x_rs1_data * x_rs2_data;
							x_result = x_mulfull[31:0];
						end
						else
							x_illegal_insn = 1'b1;
					3'b001:
						if (execute_state[328-:7] == 7'h00)
							x_result = x_rs1_data << x_rs2_data[4:0];
						else if (execute_state[328-:7] == 7'h01) begin
							x_mulfull = $signed(x_rs1_data) * $signed(x_rs2_data);
							x_result = x_mulfull[63:32];
						end
						else
							x_illegal_insn = 1'b1;
					3'b010:
						if (execute_state[328-:7] == 7'h00)
							x_result = ($signed(x_rs1_data) < $signed(x_rs2_data) ? 1 : 0);
						else if (execute_state[328-:7] == 7'h01) begin
							x_mulfull = {{32 {x_rs1_data[31]}}, x_rs1_data} * {32'b00000000000000000000000000000000, x_rs2_data};
							x_result = x_mulfull[63:32];
						end
						else
							x_illegal_insn = 1'b1;
					3'b011:
						if (execute_state[328-:7] == 7'h00)
							x_result = (x_rs1_data < x_rs2_data ? 1 : 0);
						else if (execute_state[328-:7] == 7'h01) begin
							x_mulfull = $unsigned(x_rs1_data) * $unsigned(x_rs2_data);
							x_result = x_mulfull[63:32];
						end
						else
							x_illegal_insn = 1'b1;
					3'b100:
						if (execute_state[328-:7] == 7'h00)
							x_result = x_rs1_data ^ x_rs2_data;
						else if (execute_state[328-:7] == 7'h01) begin
							x_div_launch = 1'b1;
							if (x_rs2_data == 32'b00000000000000000000000000000000) begin
								x_a = 32'd0;
								x_b = 32'd1;
							end
							else begin
								x_a = (x_rs1_data[31] ? ~x_rs1_data + 1 : x_rs1_data);
								x_b = (x_rs2_data[31] ? ~x_rs2_data + 1 : x_rs2_data);
							end
						end
						else
							x_illegal_insn = 1'b1;
					3'b101:
						if (execute_state[328-:7] == 7'h00)
							x_result = x_rs1_data >> x_rs2_data[4:0];
						else if (execute_state[328-:7] == 7'h20)
							x_result = $signed(x_rs1_data) >>> x_rs2_data[4:0];
						else if (execute_state[328-:7] == 7'h01) begin
							x_div_launch = 1'b1;
							x_a = x_rs1_data;
							x_b = (x_rs2_data == 0 ? 32'd1 : x_rs2_data);
						end
						else
							x_illegal_insn = 1'b1;
					3'b110:
						if (execute_state[328-:7] == 7'h00)
							x_result = x_rs1_data | x_rs2_data;
						else if (execute_state[328-:7] == 7'h01) begin
							x_div_launch = 1'b1;
							if (x_rs2_data == 32'b00000000000000000000000000000000) begin
								x_a = 32'd0;
								x_b = 32'd1;
							end
							else begin
								x_a = (x_rs1_data[31] ? ~x_rs1_data + 1 : x_rs1_data);
								x_b = (x_rs2_data[31] ? ~x_rs2_data + 1 : x_rs2_data);
							end
						end
						else
							x_illegal_insn = 1'b1;
					3'b111:
						if (execute_state[328-:7] == 7'h00)
							x_result = x_rs1_data & x_rs2_data;
						else if (execute_state[328-:7] == 7'h01) begin
							x_div_launch = 1'b1;
							x_a = x_rs1_data;
							x_b = (x_rs2_data == 0 ? 32'd1 : x_rs2_data);
						end
						else
							x_illegal_insn = 1'b1;
				endcase
			OpcodeLoad: x_result = x_rs1_data + execute_state[302-:32];
			OpcodeStore: x_result = x_rs1_data + execute_state[258-:32];
			OpcodeJal: begin
				x_result = execute_state[127-:32] + 4;
				x_branchTarget = execute_state[127-:32] + execute_state[160-:32];
				x_branchTaken = 1'b1;
			end
			OpcodeJalr:
				if (execute_state[331-:3] == 3'b000) begin
					x_result = execute_state[127-:32] + 4;
					x_branchTarget = (x_rs1_data + execute_state[302-:32]) & ~32'h00000001;
					x_branchTaken = 1'b1;
				end
				else
					x_illegal_insn = 1'b1;
			OpcodeBranch: begin
				case (execute_state[331-:3])
					3'b000: x_branchConditional = x_rs1_data == x_rs2_data;
					3'b001: x_branchConditional = x_rs1_data != x_rs2_data;
					3'b100: x_branchConditional = $signed(x_rs1_data) < $signed(x_rs2_data);
					3'b101: x_branchConditional = $signed(x_rs1_data) >= $signed(x_rs2_data);
					3'b110: x_branchConditional = $unsigned(x_rs1_data) < $unsigned(x_rs2_data);
					3'b111: x_branchConditional = $unsigned(x_rs1_data) >= $unsigned(x_rs2_data);
					default: x_illegal_insn = 1'b1;
				endcase
				if (x_branchConditional) begin
					x_branchTarget = $signed(execute_state[127-:32]) + $signed(execute_state[213-:32]);
					x_branchTaken = 1'b1;
				end
			end
			OpcodeEnviron:
				if (execute_state[378:354] != 25'b0000000000000000000000000)
					x_illegal_insn = 1'b1;
			OpcodeMiscMem:
				;
			default: x_illegal_insn = 1'b1;
		endcase
	end
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		x_div_meta = {1'b0, sv2v_cast_5(execute_state[336-:5]), 36'h000000000, execute_state[127-:32], sv2v_cast_32(execute_state[378-:32]), execute_state[95-:32]};
		if (x_div_launch) begin
			x_div_meta[137] = 1'b1;
			case (execute_state[331-:3])
				3'b100: begin
					x_div_meta[131] = 1'b0;
					if (x_rs2_data == 0) begin
						x_div_meta[128] = 1'b1;
						x_div_meta[127-:32] = 32'hffffffff;
					end
					else
						x_div_meta[130] = x_rs1_data[31] ^ x_rs2_data[31];
				end
				3'b101: begin
					x_div_meta[131] = 1'b0;
					if (x_rs2_data == 0) begin
						x_div_meta[128] = 1'b1;
						x_div_meta[127-:32] = 32'hffffffff;
					end
				end
				3'b110: begin
					x_div_meta[131] = 1'b1;
					if (x_rs2_data == 0) begin
						x_div_meta[128] = 1'b1;
						x_div_meta[127-:32] = x_rs1_data;
					end
					else
						x_div_meta[129] = x_rs1_data[31];
				end
				3'b111: begin
					x_div_meta[131] = 1'b1;
					if (x_rs2_data == 0) begin
						x_div_meta[128] = 1'b1;
						x_div_meta[127-:32] = x_rs1_data;
					end
				end
				default:
					;
			endcase
		end
	end
	always @(posedge clk)
		if (rst) begin : sv2v_autoblock_1
			integer i;
			for (i = 0; i < 8; i = i + 1)
				div_pipe[i] <= 138'h00000000000000000000000000000000001;
		end
		else begin
			begin : sv2v_autoblock_2
				integer i;
				for (i = 7; i > 0; i = i - 1)
					div_pipe[i] <= div_pipe[i - 1];
			end
			div_pipe[0] <= x_div_meta;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		if (div_pipe[7][128])
			div_done_result = div_pipe[7][127-:32];
		else if (div_pipe[7][131])
			div_done_result = (div_pipe[7][129] ? ~x_rem + 1 : x_rem);
		else
			div_done_result = (div_pipe[7][130] ? ~x_quo + 1 : x_quo);
	end
	function automatic [250:0] sv2v_cast_251;
		input reg [250:0] inp;
		sv2v_cast_251 = inp;
	endfunction
	always @(posedge clk)
		if (rst)
			memory_state <= {BUBBLE_INSN, 128'h00000000000000010000000000000000};
		else if (div_done_valid)
			memory_state <= memory_state;
		else if (x_div_launch)
			memory_state <= {BUBBLE_INSN, 128'h00000000000000020000000000000000};
		else
			memory_state <= {sv2v_cast_251(execute_state[378-:251]), sv2v_cast_32(execute_state[127-:32]), sv2v_cast_32(execute_state[95-:32]), x_result, x_rs2_data};
	reg [31:0] m_loaded_data;
	reg [1:0] m_lowerOrderAddr;
	reg m_illegal_insn;
	always @(*) begin
		if (_sv2v_0)
			;
		m_lowerOrderAddr = memory_state[33:32];
		addr_to_dmem = {memory_state[63:34], 2'b00};
		m_loaded_data = 32'b00000000000000000000000000000000;
		m_illegal_insn = 1'b0;
		store_we_to_dmem = 4'b0000;
		store_data_to_dmem = 32'b00000000000000000000000000000000;
		if (memory_state[321-:7] == OpcodeLoad)
			case (memory_state[331-:3])
				3'b000:
					case (m_lowerOrderAddr)
						2'b00: m_loaded_data = {{24 {load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};
						2'b01: m_loaded_data = {{24 {load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
						2'b10: m_loaded_data = {{24 {load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
						2'b11: m_loaded_data = {{24 {load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
					endcase
				3'b001:
					case (m_lowerOrderAddr)
						2'b00: m_loaded_data = {{16 {load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
						2'b01: m_loaded_data = {{16 {load_data_from_dmem[23]}}, load_data_from_dmem[23:8]};
						2'b10: m_loaded_data = {{16 {load_data_from_dmem[31]}}, load_data_from_dmem[31:16]};
						2'b11: m_illegal_insn = 1'b1;
					endcase
				3'b010:
					if (m_lowerOrderAddr == 2'b00)
						m_loaded_data = load_data_from_dmem[31:0];
					else
						m_illegal_insn = 1'b1;
				3'b100:
					case (m_lowerOrderAddr)
						2'b00: m_loaded_data = {24'b000000000000000000000000, load_data_from_dmem[7:0]};
						2'b01: m_loaded_data = {24'b000000000000000000000000, load_data_from_dmem[15:8]};
						2'b10: m_loaded_data = {24'b000000000000000000000000, load_data_from_dmem[23:16]};
						2'b11: m_loaded_data = {24'b000000000000000000000000, load_data_from_dmem[31:24]};
					endcase
				3'b101:
					case (m_lowerOrderAddr)
						2'b00: m_loaded_data = {16'b0000000000000000, load_data_from_dmem[15:0]};
						2'b01: m_loaded_data = {16'b0000000000000000, load_data_from_dmem[23:8]};
						2'b10: m_loaded_data = {16'b0000000000000000, load_data_from_dmem[31:16]};
						2'b11: m_illegal_insn = 1'b1;
					endcase
				default: m_illegal_insn = 1'b1;
			endcase
		if (memory_state[321-:7] == OpcodeStore)
			case (memory_state[331-:3])
				3'b000:
					case (m_lowerOrderAddr)
						2'b00: begin
							store_we_to_dmem = 4'b0001;
							store_data_to_dmem = {24'b000000000000000000000000, memory_state[7:0]};
						end
						2'b01: begin
							store_we_to_dmem = 4'b0010;
							store_data_to_dmem = {16'b0000000000000000, memory_state[7:0], 8'b00000000};
						end
						2'b10: begin
							store_we_to_dmem = 4'b0100;
							store_data_to_dmem = {8'b00000000, memory_state[7:0], 16'b0000000000000000};
						end
						2'b11: begin
							store_we_to_dmem = 4'b1000;
							store_data_to_dmem = {memory_state[7:0], 24'b000000000000000000000000};
						end
					endcase
				3'b001:
					case (m_lowerOrderAddr)
						2'b00: begin
							store_we_to_dmem = 4'b0011;
							store_data_to_dmem = {16'b0000000000000000, memory_state[15:0]};
						end
						2'b01: begin
							store_we_to_dmem = 4'b0110;
							store_data_to_dmem = {8'b00000000, memory_state[15:0], 8'b00000000};
						end
						2'b10: begin
							store_we_to_dmem = 4'b1100;
							store_data_to_dmem = {memory_state[15:0], 16'b0000000000000000};
						end
						2'b11: m_illegal_insn = 1'b1;
					endcase
				3'b010:
					if (m_lowerOrderAddr == 2'b00) begin
						store_we_to_dmem = 4'b1111;
						store_data_to_dmem = memory_state[31-:32];
					end
					else
						m_illegal_insn = 1'b1;
				default: m_illegal_insn = 1'b1;
			endcase
	end
	always @(posedge clk)
		if (rst)
			writeback_state <= {BUBBLE_INSN, 128'h00000000000000010000000000000000};
		else if (div_done_valid)
			writeback_state <= {sv2v_cast_251({sv2v_cast_32(div_pipe[7][63-:32]), 10'h000, sv2v_cast_5(div_pipe[7][136-:5]), 10'h000, OpcodeRegReg, 187'h00000000000000000000000000000000000000000000001}), sv2v_cast_32(div_pipe[7][95-:32]), sv2v_cast_32(div_pipe[7][31-:32]), div_done_result, 32'd0};
		else
			writeback_state <= {sv2v_cast_251(memory_state[378-:251]), sv2v_cast_32(memory_state[127-:32]), sv2v_cast_32(memory_state[95-:32]), sv2v_cast_32(memory_state[63-:32]), m_loaded_data};
	wire w_illegal_insn;
	reg w_we;
	reg w_halt;
	always @(*) begin
		if (_sv2v_0)
			;
		case (writeback_state[321-:7])
			OpcodeLui, OpcodeAuipc, OpcodeRegImm, OpcodeRegReg, OpcodeJal, OpcodeJalr: begin
				w_we = 1'b1;
				w_value = writeback_state[63-:32];
				w_halt = 1'b0;
			end
			OpcodeLoad: begin
				w_we = 1'b1;
				w_value = writeback_state[31-:32];
				w_halt = 1'b0;
			end
			OpcodeEnviron: begin
				w_we = 1'b0;
				w_value = 32'b00000000000000000000000000000000;
				w_halt = 1'b1;
			end
			default: begin
				w_we = 1'b0;
				w_value = 32'b00000000000000000000000000000000;
				w_halt = 1'b0;
			end
		endcase
		if (writeback_state[336-:5] == 0)
			w_we = 1'b0;
	end
	assign rf_we = w_we;
	assign rf_rd = writeback_state[336-:5];
	assign rf_rd_data = w_value;
	assign halt = w_halt;
	assign trace_completed_pc = writeback_state[127-:32];
	assign trace_completed_insn = writeback_state[378-:32];
	assign trace_completed_cycle_status = writeback_state[95-:32];
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
	initial $readmemh("mem_initial_contents.hex", mem_array, 0);
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
`default_nettype none
module SystemResourceCheck (
	external_clk_25MHz,
	btn,
	led
);
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output wire [7:0] led;
	wire clk_proc;
	wire clk_locked;
	MyClockGen clock_gen(
		.input_clk_25MHz(external_clk_25MHz),
		.clk_proc(clk_proc),
		.locked(clk_locked)
	);
	wire [31:0] pc_to_imem;
	wire [31:0] insn_from_imem;
	wire [31:0] mem_data_addr;
	wire [31:0] mem_data_loaded_value;
	wire [31:0] mem_data_to_write;
	wire [3:0] mem_data_we;
	wire [31:0] trace_completed_pc;
	wire [31:0] trace_completed_insn;
	wire [31:0] trace_completed_cycle_status;
	MemorySingleCycle #(.NUM_WORDS(128)) memory(
		.rst(!clk_locked),
		.clk(clk_proc),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.load_data_from_dmem(mem_data_loaded_value),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we)
	);
	DatapathPipelined datapath(
		.clk(clk_proc),
		.rst(!clk_locked),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we),
		.load_data_from_dmem(mem_data_loaded_value),
		.halt(led[0]),
		.trace_completed_pc(trace_completed_pc),
		.trace_completed_insn(trace_completed_insn),
		.trace_completed_cycle_status(trace_completed_cycle_status)
	);
endmodule