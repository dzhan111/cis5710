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
module SystemDemo (
	external_clk_25MHz,
	btn,
	led
);
	reg _sv2v_0;
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output reg [7:0] led;
	reg [31:0] ab;
	wire [15:0] a;
	wire [15:0] b;
	wire [31:0] expected_sum;
	wire [31:0] actual_sum;
	wire rst = ~btn[0];
	reg error;
	wire [2:0] chunk = ab[31:29];
	reg [7:0] completed;
	CarryLookaheadAdder cla_inst(
		.a(a),
		.b(b),
		.cin(1'b0),
		.sum(actual_sum)
	);
	always @(*) begin
		if (_sv2v_0)
			;
		a = ab[31:16];
		b = ab[15:0];
		expected_sum = a + b;
	end
	always @(posedge external_clk_25MHz)
		if (rst) begin
			ab <= 32'd0;
			error <= 1'b0;
			completed <= 8'd0;
		end
		else if (!error) begin
			if (actual_sum != expected_sum)
				error <= 1'b1;
			else begin
				ab <= ab + 1;
				if (ab[28:0] == 29'h1fffffff)
					completed[chunk] <= 1'b1;
			end
		end
	reg [23:0] blink;
	always @(posedge external_clk_25MHz)
		if (rst)
			blink <= 0;
		else
			blink <= blink + 1;
	always @(*) begin
		if (_sv2v_0)
			;
		if (error)
			led = completed;
		else
			led = completed | ({7'd0, blink[23]} << chunk);
	end
	initial _sv2v_0 = 0;
endmodule