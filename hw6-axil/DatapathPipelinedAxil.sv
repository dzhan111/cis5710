`timescale 1ns / 1ns
`define REG_SIZE 31:0
`define INSN_SIZE 31:0
`define OPCODE_SIZE 6:0
`define ADDR_WIDTH 32
`define DATA_WIDTH 32
`ifndef DIVIDER_STAGES
`define DIVIDER_STAGES 8
`endif
`ifndef SYNTHESIS
`include "../hw3-singlecycle/RvDisassembler.sv"
`endif
`include "../hw2b-cla/CarryLookaheadAdder.sv"
`include "../hw3-singlecycle/cycle_status.sv"
`include "../hw4-multicycle/DividerUnsignedPipelined.sv"
`include "EasyAxilMemory.sv"

module Disasm #(PREFIX = "D") (input wire [31:0] insn, output wire [(8*32)-1:0] disasm);
`ifndef RISCV_FORMAL
`ifndef SYNTHESIS
  string disasm_string;
  always_comb disasm_string = rv_disasm(insn);
  genvar i;
  for (i = 3; i < 32; i = i + 1) begin : gen_disasm
    assign disasm[((i+1-3)*8)-1-:8] = disasm_string[31-i];
  end
  assign disasm[255-:8] = PREFIX;
  assign disasm[247-:8] = ":";
  assign disasm[239-:8] = " ";
`endif
`endif
endmodule

typedef struct packed { logic [`REG_SIZE] pc; cycle_status_e cycle_status; logic valid; } stage_going_t;
typedef struct packed { logic [`REG_SIZE] pc; logic [`INSN_SIZE] insn; cycle_status_e cycle_status; logic valid; } stage_decode_t;
typedef struct packed {
  logic [`REG_SIZE] pc; logic [`INSN_SIZE] insn; cycle_status_e cycle_status; logic valid;
  logic [6:0] funct7; logic [4:0] rs2, rs1; logic [2:0] funct3; logic [4:0] rd; logic [`OPCODE_SIZE] opcode;
  logic [`REG_SIZE] rs1_data, rs2_data;
} stage_execute_t;
typedef struct packed {
  logic [`REG_SIZE] pc; logic [`INSN_SIZE] insn; cycle_status_e cycle_status; logic valid;
  logic we; logic [4:0] rd; logic [`REG_SIZE] rd_data; logic is_load; logic [2:0] load_funct3; logic [1:0] byte_off;
} stage_memory_t;
typedef struct packed {
  logic [`REG_SIZE] pc; logic [`INSN_SIZE] insn; cycle_status_e cycle_status; logic valid;
  logic we; logic [4:0] rd; logic [`REG_SIZE] rd_data;
} stage_writeback_t;

module RegFile(
  input logic [4:0] rd, input logic [`REG_SIZE] rd_data, input logic [4:0] rs1, output logic [`REG_SIZE] rs1_data,
  input logic [4:0] rs2, output logic [`REG_SIZE] rs2_data, input logic clk, input logic we, input logic rst
);
  localparam int NumRegs = 32;
  logic [`REG_SIZE] regs[NumRegs];
  integer i;
  always_comb begin
    rs1_data = (rs1 == 0) ? 0 : regs[rs1];
    rs2_data = (rs2 == 0) ? 0 : regs[rs2];
  end
  always_ff @(posedge clk) begin
    if (rst) for (i = 0; i < NumRegs; i = i + 1) regs[i] <= 0;
    else begin if (we && rd != 0) regs[rd] <= rd_data; regs[0] <= 0; end
  end
endmodule

module DatapathPipelinedAxil (
  input wire clk, input wire rst, axil_if.manager imem, axil_if.manager dmem, output logic halt,
  output logic [`REG_SIZE] trace_completed_pc, output logic [`INSN_SIZE] trace_completed_insn, output cycle_status_e trace_completed_cycle_status
);
  localparam bit [`OPCODE_SIZE] OpcodeLoad=7'b00_000_11, OpcodeStore=7'b01_000_11, OpcodeBranch=7'b11_000_11, OpcodeJalr=7'b11_001_11,
    OpcodeMiscMem=7'b00_011_11, OpcodeJal=7'b11_011_11, OpcodeRegImm=7'b00_100_11, OpcodeRegReg=7'b01_100_11, OpcodeEnviron=7'b11_100_11,
    OpcodeAuipc=7'b00_101_11, OpcodeLui=7'b01_101_11;
  logic [`REG_SIZE] cycles_current;
  always_ff @(posedge clk) if (rst) cycles_current <= 0; else cycles_current <= cycles_current + 1;

  logic [`REG_SIZE] f_pc_current, f_pc_branch_decision;
  cycle_status_e f_cycle_status;
  stage_going_t g_state;
  stage_decode_t d_state;
  stage_execute_t x_state;
  stage_memory_t m_state;
  stage_writeback_t w_state;
  logic x_branch_taken, x_we, pipeline_stall;
  logic [`REG_SIZE] x_wdata;
  logic [`REG_SIZE] x_rs1_data, x_rs2_data;
  logic x_illegal_insn;
  logic [`REG_SIZE] x_load_addr_raw, x_store_addr_raw;
  logic [1:0] x_store_byte_off;
  logic [63:0] x_mulh_ss, x_mulh_su, x_mulh_uu;

  wire [6:0] d_funct7 = d_state.insn[31:25];
  wire [4:0] d_rs2 = d_state.insn[24:20], d_rs1 = d_state.insn[19:15], d_rd = d_state.insn[11:7];
  wire [2:0] d_funct3 = d_state.insn[14:12];
  wire [`OPCODE_SIZE] d_opcode = d_state.insn[6:0];
  wire d_reads_rs1 = (d_opcode != OpcodeLui && d_opcode != OpcodeAuipc && d_opcode != OpcodeJal);
  wire d_reads_rs2 = (d_opcode == OpcodeRegReg || d_opcode == OpcodeBranch || d_opcode == OpcodeStore);
  wire d_is_div = d_state.valid && d_opcode == OpcodeRegReg && d_state.insn[31:25] == 7'd1 && (d_funct3[2]);
  wire x_is_load = x_state.valid && x_state.opcode == OpcodeLoad;
  wire load_use_stall = x_is_load && x_state.rd != 0 && ((d_reads_rs1 && d_rs1 == x_state.rd) || (d_reads_rs2 && d_rs2 == x_state.rd));

  localparam int DVS = `DIVIDER_STAGES;
  logic [4:0] div_pipe_rd[0:DVS-1]; logic div_pipe_valid[0:DVS-1], div_pipe_is_div[0:DVS-1], div_pipe_is_divu[0:DVS-1], div_pipe_is_rem[0:DVS-1], div_pipe_is_remu[0:DVS-1], div_pipe_vinsn[0:DVS-1];
  logic [`REG_SIZE] div_pipe_rs1[0:DVS-1], div_pipe_rs2[0:DVS-1], div_pipe_pc[0:DVS-1];
  logic [`INSN_SIZE] div_pipe_insn[0:DVS-1];
  cycle_status_e div_pipe_cstat[0:DVS-1];
  logic div_stall_raw, div_nondiv_stall, div_any_inflight;
  always_comb begin
    div_stall_raw = 0; div_any_inflight = 0;
    for (int i = 0; i < DVS; i++) if (div_pipe_valid[i]) div_any_inflight = 1;
    if (d_reads_rs1 && d_rs1 != 0) for (int i = 0; i < (d_is_div ? DVS : DVS-1); i++) if (div_pipe_valid[i] && div_pipe_rd[i] == d_rs1) div_stall_raw = 1;
    if (d_reads_rs2 && d_rs2 != 0) for (int i = 0; i < (d_is_div ? DVS : DVS-1); i++) if (div_pipe_valid[i] && div_pipe_rd[i] == d_rs2) div_stall_raw = 1;
    div_nondiv_stall = div_any_inflight && !div_pipe_valid[DVS-1] && d_state.valid && !d_is_div;
  end
  wire x_is_div = x_state.valid && x_state.opcode == OpcodeRegReg && x_state.insn[31:25] == 7'd1 && x_state.insn[14:12][2];
  wire div_mem_conflict = div_pipe_valid[DVS-1] && x_state.valid && !x_is_div;
  assign pipeline_stall = load_use_stall || div_stall_raw || div_nondiv_stall || div_mem_conflict;

  // AXI-Lite instruction memory.
  assign imem.ARPROT = 3'b000;
  assign imem.ARADDR = {f_pc_current[31:2], 2'b00};
  assign imem.ARVALID = !rst && !pipeline_stall && !x_branch_taken;
  assign imem.RREADY = !rst && !pipeline_stall;
  assign imem.AWVALID = 1'b0; assign imem.AWADDR = 32'd0; assign imem.AWPROT = 3'd0;
  assign imem.WVALID = 1'b0; assign imem.WDATA = 32'd0; assign imem.WSTRB = 4'd0; assign imem.BREADY = 1'b1;
  wire g_req_fire = imem.ARVALID && imem.ARREADY;
  wire g_rsp_fire = imem.RVALID && imem.RREADY;

  wire [`REG_SIZE] d_rs1_raw, d_rs2_raw; logic [`REG_SIZE] d_rs1_data, d_rs2_data;
  RegFile rf(.rd(w_state.rd), .rd_data(w_state.rd_data), .rs1(d_rs1), .rs1_data(d_rs1_raw), .rs2(d_rs2), .rs2_data(d_rs2_raw), .clk(clk), .we(w_state.valid && w_state.we), .rst(rst));
  wire d_fwd_ex = x_state.valid && x_we && x_state.rd != 0 && x_state.opcode != OpcodeLoad;
  wire d_fwd_mem = m_state.valid && m_state.we && m_state.rd != 0 && !m_state.is_load;
  always_comb begin
    d_rs1_data = d_rs1_raw; d_rs2_data = d_rs2_raw;
    if (d_rs1 != 0) begin if (d_fwd_ex && x_state.rd == d_rs1) d_rs1_data = x_wdata; else if (d_fwd_mem && m_state.rd == d_rs1) d_rs1_data = m_state.rd_data; else if (w_state.valid && w_state.we && w_state.rd == d_rs1) d_rs1_data = w_state.rd_data; end
    if (d_rs2 != 0) begin if (d_fwd_ex && x_state.rd == d_rs2) d_rs2_data = x_wdata; else if (d_fwd_mem && m_state.rd == d_rs2) d_rs2_data = m_state.rd_data; else if (w_state.valid && w_state.we && w_state.rd == d_rs2) d_rs2_data = w_state.rd_data; end
  end

  logic [`REG_SIZE] x_cla_a, x_cla_b; logic x_cla_cin; wire [`REG_SIZE] x_cla_sum;
  CarryLookaheadAdder cla32(.a(x_cla_a), .b(x_cla_b), .cin(x_cla_cin), .sum(x_cla_sum));
  wire [11:0] x_imm_i = x_state.insn[31:20], x_imm_s = {x_state.funct7, x_state.rd}; wire [4:0] x_shamt = x_state.insn[24:20];
  wire [12:0] x_imm_b = {x_state.funct7[6], x_state.rd[0], x_state.funct7[5:0], x_state.rd[4:1], 1'b0};
  wire [20:0] x_imm_j = {x_state.insn[31], x_state.insn[19:12], x_state.insn[20], x_state.insn[30:21], 1'b0};
  wire [`REG_SIZE] x_imm_u = {x_state.insn[31:12], 12'b0}, x_imm_i_sext={{20{x_imm_i[11]}},x_imm_i}, x_imm_s_sext={{20{x_imm_s[11]}},x_imm_s}, x_imm_b_sext={{19{x_imm_b[12]}},x_imm_b}, x_imm_j_sext={{11{x_imm_j[20]}},x_imm_j};
  always_comb begin
    x_load_addr_raw = x_rs1_data + x_imm_i_sext;
    x_store_addr_raw = x_rs1_data + x_imm_s_sext;
    x_store_byte_off = x_store_addr_raw[1:0];
    x_mulh_ss = $signed({{32{x_rs1_data[31]}}, x_rs1_data}) * $signed({{32{x_rs2_data[31]}}, x_rs2_data});
    x_mulh_su = $signed({{32{x_rs1_data[31]}}, x_rs1_data}) * $signed({32'b0, x_rs2_data});
    x_mulh_uu = {32'b0, x_rs1_data} * {32'b0, x_rs2_data};
  end
  always_comb begin
    x_rs1_data = x_state.rs1_data; x_rs2_data = x_state.rs2_data;
    if (m_state.valid && m_state.we && !m_state.is_load && m_state.rd != 0 && m_state.rd == x_state.rs1) x_rs1_data = m_state.rd_data; else if (w_state.valid && w_state.we && w_state.rd != 0 && w_state.rd == x_state.rs1) x_rs1_data = w_state.rd_data;
    if (m_state.valid && m_state.we && !m_state.is_load && m_state.rd != 0 && m_state.rd == x_state.rs2) x_rs2_data = m_state.rd_data; else if (w_state.valid && w_state.we && w_state.rd != 0 && w_state.rd == x_state.rs2) x_rs2_data = w_state.rd_data;
  end

  logic dmem_issue_load, dmem_issue_store; logic [`REG_SIZE] dmem_addr, dmem_wdata_x; logic [3:0] dmem_wstrb_x;
  always_comb begin
    x_we = 0; x_wdata = 0; x_illegal_insn = 0; x_branch_taken = 0; f_pc_branch_decision = x_state.pc + 4;
    dmem_issue_load = 0; dmem_issue_store = 0; dmem_addr = 0; dmem_wdata_x = 0; dmem_wstrb_x = 0;
    x_cla_a = 0; x_cla_b = 0; x_cla_cin = 0;
    unique case (x_state.opcode)
      OpcodeLui: begin x_we = 1; x_wdata = x_imm_u; end
      OpcodeAuipc: begin x_we = 1; x_wdata = x_state.pc + x_imm_u; end
      OpcodeRegImm: begin
        x_we = 1;
        if (x_state.funct3 == 3'b000) begin x_cla_a=x_rs1_data; x_cla_b=x_imm_i_sext; x_wdata=x_cla_sum; end
        else if (x_state.funct3 == 3'b010) x_wdata = ($signed(x_rs1_data) < $signed(x_imm_i_sext)) ? 32'd1 : 32'd0;
        else if (x_state.funct3 == 3'b011) x_wdata = (x_rs1_data < x_imm_i_sext) ? 32'd1 : 32'd0;
        else if (x_state.funct3 == 3'b100) x_wdata = x_rs1_data ^ x_imm_i_sext;
        else if (x_state.funct3 == 3'b110) x_wdata = x_rs1_data | x_imm_i_sext;
        else if (x_state.funct3 == 3'b111) x_wdata = x_rs1_data & x_imm_i_sext;
        else if (x_state.funct3 == 3'b001 && x_state.funct7 == 0) x_wdata = x_rs1_data << x_shamt;
        else if (x_state.funct3 == 3'b101 && x_state.funct7 == 0) x_wdata = x_rs1_data >> x_shamt;
        else if (x_state.funct3 == 3'b101 && x_state.funct7 == 7'b0100000) x_wdata = $signed(x_rs1_data) >>> x_shamt;
        else x_illegal_insn = 1;
      end
      OpcodeRegReg: begin
        x_we = 1;
        if (x_state.funct7 == 0 && x_state.funct3 == 3'b000) begin x_cla_a=x_rs1_data; x_cla_b=x_rs2_data; x_wdata=x_cla_sum; end
        else if (x_state.funct7 == 7'b0100000 && x_state.funct3 == 3'b000) begin x_cla_a=x_rs1_data; x_cla_b=~x_rs2_data; x_cla_cin=1; x_wdata=x_cla_sum; end
        else if (x_state.funct7 == 0 && x_state.funct3 == 3'b001) x_wdata = x_rs1_data << x_rs2_data[4:0];
        else if (x_state.funct7 == 0 && x_state.funct3 == 3'b010) x_wdata = ($signed(x_rs1_data) < $signed(x_rs2_data)) ? 32'd1 : 32'd0;
        else if (x_state.funct7 == 0 && x_state.funct3 == 3'b011) x_wdata = (x_rs1_data < x_rs2_data) ? 32'd1 : 32'd0;
        else if (x_state.funct7 == 0 && x_state.funct3 == 3'b100) x_wdata = x_rs1_data ^ x_rs2_data;
        else if (x_state.funct7 == 0 && x_state.funct3 == 3'b101) x_wdata = x_rs1_data >> x_rs2_data[4:0];
        else if (x_state.funct7 == 7'b0100000 && x_state.funct3 == 3'b101) x_wdata = $signed(x_rs1_data) >>> x_rs2_data[4:0];
        else if (x_state.funct7 == 0 && x_state.funct3 == 3'b110) x_wdata = x_rs1_data | x_rs2_data;
        else if (x_state.funct7 == 0 && x_state.funct3 == 3'b111) x_wdata = x_rs1_data & x_rs2_data;
        else if (x_state.funct7 == 7'd1 && x_state.funct3 == 3'b000) x_wdata = x_rs1_data * x_rs2_data;
        else if (x_state.funct7 == 7'd1 && x_state.funct3 == 3'b001) x_wdata = x_mulh_ss[63:32];
        else if (x_state.funct7 == 7'd1 && x_state.funct3 == 3'b010) x_wdata = x_mulh_su[63:32];
        else if (x_state.funct7 == 7'd1 && x_state.funct3 == 3'b011) x_wdata = x_mulh_uu[63:32];
        else if (x_state.funct7 == 7'd1 && x_state.funct3[2]) x_we = 0;
        else x_illegal_insn = 1;
      end
      OpcodeLoad: begin x_we = 1; x_wdata = {x_load_addr_raw[31:2], 2'b00}; dmem_issue_load = x_state.valid; dmem_addr = {x_load_addr_raw[31:2], 2'b00}; end
      OpcodeStore: begin dmem_issue_store = x_state.valid; dmem_addr = {x_store_addr_raw[31:2], 2'b00};
        case (x_state.funct3)
          3'b000: begin dmem_wstrb_x = 4'b0001 << x_store_byte_off; dmem_wdata_x = {24'd0, x_rs2_data[7:0]} << (x_store_byte_off * 8); end
          3'b001: begin dmem_wstrb_x = 4'b0011 << x_store_byte_off; dmem_wdata_x = {16'd0, x_rs2_data[15:0]} << (x_store_byte_off * 8); end
          3'b010: begin dmem_wstrb_x = 4'b1111; dmem_wdata_x = x_rs2_data; end
          default: x_illegal_insn = 1;
        endcase
      end
      OpcodeJal: begin x_we = 1; x_wdata = x_state.pc + 4; x_branch_taken = 1; f_pc_branch_decision = x_state.pc + x_imm_j_sext; end
      OpcodeJalr: begin x_we = 1; x_wdata = x_state.pc + 4; x_branch_taken = 1; f_pc_branch_decision = (x_rs1_data + x_imm_i_sext) & ~32'd1; end
      OpcodeBranch: begin
        if (x_state.funct3 == 3'b000) x_branch_taken = (x_rs1_data == x_rs2_data);
        else if (x_state.funct3 == 3'b001) x_branch_taken = (x_rs1_data != x_rs2_data);
        else if (x_state.funct3 == 3'b100) x_branch_taken = ($signed(x_rs1_data) < $signed(x_rs2_data));
        else if (x_state.funct3 == 3'b101) x_branch_taken = ($signed(x_rs1_data) >= $signed(x_rs2_data));
        else if (x_state.funct3 == 3'b110) x_branch_taken = (x_rs1_data < x_rs2_data);
        else if (x_state.funct3 == 3'b111) x_branch_taken = (x_rs1_data >= x_rs2_data);
        else x_illegal_insn = 1;
        if (x_branch_taken && !x_illegal_insn) f_pc_branch_decision = x_state.pc + x_imm_b_sext;
      end
      OpcodeEnviron: begin end
      OpcodeMiscMem: begin end
      default: x_illegal_insn = 1;
    endcase
  end

  assign dmem.ARPROT = 3'b000; assign dmem.ARADDR = dmem_addr; assign dmem.ARVALID = dmem_issue_load; assign dmem.RREADY = 1'b1;
  assign dmem.AWPROT = 3'b000; assign dmem.AWADDR = dmem_addr; assign dmem.AWVALID = dmem_issue_store;
  assign dmem.WDATA = dmem_wdata_x; assign dmem.WSTRB = dmem_wstrb_x; assign dmem.WVALID = dmem_issue_store; assign dmem.BREADY = 1'b1;

  wire [`REG_SIZE] d_div_rs1_abs = d_rs1_data[31] ? (~d_rs1_data + 1) : d_rs1_data;
  wire [`REG_SIZE] d_div_rs2_abs = d_rs2_data[31] ? (~d_rs2_data + 1) : d_rs2_data;
  wire div_issue = d_is_div && !pipeline_stall && !x_branch_taken && !rst;
  logic [`REG_SIZE] div_i_dividend, div_i_divisor;
  always_comb begin
    div_i_dividend = 0; div_i_divisor = 1;
    if (div_issue) begin
      if (d_funct3 == 3'b100 || d_funct3 == 3'b110) begin div_i_dividend = d_div_rs1_abs; div_i_divisor = d_div_rs2_abs; end
      else begin div_i_dividend = d_rs1_data; div_i_divisor = d_rs2_data; end
    end
  end
  wire [`REG_SIZE] div_o_q, div_o_r;
  DividerUnsignedPipelined divider(.clk(clk), .rst(rst), .stall(1'b0), .i_dividend(div_i_dividend), .i_divisor(div_i_divisor), .o_quotient(div_o_q), .o_remainder(div_o_r));
  logic [`REG_SIZE] div_q_r, div_r_r;
  always_ff @(posedge clk) if (rst) begin div_q_r <= 0; div_r_r <= 0; end else begin div_q_r <= div_o_q; div_r_r <= div_o_r; end
  logic [`REG_SIZE] div_wdata;
  always_comb begin
    div_wdata = 0;
    if (div_pipe_valid[DVS-1]) begin
      if (div_pipe_is_div[DVS-1]) begin if (div_pipe_rs2[DVS-1] == 0) div_wdata = 32'hffff_ffff; else if (div_pipe_rs1[DVS-1] == 32'h8000_0000 && div_pipe_rs2[DVS-1] == 32'hffff_ffff) div_wdata = 32'h8000_0000; else if (div_pipe_rs1[DVS-1][31] ^ div_pipe_rs2[DVS-1][31]) div_wdata = ~div_q_r + 1; else div_wdata = div_q_r; end
      else if (div_pipe_is_divu[DVS-1]) begin if (div_pipe_rs2[DVS-1] == 0) div_wdata = 32'hffff_ffff; else div_wdata = div_q_r; end
      else if (div_pipe_is_rem[DVS-1]) begin if (div_pipe_rs2[DVS-1] == 0) div_wdata = div_pipe_rs1[DVS-1]; else if (div_pipe_rs1[DVS-1] == 32'h8000_0000 && div_pipe_rs2[DVS-1] == 32'hffff_ffff) div_wdata = 0; else if (div_pipe_rs1[DVS-1][31]) div_wdata = ~div_r_r + 1; else div_wdata = div_r_r; end
      else begin if (div_pipe_rs2[DVS-1] == 0) div_wdata = div_pipe_rs1[DVS-1]; else div_wdata = div_r_r; end
    end
  end

  wire [`REG_SIZE] m_load_data_q = dmem.RDATA;
  always_ff @(posedge clk) begin
    if (rst) begin
      f_pc_current <= 0; f_cycle_status <= CYCLE_NO_STALL;
      g_state <= '{pc:0, cycle_status:CYCLE_RESET, valid:0};
      d_state <= '{pc:0, insn:0, cycle_status:CYCLE_RESET, valid:0};
      x_state <= '{pc:0, insn:0, cycle_status:CYCLE_RESET, valid:0, funct7:0, rs2:0, rs1:0, funct3:0, rd:0, opcode:0, rs1_data:0, rs2_data:0};
      m_state <= '{pc:0, insn:0, cycle_status:CYCLE_RESET, valid:0, we:0, rd:0, rd_data:0, is_load:0, load_funct3:0, byte_off:0};
      w_state <= '{pc:0, insn:0, cycle_status:CYCLE_RESET, valid:0, we:0, rd:0, rd_data:0};
      for (int i=0; i<DVS; i++) begin div_pipe_rd[i]<=0; div_pipe_valid[i]<=0; div_pipe_rs1[i]<=0; div_pipe_rs2[i]<=0; div_pipe_is_div[i]<=0; div_pipe_is_divu[i]<=0; div_pipe_is_rem[i]<=0; div_pipe_is_remu[i]<=0; div_pipe_pc[i]<=0; div_pipe_insn[i]<=0; div_pipe_vinsn[i]<=0; div_pipe_cstat[i]<=CYCLE_NO_STALL; end
    end else begin
      if (x_branch_taken) f_pc_current <= f_pc_branch_decision; else if (!pipeline_stall) f_pc_current <= f_pc_current + 4;
      f_cycle_status <= CYCLE_NO_STALL;
      if (x_branch_taken) g_state <= '{pc:0, cycle_status:CYCLE_TAKEN_BRANCH, valid:0}; else if (g_req_fire) g_state <= '{pc:f_pc_current, cycle_status:f_cycle_status, valid:1};
      if (x_branch_taken) d_state <= '{pc:0, insn:0, cycle_status:CYCLE_TAKEN_BRANCH, valid:0};
      else if (!pipeline_stall && g_rsp_fire) d_state <= '{pc:g_state.pc, insn:imem.RDATA, cycle_status:g_state.cycle_status, valid:g_state.valid};
      else if (pipeline_stall) d_state <= d_state;

      for (int i=DVS-1; i>0; i--) begin div_pipe_rd[i]<=div_pipe_rd[i-1]; div_pipe_valid[i]<=div_pipe_valid[i-1]; div_pipe_rs1[i]<=div_pipe_rs1[i-1]; div_pipe_rs2[i]<=div_pipe_rs2[i-1]; div_pipe_is_div[i]<=div_pipe_is_div[i-1]; div_pipe_is_divu[i]<=div_pipe_is_divu[i-1]; div_pipe_is_rem[i]<=div_pipe_is_rem[i-1]; div_pipe_is_remu[i]<=div_pipe_is_remu[i-1]; div_pipe_pc[i]<=div_pipe_pc[i-1]; div_pipe_insn[i]<=div_pipe_insn[i-1]; div_pipe_vinsn[i]<=div_pipe_vinsn[i-1]; div_pipe_cstat[i]<=div_pipe_cstat[i-1]; end
      if (d_is_div && !pipeline_stall && !x_branch_taken) begin
        div_pipe_valid[0]<=1; div_pipe_rd[0]<=d_rd; div_pipe_rs1[0]<=d_rs1_data; div_pipe_rs2[0]<=d_rs2_data; div_pipe_pc[0]<=d_state.pc; div_pipe_insn[0]<=d_state.insn; div_pipe_vinsn[0]<=d_state.valid; div_pipe_cstat[0]<=d_state.cycle_status;
        div_pipe_is_div[0]<=d_funct3==3'b100; div_pipe_is_divu[0]<=d_funct3==3'b101; div_pipe_is_rem[0]<=d_funct3==3'b110; div_pipe_is_remu[0]<=d_funct3==3'b111;
      end else begin
        div_pipe_valid[0]<=0; div_pipe_rd[0]<=0; div_pipe_rs1[0]<=0; div_pipe_rs2[0]<=0; div_pipe_pc[0]<=0; div_pipe_insn[0]<=0; div_pipe_vinsn[0]<=0; div_pipe_cstat[0]<=CYCLE_NO_STALL; div_pipe_is_div[0]<=0; div_pipe_is_divu[0]<=0; div_pipe_is_rem[0]<=0; div_pipe_is_remu[0]<=0;
      end

      if (x_branch_taken) x_state <= '{pc:0, insn:0, cycle_status:CYCLE_TAKEN_BRANCH, valid:0, funct7:0, rs2:0, rs1:0, funct3:0, rd:0, opcode:0, rs1_data:0, rs2_data:0};
      else if (load_use_stall || div_stall_raw || div_nondiv_stall) x_state <= '{pc:0, insn:0, cycle_status:(load_use_stall ? CYCLE_LOAD2USE : CYCLE_DIV), valid:0, funct7:0, rs2:0, rs1:0, funct3:0, rd:0, opcode:0, rs1_data:0, rs2_data:0};
      else if (!div_mem_conflict) x_state <= '{pc:d_state.pc, insn:d_state.insn, cycle_status:d_state.cycle_status, valid:d_state.valid, funct7:d_funct7, rs2:d_rs2, rs1:d_rs1, funct3:d_funct3, rd:d_rd, opcode:d_opcode, rs1_data:d_rs1_data, rs2_data:d_rs2_data};

      if (div_pipe_valid[DVS-1]) m_state <= '{pc:div_pipe_pc[DVS-1], insn:div_pipe_insn[DVS-1], cycle_status:div_pipe_cstat[DVS-1], valid:div_pipe_vinsn[DVS-1], we:(div_pipe_rd[DVS-1]!=0), rd:div_pipe_rd[DVS-1], rd_data:div_wdata, is_load:0, load_funct3:0, byte_off:0};
      else if (x_is_div) m_state <= '{pc:0, insn:0, cycle_status:CYCLE_DIV, valid:0, we:0, rd:0, rd_data:0, is_load:0, load_funct3:0, byte_off:0};
      else m_state <= '{pc:x_state.pc, insn:x_state.insn, cycle_status:x_state.cycle_status, valid:x_state.valid, we:x_we, rd:x_state.rd, rd_data:x_wdata, is_load:(x_state.opcode==OpcodeLoad), load_funct3:x_state.funct3, byte_off:x_load_addr_raw[1:0]};

      w_state <= '{pc:m_state.pc, insn:m_state.insn, cycle_status:m_state.cycle_status, valid:m_state.valid, we:m_state.we, rd:m_state.rd, rd_data:m_state.rd_data};
      if (m_state.valid && m_state.is_load) begin
        case (m_state.load_funct3)
          3'b000: w_state.rd_data <= {{24{m_load_data_q[m_state.byte_off*8+7]}}, m_load_data_q[m_state.byte_off*8 +: 8]};
          3'b001: w_state.rd_data <= {{16{m_load_data_q[m_state.byte_off*8+15]}}, m_load_data_q[m_state.byte_off*8 +: 16]};
          3'b010: w_state.rd_data <= m_load_data_q;
          3'b100: w_state.rd_data <= {24'd0, m_load_data_q[m_state.byte_off*8 +: 8]};
          3'b101: w_state.rd_data <= {16'd0, m_load_data_q[m_state.byte_off*8 +: 16]};
          default: ;
        endcase
      end
    end
  end

  wire [255:0] g_disasm, d_disasm, x_disasm, m_disasm, w_disasm;
  Disasm #(.PREFIX("G")) dis0(.insn(imem.RDATA), .disasm(g_disasm));
  Disasm #(.PREFIX("D")) dis1(.insn(d_state.insn), .disasm(d_disasm));
  Disasm #(.PREFIX("X")) dis2(.insn(x_state.insn), .disasm(x_disasm));
  Disasm #(.PREFIX("M")) dis3(.insn(m_state.insn), .disasm(m_disasm));
  Disasm #(.PREFIX("W")) dis4(.insn(w_state.insn), .disasm(w_disasm));

  assign halt = w_state.valid && (w_state.insn == 32'h0000_0073);
  assign trace_completed_pc = w_state.valid ? w_state.pc : 32'd0;
  assign trace_completed_insn = w_state.valid ? w_state.insn : 32'd0;
  assign trace_completed_cycle_status = w_state.cycle_status;
endmodule

module Processor (
    input wire clk, input wire rst, output logic halt, output wire [`REG_SIZE] trace_completed_pc,
    output wire [`INSN_SIZE] trace_completed_insn, output cycle_status_e trace_completed_cycle_status
);
  wire [(8*32)-1:0] test_case;
  axil_if axil_mem_ro (); axil_if axil_mem_rw ();
  EasyAxilMemory #(.OPT_SKIDBUFFER(1), .OPT_LOWPOWER(0), .NUM_WORDS(8192)) memory (
      .ACLK(clk), .ARESETn(~rst), .port_ro(axil_mem_ro.subord), .port_rw(axil_mem_rw.subord)
  );
  DatapathPipelinedAxil datapath (
      .clk(clk), .rst(rst), .imem(axil_mem_ro.manager), .dmem(axil_mem_rw.manager), .halt(halt),
      .trace_completed_pc(trace_completed_pc), .trace_completed_insn(trace_completed_insn),
      .trace_completed_cycle_status(trace_completed_cycle_status)
  );
endmodule
