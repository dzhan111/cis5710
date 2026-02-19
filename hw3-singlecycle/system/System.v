module MyClockGen (
	input_clk_25MHz,
	clk_proc,
	clk_mem,
	locked
);
	input input_clk_25MHz;
	output wire clk_proc;
	output wire clk_mem;
	output wire locked;
	wire clkfb;
	(* FREQUENCY_PIN_CLKI = "25" *) (* FREQUENCY_PIN_CLKOP = "4.16667" *) (* FREQUENCY_PIN_CLKOS = "4.01003" *) (* ICP_CURRENT = "12" *) (* LPF_RESISTOR = "8" *) (* MFG_ENABLE_FILTEROPAMP = "1" *) (* MFG_GMCREF_SEL = "2" *) EHXPLLL #(
		.PLLRST_ENA("DISABLED"),
		.INTFB_WAKE("DISABLED"),
		.STDBY_ENABLE("DISABLED"),
		.DPHASE_SOURCE("DISABLED"),
		.OUTDIVIDER_MUXA("DIVA"),
		.OUTDIVIDER_MUXB("DIVB"),
		.OUTDIVIDER_MUXC("DIVC"),
		.OUTDIVIDER_MUXD("DIVD"),
		.CLKI_DIV(6),
		.CLKOP_ENABLE("ENABLED"),
		.CLKOP_DIV(128),
		.CLKOP_CPHASE(64),
		.CLKOP_FPHASE(0),
		.CLKOS_ENABLE("ENABLED"),
		.CLKOS_DIV(133),
		.CLKOS_CPHASE(97),
		.CLKOS_FPHASE(2),
		.FEEDBK_PATH("INT_OP"),
		.CLKFB_DIV(1)
	) pll_i(
		.RST(1'b0),
		.STDBY(1'b0),
		.CLKI(input_clk_25MHz),
		.CLKOP(clk_proc),
		.CLKOS(clk_mem),
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
module DividerUnsigned (
	i_dividend,
	i_divisor,
	o_remainder,
	o_quotient
);
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	wire [31:0] dividend_pipe [0:32];
	wire [31:0] remainder_pipe [0:32];
	wire [31:0] quotient_pipe [0:32];
	assign dividend_pipe[0] = i_dividend;
	assign remainder_pipe[0] = 32'b00000000000000000000000000000000;
	assign quotient_pipe[0] = 32'b00000000000000000000000000000000;
	genvar _gv_k_1;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 32; _gv_k_1 = _gv_k_1 + 1) begin : gen_div
			localparam k = _gv_k_1;
			DividerOneIter u_iter(
				.i_dividend(dividend_pipe[k]),
				.i_divisor(i_divisor),
				.i_remainder(remainder_pipe[k]),
				.i_quotient(quotient_pipe[k]),
				.o_dividend(dividend_pipe[k + 1]),
				.o_remainder(remainder_pipe[k + 1]),
				.o_quotient(quotient_pipe[k + 1])
			);
		end
	endgenerate
	assign o_remainder = remainder_pipe[32];
	assign o_quotient = quotient_pipe[32];
endmodule
module DividerOneIter (
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
	wire [31:0] rem_shift = (i_remainder << 1) | {31'b0000000000000000000000000000000, i_dividend[31]};
	wire take = $unsigned(rem_shift) >= $unsigned(i_divisor);
	assign o_quotient = (i_quotient << 1) | {31'b0000000000000000000000000000000, take};
	assign o_remainder = (take ? rem_shift - i_divisor : rem_shift);
	assign o_dividend = i_dividend << 1;
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
	always @(*) begin
		if (_sv2v_0)
			;
		rs1_data = regs[rs1];
		rs2_data = regs[rs2];
	end
	always @(posedge clk)
		if (rst) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NumRegs; i = i + 1)
				regs[i] <= 32'b00000000000000000000000000000000;
		end
		else if (we && (rd != 5'd0))
			regs[rd] <= rd_data;
	initial _sv2v_0 = 0;
endmodule
module DatapathSingleCycle (
	clk,
	rst,
	halt,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem,
	trace_completed_pc,
	trace_completed_insn,
	trace_completed_cycle_status
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	output reg halt;
	output wire [31:0] pc_to_imem;
	input wire [31:0] insn_from_imem;
	output reg [31:0] addr_to_dmem;
	input wire [31:0] load_data_from_dmem;
	output reg [31:0] store_data_to_dmem;
	output reg [3:0] store_we_to_dmem;
	output reg [31:0] trace_completed_pc;
	output reg [31:0] trace_completed_insn;
	output reg [31:0] trace_completed_cycle_status;
	wire [6:0] insn_funct7 = insn_from_imem[31:25];
	wire [4:0] insn_rs2 = insn_from_imem[24:20];
	wire [4:0] insn_rs1 = insn_from_imem[19:15];
	wire [2:0] insn_funct3 = insn_from_imem[14:12];
	wire [4:0] insn_rd = insn_from_imem[11:7];
	wire [6:0] insn_opcode = insn_from_imem[6:0];
	wire [11:0] imm_i = insn_from_imem[31:20];
	wire [4:0] imm_shamt = insn_from_imem[24:20];
	wire [11:0] imm_s;
	assign imm_s[11:5] = insn_funct7;
	assign imm_s[4:0] = insn_rd;
	wire [12:0] imm_b;
	assign {imm_b[12], imm_b[10:5]} = insn_funct7;
	assign {imm_b[4:1], imm_b[11]} = insn_rd;
	assign imm_b[0] = 1'b0;
	wire [20:0] imm_j;
	assign {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} = {insn_from_imem[31:12], 1'b0};
	wire [31:0] imm_i_sext = {{20 {imm_i[11]}}, imm_i};
	wire [31:0] imm_s_sext = {{20 {imm_s[11]}}, imm_s};
	wire [31:0] imm_b_sext = {{19 {imm_b[12]}}, imm_b};
	wire [31:0] imm_j_sext = {{11 {imm_j[20]}}, imm_j};
	localparam [6:0] OpLoad = 7'b0000011;
	localparam [6:0] OpStore = 7'b0100011;
	localparam [6:0] OpBranch = 7'b1100011;
	localparam [6:0] OpJalr = 7'b1100111;
	localparam [6:0] OpMiscMem = 7'b0001111;
	localparam [6:0] OpJal = 7'b1101111;
	localparam [6:0] OpRegImm = 7'b0010011;
	localparam [6:0] OpRegReg = 7'b0110011;
	localparam [6:0] OpEnviron = 7'b1110011;
	localparam [6:0] OpAuipc = 7'b0010111;
	localparam [6:0] OpLui = 7'b0110111;
	wire f7_0 = insn_funct7 == 7'd0;
	wire f7_sub = insn_funct7 == 7'b0100000;
	wire f7_mext = insn_funct7 == 7'd1;
	wire insn_beq = (insn_opcode == OpBranch) & (insn_funct3 == 3'b000);
	wire insn_bne = (insn_opcode == OpBranch) & (insn_funct3 == 3'b001);
	wire insn_blt = (insn_opcode == OpBranch) & (insn_funct3 == 3'b100);
	wire insn_bge = (insn_opcode == OpBranch) & (insn_funct3 == 3'b101);
	wire insn_bltu = (insn_opcode == OpBranch) & (insn_funct3 == 3'b110);
	wire insn_bgeu = (insn_opcode == OpBranch) & (insn_funct3 == 3'b111);
	wire insn_lb = (insn_opcode == OpLoad) & (insn_funct3 == 3'b000);
	wire insn_lh = (insn_opcode == OpLoad) & (insn_funct3 == 3'b001);
	wire insn_lw = (insn_opcode == OpLoad) & (insn_funct3 == 3'b010);
	wire insn_lbu = (insn_opcode == OpLoad) & (insn_funct3 == 3'b100);
	wire insn_lhu = (insn_opcode == OpLoad) & (insn_funct3 == 3'b101);
	wire insn_sb = (insn_opcode == OpStore) & (insn_funct3 == 3'b000);
	wire insn_sh = (insn_opcode == OpStore) & (insn_funct3 == 3'b001);
	wire insn_sw = (insn_opcode == OpStore) & (insn_funct3 == 3'b010);
	wire insn_addi = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b000);
	wire insn_slti = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b010);
	wire insn_sltiu = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b011);
	wire insn_xori = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b100);
	wire insn_ori = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b110);
	wire insn_andi = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b111);
	wire insn_slli = ((insn_opcode == OpRegImm) & (insn_funct3 == 3'b001)) & f7_0;
	wire insn_srli = ((insn_opcode == OpRegImm) & (insn_funct3 == 3'b101)) & f7_0;
	wire insn_srai = ((insn_opcode == OpRegImm) & (insn_funct3 == 3'b101)) & f7_sub;
	wire insn_add = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b000)) & f7_0;
	wire insn_sub = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b000)) & f7_sub;
	wire insn_sll = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b001)) & f7_0;
	wire insn_slt = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b010)) & f7_0;
	wire insn_sltu = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b011)) & f7_0;
	wire insn_xor = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b100)) & f7_0;
	wire insn_srl = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b101)) & f7_0;
	wire insn_sra = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b101)) & f7_sub;
	wire insn_or = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b110)) & f7_0;
	wire insn_and = ((insn_opcode == OpRegReg) & (insn_funct3 == 3'b111)) & f7_0;
	wire insn_mul = ((insn_opcode == OpRegReg) & f7_mext) & (insn_funct3 == 3'b000);
	wire insn_mulh = ((insn_opcode == OpRegReg) & f7_mext) & (insn_funct3 == 3'b001);
	wire insn_mulhsu = ((insn_opcode == OpRegReg) & f7_mext) & (insn_funct3 == 3'b010);
	wire insn_mulhu = ((insn_opcode == OpRegReg) & f7_mext) & (insn_funct3 == 3'b011);
	wire insn_div = ((insn_opcode == OpRegReg) & f7_mext) & (insn_funct3 == 3'b100);
	wire insn_divu = ((insn_opcode == OpRegReg) & f7_mext) & (insn_funct3 == 3'b101);
	wire insn_rem = ((insn_opcode == OpRegReg) & f7_mext) & (insn_funct3 == 3'b110);
	wire insn_remu = ((insn_opcode == OpRegReg) & f7_mext) & (insn_funct3 == 3'b111);
	wire insn_lui = insn_opcode == OpLui;
	wire insn_auipc = insn_opcode == OpAuipc;
	wire insn_jal = insn_opcode == OpJal;
	wire insn_jalr = insn_opcode == OpJalr;
	wire insn_ecall = (insn_opcode == OpEnviron) & (insn_from_imem[31:7] == 25'd0);
	wire insn_fence = insn_opcode == OpMiscMem;
	reg [31:0] pcNext;
	reg [31:0] pcCurrent;
	always @(posedge clk) pcCurrent <= (rst ? 32'd0 : pcNext);
	assign pc_to_imem = pcCurrent;
	reg [31:0] cycles_current;
	reg [31:0] num_insns_current;
	always @(posedge clk)
		if (rst) begin
			cycles_current <= 0;
			num_insns_current <= 0;
		end
		else begin
			cycles_current <= cycles_current + 1;
			num_insns_current <= num_insns_current + 1;
		end
	wire [31:0] rs1_data;
	wire [31:0] rs2_data;
	reg rf_we;
	reg [31:0] rd_data;
	RegFile rf(
		.clk(clk),
		.rst(rst),
		.we(rf_we),
		.rd(insn_rd),
		.rd_data(rd_data),
		.rs1(insn_rs1),
		.rs2(insn_rs2),
		.rs1_data(rs1_data),
		.rs2_data(rs2_data)
	);
	reg [31:0] cla_a;
	reg [31:0] cla_b;
	reg cla_cin;
	wire [31:0] cla_sum;
	CarryLookaheadAdder cla(
		.a(cla_a),
		.b(cla_b),
		.cin(cla_cin),
		.sum(cla_sum)
	);
	reg [32:0] mul_op_a;
	reg [32:0] mul_op_b;
	wire [65:0] mul_result;
	assign mul_result = $signed(mul_op_a) * $signed(mul_op_b);
	reg [31:0] div_dividend;
	reg [31:0] div_divisor;
	wire [31:0] div_quotient;
	wire [31:0] div_remainder;
	wire [31:0] rs1_abs = (rs1_data[31] ? ~rs1_data + 1 : rs1_data);
	wire [31:0] rs2_abs = (rs2_data[31] ? ~rs2_data + 1 : rs2_data);
	DividerUnsigned u_div(
		.i_dividend(div_dividend),
		.i_divisor(div_divisor),
		.o_quotient(div_quotient),
		.o_remainder(div_remainder)
	);
	reg illegal_insn;
	reg [31:0] addr;
	always @(*) begin
		if (_sv2v_0)
			;
		illegal_insn = 1'b0;
		halt = 1'b0;
		rf_we = 1'b0;
		rd_data = 32'd0;
		pcNext = pcCurrent + 32'd4;
		addr_to_dmem = 32'd0;
		store_data_to_dmem = 32'd0;
		store_we_to_dmem = 4'b0000;
		addr = 32'd0;
		cla_a = 32'd0;
		cla_b = 32'd0;
		cla_cin = 1'b0;
		mul_op_a = {1'b0, rs1_data};
		mul_op_b = {1'b0, rs2_data};
		div_dividend = rs1_data;
		div_divisor = rs2_data;
		trace_completed_pc = pcCurrent;
		trace_completed_insn = insn_from_imem;
		trace_completed_cycle_status = 32'd1;
		(* full_case, parallel_case *)
		case (insn_opcode)
			OpLui: begin
				rf_we = 1'b1;
				rd_data = {insn_from_imem[31:12], 12'b000000000000};
			end
			OpAuipc: begin
				rf_we = 1'b1;
				rd_data = pcCurrent + {insn_from_imem[31:12], 12'b000000000000};
			end
			OpRegImm: begin
				rf_we = 1'b1;
				(* full_case, parallel_case *)
				case (1'b1)
					insn_addi: begin
						cla_a = rs1_data;
						cla_b = imm_i_sext;
						cla_cin = 1'b0;
						rd_data = cla_sum;
					end
					insn_slti: rd_data = ($signed(rs1_data) < $signed(imm_i_sext) ? 32'b00000000000000000000000000000001 : 32'b00000000000000000000000000000000);
					insn_sltiu: rd_data = (rs1_data < imm_i_sext ? 32'b00000000000000000000000000000001 : 32'b00000000000000000000000000000000);
					insn_xori: rd_data = rs1_data ^ imm_i_sext;
					insn_ori: rd_data = rs1_data | imm_i_sext;
					insn_andi: rd_data = rs1_data & imm_i_sext;
					insn_slli: rd_data = rs1_data << imm_shamt;
					insn_srli: rd_data = rs1_data >> imm_shamt;
					insn_srai: rd_data = $signed(rs1_data) >>> imm_shamt;
					default: begin
						rf_we = 1'b0;
						illegal_insn = 1'b1;
					end
				endcase
			end
			OpRegReg: begin
				rf_we = 1'b1;
				(* full_case, parallel_case *)
				case (1'b1)
					insn_add: begin
						cla_a = rs1_data;
						cla_b = rs2_data;
						cla_cin = 1'b0;
						rd_data = cla_sum;
					end
					insn_sub: begin
						cla_a = rs1_data;
						cla_b = ~rs2_data;
						cla_cin = 1'b1;
						rd_data = cla_sum;
					end
					insn_sll: rd_data = rs1_data << rs2_data[4:0];
					insn_slt: rd_data = ($signed(rs1_data) < $signed(rs2_data) ? 32'b00000000000000000000000000000001 : 32'b00000000000000000000000000000000);
					insn_sltu: rd_data = (rs1_data < rs2_data ? 32'b00000000000000000000000000000001 : 32'b00000000000000000000000000000000);
					insn_xor: rd_data = rs1_data ^ rs2_data;
					insn_srl: rd_data = rs1_data >> rs2_data[4:0];
					insn_sra: rd_data = $signed(rs1_data) >>> rs2_data[4:0];
					insn_or: rd_data = rs1_data | rs2_data;
					insn_and: rd_data = rs1_data & rs2_data;
					insn_mul: begin
						mul_op_a = {1'b0, rs1_data};
						mul_op_b = {1'b0, rs2_data};
						rd_data = mul_result[31:0];
					end
					insn_mulh: begin
						mul_op_a = {rs1_data[31], rs1_data};
						mul_op_b = {rs2_data[31], rs2_data};
						rd_data = mul_result[63:32];
					end
					insn_mulhsu: begin
						mul_op_a = {rs1_data[31], rs1_data};
						mul_op_b = {1'b0, rs2_data};
						rd_data = mul_result[63:32];
					end
					insn_mulhu: begin
						mul_op_a = {1'b0, rs1_data};
						mul_op_b = {1'b0, rs2_data};
						rd_data = mul_result[63:32];
					end
					insn_div: begin
						div_dividend = rs1_abs;
						div_divisor = rs2_abs;
						if (rs2_data == 32'b00000000000000000000000000000000)
							rd_data = 32'hffffffff;
						else if ((rs1_data == 32'h80000000) && (rs2_data == 32'hffffffff))
							rd_data = 32'h80000000;
						else
							rd_data = (rs1_data[31] ^ rs2_data[31] ? ~div_quotient + 1 : div_quotient);
					end
					insn_divu: begin
						div_dividend = rs1_data;
						div_divisor = rs2_data;
						rd_data = (rs2_data == 32'b00000000000000000000000000000000 ? 32'hffffffff : div_quotient);
					end
					insn_rem: begin
						div_dividend = rs1_abs;
						div_divisor = rs2_abs;
						if (rs2_data == 32'b00000000000000000000000000000000)
							rd_data = rs1_data;
						else if ((rs1_data == 32'h80000000) && (rs2_data == 32'hffffffff))
							rd_data = 32'b00000000000000000000000000000000;
						else
							rd_data = (rs1_data[31] ? ~div_remainder + 1 : div_remainder);
					end
					insn_remu: begin
						div_dividend = rs1_data;
						div_divisor = rs2_data;
						rd_data = (rs2_data == 32'b00000000000000000000000000000000 ? rs1_data : div_remainder);
					end
					default: begin
						illegal_insn = 1'b1;
						rf_we = 1'b0;
					end
				endcase
			end
			OpBranch: begin : sv2v_autoblock_1
				reg take;
				take = 1'b0;
				(* full_case, parallel_case *)
				case (1'b1)
					insn_beq: take = rs1_data == rs2_data;
					insn_bne: take = rs1_data != rs2_data;
					insn_blt: take = $signed(rs1_data) < $signed(rs2_data);
					insn_bge: take = $signed(rs1_data) >= $signed(rs2_data);
					insn_bltu: take = rs1_data < rs2_data;
					insn_bgeu: take = rs1_data >= rs2_data;
					default: illegal_insn = 1'b1;
				endcase
				if (take)
					pcNext = pcCurrent + imm_b_sext;
			end
			OpJal: begin
				rf_we = 1'b1;
				rd_data = pcCurrent + 32'd4;
				pcNext = pcCurrent + imm_j_sext;
			end
			OpJalr: begin
				rf_we = 1'b1;
				rd_data = pcCurrent + 32'd4;
				pcNext = (rs1_data + imm_i_sext) & ~32'd1;
			end
			OpLoad: begin
				rf_we = 1'b1;
				addr = rs1_data + imm_i_sext;
				addr_to_dmem = {addr[31:2], 2'b00};
				(* full_case, parallel_case *)
				case (1'b1)
					insn_lb:
						(* full_case, parallel_case *)
						case (addr[1:0])
							2'b00: rd_data = {{24 {load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};
							2'b01: rd_data = {{24 {load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
							2'b10: rd_data = {{24 {load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
							2'b11: rd_data = {{24 {load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
						endcase
					insn_lh:
						(* full_case, parallel_case *)
						case (addr[1])
							1'b0: rd_data = {{16 {load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
							1'b1: rd_data = {{16 {load_data_from_dmem[31]}}, load_data_from_dmem[31:16]};
						endcase
					insn_lw: rd_data = load_data_from_dmem;
					insn_lbu:
						(* full_case, parallel_case *)
						case (addr[1:0])
							2'b00: rd_data = {24'b000000000000000000000000, load_data_from_dmem[7:0]};
							2'b01: rd_data = {24'b000000000000000000000000, load_data_from_dmem[15:8]};
							2'b10: rd_data = {24'b000000000000000000000000, load_data_from_dmem[23:16]};
							2'b11: rd_data = {24'b000000000000000000000000, load_data_from_dmem[31:24]};
						endcase
					insn_lhu:
						(* full_case, parallel_case *)
						case (addr[1])
							1'b0: rd_data = {16'b0000000000000000, load_data_from_dmem[15:0]};
							1'b1: rd_data = {16'b0000000000000000, load_data_from_dmem[31:16]};
						endcase
					default: begin
						rf_we = 1'b0;
						illegal_insn = 1'b1;
					end
				endcase
			end
			OpStore: begin
				addr = rs1_data + imm_s_sext;
				addr_to_dmem = {addr[31:2], 2'b00};
				(* full_case, parallel_case *)
				case (1'b1)
					insn_sb:
						(* full_case, parallel_case *)
						case (addr[1:0])
							2'b00: begin
								store_data_to_dmem = {24'b000000000000000000000000, rs2_data[7:0]};
								store_we_to_dmem = 4'b0001;
							end
							2'b01: begin
								store_data_to_dmem = {16'b0000000000000000, rs2_data[7:0], 8'b00000000};
								store_we_to_dmem = 4'b0010;
							end
							2'b10: begin
								store_data_to_dmem = {8'b00000000, rs2_data[7:0], 16'b0000000000000000};
								store_we_to_dmem = 4'b0100;
							end
							2'b11: begin
								store_data_to_dmem = {rs2_data[7:0], 24'b000000000000000000000000};
								store_we_to_dmem = 4'b1000;
							end
						endcase
					insn_sh:
						(* full_case, parallel_case *)
						case (addr[1])
							1'b0: begin
								store_data_to_dmem = {16'b0000000000000000, rs2_data[15:0]};
								store_we_to_dmem = 4'b0011;
							end
							1'b1: begin
								store_data_to_dmem = {rs2_data[15:0], 16'b0000000000000000};
								store_we_to_dmem = 4'b1100;
							end
						endcase
					insn_sw: begin
						store_data_to_dmem = rs2_data;
						store_we_to_dmem = 4'b1111;
					end
					default: illegal_insn = 1'b1;
				endcase
			end
			OpEnviron:
				if (insn_ecall)
					halt = 1'b1;
				else
					illegal_insn = 1'b1;
			OpMiscMem:
				if (!insn_fence)
					illegal_insn = 1'b1;
			default: illegal_insn = 1'b1;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module MemorySingleCycle (
	rst,
	clock_mem,
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
	input wire clock_mem;
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
	always @(posedge clock_mem)
		if (!rst)
			insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
	always @(negedge clock_mem)
		if (!rst) begin
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
module SystemResourceCheck (
	external_clk_25MHz,
	btn,
	led
);
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output wire [7:0] led;
	wire clk_proc;
	wire clk_mem;
	wire clk_locked;
	MyClockGen clock_gen(
		.input_clk_25MHz(external_clk_25MHz),
		.clk_proc(clk_proc),
		.clk_mem(clk_mem),
		.locked(clk_locked)
	);
	wire [31:0] pc_to_imem;
	wire [31:0] insn_from_imem;
	wire [31:0] mem_data_addr;
	wire [31:0] mem_data_loaded_value;
	wire [31:0] mem_data_to_write;
	wire [3:0] mem_data_we;
	MemorySingleCycle #(.NUM_WORDS(128)) memory(
		.rst(!clk_locked),
		.clock_mem(clk_mem),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.load_data_from_dmem(mem_data_loaded_value),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we)
	);
	DatapathSingleCycle datapath(
		.clk(clk_proc),
		.rst(!clk_locked),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we),
		.load_data_from_dmem(mem_data_loaded_value),
		.halt(led[0])
	);
endmodule