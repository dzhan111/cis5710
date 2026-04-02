`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31:0

// insns are 32 bits in RV32IM
`define INSN_SIZE 31:0

// RV opcodes are 7 bits
`define OPCODE_SIZE 6:0

`ifndef DIVIDER_STAGES
`define DIVIDER_STAGES 8
`endif

`ifndef SYNTHESIS
`include "../hw3-singlecycle/RvDisassembler.sv"
`endif
`include "../hw2b-cla/CarryLookaheadAdder.sv"
`include "../hw4-multicycle/DividerUnsignedPipelined.sv"

module Disasm #(
    byte PREFIX = "D"
) (
    input wire [31:0] insn,
    output wire [(8*32)-1:0] disasm
);
  // synthesis translate_off
  string disasm_string;
  always_comb begin
    disasm_string = rv_disasm(insn);
  end
  genvar i;
  for (i = 3; i < 32; i = i + 1) begin : gen_disasm
    assign disasm[((i+1-3)*8)-1-:8] = disasm_string[31-i];
  end
  assign disasm[255-:8] = PREFIX;
  assign disasm[247-:8] = ":";
  assign disasm[239-:8] = " ";
  // synthesis translate_on
endmodule

module RegFile (
    input logic [4:0] rd,
    input logic [`REG_SIZE] rd_data,
    input logic [4:0] rs1,
    output logic [`REG_SIZE] rs1_data,
    input logic [4:0] rs2,
    output logic [`REG_SIZE] rs2_data,

    input logic clk,
    input logic we,
    input logic rst
);
  localparam int NumRegs = 32;
  logic [`REG_SIZE] regs[NumRegs];

  always_ff @(posedge clk) begin
    if (rst) begin
      for (integer i = 0; i < NumRegs; i = i + 1) begin
        regs[i] <= 0;
      end
    end else begin
      if (we && (rd != 0)) begin
        regs[rd] <= rd_data;
      end
    end
  end

  assign rs1_data = (rs1 == 0) ? 32'd0 :
                    (we && rd != 0 && rd == rs1) ? rd_data :
                    regs[rs1];

  assign rs2_data = (rs2 == 0) ? 32'd0 :
                    (we && rd != 0 && rd == rs2) ? rd_data :
                    regs[rs2];
endmodule

typedef enum {
  CYCLE_INVALID = 0,
  CYCLE_RESET = 1,
  CYCLE_NO_STALL = 2,
  CYCLE_TAKEN_BRANCH = 4,
  CYCLE_LOAD2USE = 8,
  CYCLE_DIV2USE = 16,
  CYCLE_FENCEI = 32
} cycle_status_e;

/** state at the start of Decode stage */
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
} stage_decode_t;

// decoded instruction type
typedef struct packed {
  logic [`INSN_SIZE] insn;
  logic [4:0] rs1;
  logic [4:0] rs2;
  logic [4:0] rd;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [`OPCODE_SIZE] opcode;

  logic [11:0] imm_i;
  logic [`REG_SIZE] imm_i_sext;
  logic [11:0] imm_s;
  logic [`REG_SIZE] imm_s_sext;
  logic [12:0] imm_b;
  logic [`REG_SIZE] imm_b_sext;
  logic [20:0] imm_j;
  logic [`REG_SIZE] imm_j_sext;

  logic bypassable;
} insn_t;

typedef struct packed {
  insn_t insn;
  logic [`REG_SIZE] pc;
  cycle_status_e cycle_status;

  logic [`REG_SIZE] rs1_data;
  logic [`REG_SIZE] rs2_data;
} stage_execute_t;

typedef struct packed {
  insn_t insn;
  logic [`REG_SIZE] pc;
  cycle_status_e cycle_status;

  logic [`REG_SIZE] result;
  logic [`REG_SIZE] rs2_passthrough;
} stage_memory_t;

typedef struct packed {
  insn_t insn;
  logic [`REG_SIZE] pc;
  cycle_status_e cycle_status;

  logic [`REG_SIZE] result;
  logic [`REG_SIZE] data;
} stage_writeback_t;

typedef struct packed {
  logic valid;
  logic [4:0] rd;
  logic is_rem;
  logic negate_quot;
  logic negate_rem;
  logic special_case;
  logic [`REG_SIZE] special_result;
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn_bits;
  cycle_status_e cycle_status;
} div_meta_t;

module DatapathPipelined (
    input wire clk,
    input wire rst,
    output logic [`REG_SIZE] pc_to_imem,
    input wire [`INSN_SIZE] insn_from_imem,
    output logic [`REG_SIZE] addr_to_dmem,
    input wire [`REG_SIZE] load_data_from_dmem,
    output logic [`REG_SIZE] store_data_to_dmem,
    output logic [3:0] store_we_to_dmem,

    output logic halt,

    output logic [`REG_SIZE] trace_completed_pc,
    output logic [`INSN_SIZE] trace_completed_insn,
    output cycle_status_e trace_completed_cycle_status
);

  localparam bit [`OPCODE_SIZE] OpcodeLoad = 7'b00_000_11;
  localparam bit [`OPCODE_SIZE] OpcodeStore = 7'b01_000_11;
  localparam bit [`OPCODE_SIZE] OpcodeBranch = 7'b11_000_11;
  localparam bit [`OPCODE_SIZE] OpcodeJalr = 7'b11_001_11;
  localparam bit [`OPCODE_SIZE] OpcodeMiscMem = 7'b00_011_11;
  localparam bit [`OPCODE_SIZE] OpcodeJal = 7'b11_011_11;

  localparam bit [`OPCODE_SIZE] OpcodeRegImm = 7'b00_100_11;
  localparam bit [`OPCODE_SIZE] OpcodeRegReg = 7'b01_100_11;
  localparam bit [`OPCODE_SIZE] OpcodeEnviron = 7'b11_100_11;

  localparam bit [`OPCODE_SIZE] OpcodeAuipc = 7'b00_101_11;
  localparam bit [`OPCODE_SIZE] OpcodeLui = 7'b01_101_11;

  localparam insn_t BUBBLE_INSN = '{
    insn: 0,
    rs1: 0,
    rs2: 0,
    rd: 0,
    funct3: 0,
    funct7: 0,
    opcode: 0,
    imm_i: 0,
    imm_i_sext: 0,
    imm_s: 0,
    imm_s_sext: 0,
    imm_b: 0,
    imm_b_sext: 0,
    imm_j: 0,
    imm_j_sext: 0,
    bypassable: 0
  };

  logic [`REG_SIZE] cycles_current;
  always_ff @(posedge clk) begin
    if (rst) begin
      cycles_current <= 0;
    end else begin
      cycles_current <= cycles_current + 1;
    end
  end

  /***************/
  /* FETCH STAGE */
  /***************/
  logic [`REG_SIZE] f_pc_current;
  wire [`REG_SIZE] f_insn;
  cycle_status_e f_cycle_status;

  /****************/
  /* DECODE STAGE */
  /****************/
  stage_decode_t decode_state;

  /*****************/
  /* EXECUTE STAGE */
  /*****************/
  stage_execute_t execute_state;

  /****************/
  /* MEMORY STAGE */
  /****************/
  stage_memory_t memory_state;

  /*******************/
  /* WRITEBACK STAGE */
  /*******************/
  stage_writeback_t writeback_state;

  // divider side-pipeline metadata
  div_meta_t div_pipe[`DIVIDER_STAGES];
  logic x_div_launch;
  div_meta_t x_div_meta;
  logic div_done_valid;
  logic [`REG_SIZE] div_done_result;
  logic div_pipe_conflict;

  assign div_done_valid = div_pipe[`DIVIDER_STAGES-1].valid;
  assign div_pipe_conflict = div_done_valid;

  always_ff @(posedge clk) begin
    if (rst) begin
      f_pc_current <= 32'd0;
      f_cycle_status <= CYCLE_NO_STALL;
    end else begin
      f_cycle_status <= CYCLE_NO_STALL;
      if (x_branchTaken) begin
        f_pc_current <= x_branchTarget;
      end else if (load2use_hazard) begin
        f_pc_current <= f_pc_current;
      end else if (div_pipe_conflict) begin
        f_pc_current <= f_pc_current;
      end else begin
        f_pc_current <= f_pc_current + 4;
      end
    end
  end

  assign pc_to_imem = f_pc_current;
  assign f_insn = insn_from_imem;

  always_ff @(posedge clk) begin
    if (rst) begin
      decode_state <= '{
        pc: 0,
        insn: 0,
        cycle_status: CYCLE_RESET
      };
    end else if (x_branchTaken) begin
      decode_state <= '{
        pc: 0,
        insn: 0,
        cycle_status: CYCLE_TAKEN_BRANCH
      };
    end else if (load2use_hazard) begin
      decode_state <= decode_state;
    end else if (div_pipe_conflict) begin
      decode_state <= decode_state;
    end else begin
      decode_state <= '{
        pc: f_pc_current,
        insn: f_insn,
        cycle_status: f_cycle_status
      };
    end
  end

  wire [6:0] d_insn_funct7;
  wire [4:0] d_insn_rs2;
  wire [4:0] d_insn_rs1;
  wire [2:0] d_insn_funct3;
  wire [4:0] d_insn_rd;
  wire [`OPCODE_SIZE] d_insn_opcode;
  wire [11:0] d_imm_i;
  wire [11:0] d_imm_s;
  wire [12:0] d_imm_b;
  wire [20:0] d_imm_j;

  assign {d_insn_funct7, d_insn_rs2, d_insn_rs1, d_insn_funct3, d_insn_rd, d_insn_opcode} = decode_state.insn;
  assign d_imm_i = decode_state.insn[31:20];
  assign d_imm_s = {decode_state.insn[31:25], decode_state.insn[11:7]};
  assign d_imm_b = {decode_state.insn[31], decode_state.insn[7], decode_state.insn[30:25], decode_state.insn[11:8], 1'b0};
  assign d_imm_j = {decode_state.insn[31], decode_state.insn[19:12], decode_state.insn[20], decode_state.insn[30:20]};

  wire [`REG_SIZE] d_imm_i_sext = {{20{d_imm_i[11]}}, d_imm_i[11:0]};
  wire [`REG_SIZE] d_imm_s_sext = {{20{d_imm_s[11]}}, d_imm_s[11:0]};
  wire [`REG_SIZE] d_imm_b_sext = {{19{d_imm_b[12]}}, d_imm_b[12:0]};
  wire [`REG_SIZE] d_imm_j_sext = {{11{d_imm_j[20]}}, d_imm_j[20:0]};

  wire d_bypassable;
  assign d_bypassable = d_insn_rd != 0 &&
                        d_insn_opcode != OpcodeBranch &&
                        d_insn_opcode != OpcodeMiscMem &&
                        d_insn_opcode != OpcodeEnviron;

  insn_t d_decoded_insn;
  assign d_decoded_insn = '{
    insn: decode_state.insn,
    rs1: d_insn_rs1,
    rs2: d_insn_rs2,
    rd: d_insn_rd,
    funct3: d_insn_funct3,
    funct7: d_insn_funct7,
    opcode: d_insn_opcode,
    imm_i: d_imm_i,
    imm_i_sext: d_imm_i_sext,
    imm_s: d_imm_s,
    imm_s_sext: d_imm_s_sext,
    imm_b: d_imm_b,
    imm_b_sext: d_imm_b_sext,
    imm_j: d_imm_j,
    imm_j_sext: d_imm_j_sext,
    bypassable: d_bypassable
  };

  wire [4:0] rf_rd;
  wire [`REG_SIZE] rf_rd_data;
  wire [4:0] rf_rs1 = d_insn_rs1;
  wire [`REG_SIZE] rf_rs1_data;
  wire [4:0] rf_rs2 = d_insn_rs2;
  wire [`REG_SIZE] rf_rs2_data;
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

  logic [`REG_SIZE] d_rs1_data;
  logic [`REG_SIZE] d_rs2_data;
  always_comb begin
    if (d_insn_rs1 == writeback_state.insn.rd && writeback_state.insn.bypassable) begin
      d_rs1_data = w_value;
    end else begin
      d_rs1_data = rf_rs1_data;
    end

    if (d_insn_rs2 == writeback_state.insn.rd && d_insn_rs2 != 0) begin
      d_rs2_data = w_value;
    end else begin
      d_rs2_data = rf_rs2_data;
    end
  end

  logic load2use_hazard;
  always_comb begin
    load2use_hazard = 1'b0;

    if (execute_state.insn.opcode == OpcodeLoad &&
        execute_state.insn.rd != 5'd0) begin
      if ((d_insn_rs1 == execute_state.insn.rd) ||
          (d_insn_rs2 == execute_state.insn.rd)) begin
        load2use_hazard = 1'b1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      execute_state <= '{
        insn: BUBBLE_INSN,
        pc: 0,
        cycle_status: CYCLE_RESET,
        rs1_data: 0,
        rs2_data: 0
      };
    end else if (x_branchTaken) begin
      execute_state <= '{
        insn: BUBBLE_INSN,
        pc: 0,
        cycle_status: CYCLE_TAKEN_BRANCH,
        rs1_data: 0,
        rs2_data: 0
      };
    end else if (load2use_hazard) begin
      execute_state <= '{
        insn: BUBBLE_INSN,
        pc: 0,
        cycle_status: CYCLE_LOAD2USE,
        rs1_data: 0,
        rs2_data: 0
      };
    end else if (div_pipe_conflict) begin
      execute_state <= execute_state;
    end else begin
      execute_state <= '{
        insn: d_decoded_insn,
        pc: decode_state.pc,
        cycle_status: decode_state.cycle_status,
        rs1_data: d_rs1_data,
        rs2_data: d_rs2_data
      };
    end
  end

  logic [`REG_SIZE] x_rs1_data;
  logic [`REG_SIZE] x_rs2_data;
  always_comb begin
    if (execute_state.insn.rs1 == memory_state.insn.rd && memory_state.insn.bypassable) begin
      x_rs1_data = memory_state.result;
    end else if (execute_state.insn.rs1 == writeback_state.insn.rd && writeback_state.insn.bypassable) begin
      x_rs1_data = w_value;
    end else begin
      x_rs1_data = execute_state.rs1_data;
    end

    if (execute_state.insn.rs2 == memory_state.insn.rd && memory_state.insn.bypassable) begin
      x_rs2_data = memory_state.result;
    end else if (execute_state.insn.rs2 == writeback_state.insn.rd && writeback_state.insn.bypassable) begin
      x_rs2_data = w_value;
    end else begin
      x_rs2_data = execute_state.rs2_data;
    end
  end

  logic [`REG_SIZE] x_a, x_b, x_sum, x_rem, x_quo;
  logic x_cin;
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

  logic [`REG_SIZE] x_result;
  logic x_branchConditional;
  logic [63:0] x_mulfull;
  logic x_illegal_insn;
  logic [`REG_SIZE] x_branchTarget;
  logic x_branchTaken;

  always_comb begin
    x_illegal_insn = 1'b0;
    x_branchConditional = 1'b0;
    x_cin = 1'b0;
    x_result = 32'b0;
    x_a = 32'b0;
    x_b = 32'b1;
    x_mulfull = 64'b0;
    x_branchTaken = 1'b0;
    x_branchTarget = 32'b0;
    x_div_launch = 1'b0;

    case (execute_state.insn.opcode)
      OpcodeLui: begin
        x_result = {12'b0, execute_state.insn.funct7, execute_state.insn.rs2, execute_state.insn.rs1, execute_state.insn.funct3} << 12;
      end

      OpcodeAuipc: begin
        x_result = execute_state.pc + ({12'b0, execute_state.insn.funct7, execute_state.insn.rs2, execute_state.insn.rs1, execute_state.insn.funct3} << 12);
      end

      OpcodeRegImm: begin
        case (execute_state.insn.funct3)
          3'b000: begin
            x_a = x_rs1_data;
            x_b = execute_state.insn.imm_i_sext;
            x_result = x_sum;
          end
          3'b010: begin
            x_result = (signed'(x_rs1_data) < signed'(execute_state.insn.imm_i_sext)) ? 1 : 0;
          end
          3'b011: begin
            x_result = (x_rs1_data < execute_state.insn.imm_i_sext) ? 1 : 0;
          end
          3'b100: begin
            x_result = x_rs1_data ^ execute_state.insn.imm_i_sext;
          end
          3'b110: begin
            x_result = x_rs1_data | execute_state.insn.imm_i_sext;
          end
          3'b111: begin
            x_result = x_rs1_data & execute_state.insn.imm_i_sext;
          end
          3'b001: begin
            if (execute_state.insn.funct7 == 7'b0) begin
              x_result = x_rs1_data << execute_state.insn.imm_i[4:0];
            end else begin
              x_illegal_insn = 1'b1;
            end
          end
          3'b101: begin
            if (execute_state.insn.funct7 == 7'h0) begin
              x_result = x_rs1_data >> execute_state.insn.imm_i[4:0];
            end else if (execute_state.insn.funct7 == 7'h20) begin
              x_result = signed'(x_rs1_data) >>> execute_state.insn.imm_i[4:0];
            end else begin
              x_illegal_insn = 1'b1;
            end
          end
        endcase
      end

      OpcodeRegReg: begin
        case (execute_state.insn.funct3)
          3'b000: begin
            if (execute_state.insn.funct7 == 7'h0) begin
              x_a = x_rs1_data;
              x_b = x_rs2_data;
              x_result = x_sum;
            end else if (execute_state.insn.funct7 == 7'h20) begin
              x_a = x_rs1_data;
              x_b = ~x_rs2_data;
              x_cin = 1'b1;
              x_result = x_sum;
            end else if (execute_state.insn.funct7 == 7'h01) begin
              x_mulfull = (x_rs1_data * x_rs2_data);
              x_result = x_mulfull[31:0];
            end else begin
              x_illegal_insn = 1'b1;
            end
          end

          3'b001: begin
            if (execute_state.insn.funct7 == 7'h0) begin
              x_result = x_rs1_data << (x_rs2_data[4:0]);
            end else if (execute_state.insn.funct7 == 7'h01) begin
              x_mulfull = (signed'(x_rs1_data) * signed'(x_rs2_data));
              x_result = x_mulfull[63:32];
            end else begin
              x_illegal_insn = 1'b1;
            end
          end

          3'b010: begin
            if (execute_state.insn.funct7 == 7'h0) begin
              x_result = (signed'(x_rs1_data) < signed'(x_rs2_data)) ? 1 : 0;
            end else if (execute_state.insn.funct7 == 7'h01) begin
              x_mulfull = ({{32{x_rs1_data[31]}}, x_rs1_data} * {32'b0, x_rs2_data});
              x_result = x_mulfull[63:32];
            end else begin
              x_illegal_insn = 1'b1;
            end
          end

          3'b011: begin
            if (execute_state.insn.funct7 == 7'h0) begin
              x_result = (x_rs1_data < x_rs2_data) ? 1 : 0;
            end else if (execute_state.insn.funct7 == 7'h01) begin
              x_mulfull = (unsigned'(x_rs1_data) * unsigned'(x_rs2_data));
              x_result = x_mulfull[63:32];
            end else begin
              x_illegal_insn = 1'b1;
            end
          end

          3'b100: begin
            if (execute_state.insn.funct7 == 7'h0) begin
              x_result = x_rs1_data ^ x_rs2_data;
            end else if (execute_state.insn.funct7 == 7'h01) begin
              x_div_launch = 1'b1;
              if (x_rs2_data == 32'b0) begin
                x_a = 32'd0;
                x_b = 32'd1;
              end else begin
                x_a = x_rs1_data[31] ? ((~x_rs1_data) + 1) : x_rs1_data;
                x_b = x_rs2_data[31] ? ((~x_rs2_data) + 1) : x_rs2_data;
              end
            end else begin
              x_illegal_insn = 1'b1;
            end
          end

          3'b101: begin
            if (execute_state.insn.funct7 == 7'h0) begin
              x_result = x_rs1_data >> (x_rs2_data[4:0]);
            end else if (execute_state.insn.funct7 == 7'h20) begin
              x_result = signed'(x_rs1_data) >>> (x_rs2_data[4:0]);
            end else if (execute_state.insn.funct7 == 7'h01) begin
              x_div_launch = 1'b1;
              x_a = x_rs1_data;
              x_b = (x_rs2_data == 0) ? 32'd1 : x_rs2_data;
            end else begin
              x_illegal_insn = 1'b1;
            end
          end

          3'b110: begin
            if (execute_state.insn.funct7 == 7'h0) begin
              x_result = x_rs1_data | x_rs2_data;
            end else if (execute_state.insn.funct7 == 7'h01) begin
              x_div_launch = 1'b1;
              if (x_rs2_data == 32'b0) begin
                x_a = 32'd0;
                x_b = 32'd1;
              end else begin
                x_a = x_rs1_data[31] ? ((~x_rs1_data) + 1) : x_rs1_data;
                x_b = x_rs2_data[31] ? ((~x_rs2_data) + 1) : x_rs2_data;
              end
            end else begin
              x_illegal_insn = 1'b1;
            end
          end

          3'b111: begin
            if (execute_state.insn.funct7 == 7'h0) begin
              x_result = x_rs1_data & x_rs2_data;
            end else if (execute_state.insn.funct7 == 7'h01) begin
              x_div_launch = 1'b1;
              x_a = x_rs1_data;
              x_b = (x_rs2_data == 0) ? 32'd1 : x_rs2_data;
            end else begin
              x_illegal_insn = 1'b1;
            end
          end
        endcase
      end

      OpcodeLoad: begin
        x_result = x_rs1_data + execute_state.insn.imm_i_sext;
      end

      OpcodeStore: begin
        x_result = x_rs1_data + execute_state.insn.imm_s_sext;
      end

      OpcodeJal: begin
        x_result = execute_state.pc + 4;
        x_branchTarget = execute_state.pc + execute_state.insn.imm_j_sext;
        x_branchTaken = 1'b1;
      end

      OpcodeJalr: begin
        if (execute_state.insn.funct3 == 3'b000) begin
          x_result = execute_state.pc + 4;
          x_branchTarget = (x_rs1_data + execute_state.insn.imm_i_sext) & (~32'h1);
          x_branchTaken = 1'b1;
        end else begin
          x_illegal_insn = 1'b1;
        end
      end

      OpcodeBranch: begin
        case (execute_state.insn.funct3)
          3'b000: x_branchConditional = (x_rs1_data == x_rs2_data);
          3'b001: x_branchConditional = (x_rs1_data != x_rs2_data);
          3'b100: x_branchConditional = (signed'(x_rs1_data) < signed'(x_rs2_data));
          3'b101: x_branchConditional = (signed'(x_rs1_data) >= signed'(x_rs2_data));
          3'b110: x_branchConditional = (unsigned'(x_rs1_data) < unsigned'(x_rs2_data));
          3'b111: x_branchConditional = (unsigned'(x_rs1_data) >= unsigned'(x_rs2_data));
          default: x_illegal_insn = 1'b1;
        endcase

        if (x_branchConditional) begin
          x_branchTarget = signed'(execute_state.pc) + signed'(execute_state.insn.imm_b_sext);
          x_branchTaken = 1'b1;
        end
      end

      OpcodeEnviron: begin
        if (execute_state.insn.insn[31:7] != 25'b0) begin
          x_illegal_insn = 1'b1;
        end
      end

      OpcodeMiscMem: begin
      end

      default: begin
        x_illegal_insn = 1'b1;
      end
    endcase
  end

  always_comb begin
    x_div_meta = '{
      valid: 1'b0,
      rd: execute_state.insn.rd,
      is_rem: 1'b0,
      negate_quot: 1'b0,
      negate_rem: 1'b0,
      special_case: 1'b0,
      special_result: 32'd0,
      pc: execute_state.pc,
      insn_bits: execute_state.insn.insn,
      cycle_status: execute_state.cycle_status
    };

    if (x_div_launch) begin
      x_div_meta.valid = 1'b1;

      case (execute_state.insn.funct3)
        3'b100: begin
          x_div_meta.is_rem = 1'b0;
          if (x_rs2_data == 0) begin
            x_div_meta.special_case = 1'b1;
            x_div_meta.special_result = 32'hffff_ffff;
          end else begin
            x_div_meta.negate_quot = x_rs1_data[31] ^ x_rs2_data[31];
          end
        end

        3'b101: begin
          x_div_meta.is_rem = 1'b0;
          if (x_rs2_data == 0) begin
            x_div_meta.special_case = 1'b1;
            x_div_meta.special_result = 32'hffff_ffff;
          end
        end

        3'b110: begin
          x_div_meta.is_rem = 1'b1;
          if (x_rs2_data == 0) begin
            x_div_meta.special_case = 1'b1;
            x_div_meta.special_result = x_rs1_data;
          end else begin
            x_div_meta.negate_rem = x_rs1_data[31];
          end
        end

        3'b111: begin
          x_div_meta.is_rem = 1'b1;
          if (x_rs2_data == 0) begin
            x_div_meta.special_case = 1'b1;
            x_div_meta.special_result = x_rs1_data;
          end
        end
        default: begin
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (integer i = 0; i < `DIVIDER_STAGES; i = i + 1) begin
        div_pipe[i] <= '{
          valid: 1'b0,
          rd: 5'd0,
          is_rem: 1'b0,
          negate_quot: 1'b0,
          negate_rem: 1'b0,
          special_case: 1'b0,
          special_result: 32'd0,
          pc: 32'd0,
          insn_bits: 32'd0,
          cycle_status: CYCLE_RESET
        };
      end
    end else begin
      for (integer i = `DIVIDER_STAGES-1; i > 0; i = i - 1) begin
        div_pipe[i] <= div_pipe[i-1];
      end
      div_pipe[0] <= x_div_meta;
    end
  end

  always_comb begin
    if (div_pipe[`DIVIDER_STAGES-1].special_case) begin
      div_done_result = div_pipe[`DIVIDER_STAGES-1].special_result;
    end else if (div_pipe[`DIVIDER_STAGES-1].is_rem) begin
      div_done_result = div_pipe[`DIVIDER_STAGES-1].negate_rem ? ((~x_rem) + 1) : x_rem;
    end else begin
      div_done_result = div_pipe[`DIVIDER_STAGES-1].negate_quot ? ((~x_quo) + 1) : x_quo;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      memory_state <= '{
        insn: BUBBLE_INSN,
        pc: 0,
        cycle_status: CYCLE_RESET,
        result: 0,
        rs2_passthrough: 0
      };
    end else begin
      if (div_done_valid) begin
        memory_state <= memory_state;
      end else if (x_div_launch) begin
        memory_state <= '{
          insn: BUBBLE_INSN,
          pc: 0,
          cycle_status: CYCLE_NO_STALL,
          result: 0,
          rs2_passthrough: 0
        };
      end else begin
        memory_state <= '{
          insn: execute_state.insn,
          pc: execute_state.pc,
          cycle_status: execute_state.cycle_status,
          result: x_result,
          rs2_passthrough: x_rs2_data
        };
      end
    end
  end

  logic [`REG_SIZE] m_loaded_data;
  logic [1:0] m_lowerOrderAddr;
  logic m_illegal_insn;
  always_comb begin
    m_lowerOrderAddr = memory_state.result[1:0];
    addr_to_dmem = {memory_state.result[31:2], 2'b00};

    m_loaded_data = 32'b0;
    m_illegal_insn = 1'b0;
    store_we_to_dmem = 4'b0000;
    store_data_to_dmem = 32'b0;

    if (memory_state.insn.opcode == OpcodeLoad) begin
      case (memory_state.insn.funct3)
        3'b000: begin
          case (m_lowerOrderAddr)
            2'b00: m_loaded_data = {{24{load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};
            2'b01: m_loaded_data = {{24{load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
            2'b10: m_loaded_data = {{24{load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
            2'b11: m_loaded_data = {{24{load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
          endcase
        end

        3'b001: begin
          case (m_lowerOrderAddr)
            2'b00: m_loaded_data = {{16{load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
            2'b01: m_loaded_data = {{16{load_data_from_dmem[23]}}, load_data_from_dmem[23:8]};
            2'b10: m_loaded_data = {{16{load_data_from_dmem[31]}}, load_data_from_dmem[31:16]};
            2'b11: m_illegal_insn = 1'b1;
          endcase
        end

        3'b010: begin
          if (m_lowerOrderAddr == 2'b00) begin
            m_loaded_data = load_data_from_dmem[31:0];
          end else begin
            m_illegal_insn = 1'b1;
          end
        end

        3'b100: begin
          case (m_lowerOrderAddr)
            2'b00: m_loaded_data = {24'b0, load_data_from_dmem[7:0]};
            2'b01: m_loaded_data = {24'b0, load_data_from_dmem[15:8]};
            2'b10: m_loaded_data = {24'b0, load_data_from_dmem[23:16]};
            2'b11: m_loaded_data = {24'b0, load_data_from_dmem[31:24]};
          endcase
        end

        3'b101: begin
          case (m_lowerOrderAddr)
            2'b00: m_loaded_data = {16'b0, load_data_from_dmem[15:0]};
            2'b01: m_loaded_data = {16'b0, load_data_from_dmem[23:8]};
            2'b10: m_loaded_data = {16'b0, load_data_from_dmem[31:16]};
            2'b11: m_illegal_insn = 1'b1;
          endcase
        end

        default: begin
          m_illegal_insn = 1'b1;
        end
      endcase
    end

    if (memory_state.insn.opcode == OpcodeStore) begin
      case (memory_state.insn.funct3)
        3'b000: begin
          case (m_lowerOrderAddr)
            2'b00: begin
              store_we_to_dmem = 4'b0001;
              store_data_to_dmem = {24'b0, memory_state.rs2_passthrough[7:0]};
            end
            2'b01: begin
              store_we_to_dmem = 4'b0010;
              store_data_to_dmem = {16'b0, memory_state.rs2_passthrough[7:0], 8'b0};
            end
            2'b10: begin
              store_we_to_dmem = 4'b0100;
              store_data_to_dmem = {8'b0, memory_state.rs2_passthrough[7:0], 16'b0};
            end
            2'b11: begin
              store_we_to_dmem = 4'b1000;
              store_data_to_dmem = {memory_state.rs2_passthrough[7:0], 24'b0};
            end
          endcase
        end

        3'b001: begin
          case (m_lowerOrderAddr)
            2'b00: begin
              store_we_to_dmem = 4'b0011;
              store_data_to_dmem = {16'b0, memory_state.rs2_passthrough[15:0]};
            end
            2'b01: begin
              store_we_to_dmem = 4'b0110;
              store_data_to_dmem = {8'b0, memory_state.rs2_passthrough[15:0], 8'b0};
            end
            2'b10: begin
              store_we_to_dmem = 4'b1100;
              store_data_to_dmem = {memory_state.rs2_passthrough[15:0], 16'b0};
            end
            2'b11: begin
              m_illegal_insn = 1'b1;
            end
          endcase
        end

        3'b010: begin
          if (m_lowerOrderAddr == 2'b00) begin
            store_we_to_dmem = 4'b1111;
            store_data_to_dmem = memory_state.rs2_passthrough;
          end else begin
            m_illegal_insn = 1'b1;
          end
        end

        default: begin
          m_illegal_insn = 1'b1;
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      writeback_state <= '{
        insn: BUBBLE_INSN,
        pc: 0,
        cycle_status: CYCLE_RESET,
        result: 0,
        data: 0
      };
    end else begin
      if (div_done_valid) begin
        writeback_state <= '{
          insn: '{
            insn: div_pipe[`DIVIDER_STAGES-1].insn_bits,
            rs1: 5'd0,
            rs2: 5'd0,
            rd: div_pipe[`DIVIDER_STAGES-1].rd,
            funct3: 3'd0,
            funct7: 7'd0,
            opcode: OpcodeRegReg,
            imm_i: 12'd0,
            imm_i_sext: 32'd0,
            imm_s: 12'd0,
            imm_s_sext: 32'd0,
            imm_b: 13'd0,
            imm_b_sext: 32'd0,
            imm_j: 21'd0,
            imm_j_sext: 32'd0,
            bypassable: 1'b1
          },
          pc: div_pipe[`DIVIDER_STAGES-1].pc,
          cycle_status: div_pipe[`DIVIDER_STAGES-1].cycle_status,
          result: div_done_result,
          data: 32'd0
        };
      end else begin
        writeback_state <= '{
          insn: memory_state.insn,
          pc: memory_state.pc,
          cycle_status: memory_state.cycle_status,
          result: memory_state.result,
          data: m_loaded_data
        };
      end
    end
  end

  logic [`REG_SIZE] w_value;
  logic w_illegal_insn;
  logic w_we;
  logic w_halt;
  always_comb begin
    case (writeback_state.insn.opcode)
      OpcodeLui,
      OpcodeAuipc,
      OpcodeRegImm,
      OpcodeRegReg,
      OpcodeJal,
      OpcodeJalr: begin
        w_we = 1'b1;
        w_value = writeback_state.result;
        w_halt = 1'b0;
      end

      OpcodeLoad: begin
        w_we = 1'b1;
        w_value = writeback_state.data;
        w_halt = 1'b0;
      end

      OpcodeEnviron: begin
        w_we = 1'b0;
        w_value = 32'b0;
        w_halt = 1'b1;
      end

      default: begin
        w_we = 1'b0;
        w_value = 32'b0;
        w_halt = 1'b0;
      end
    endcase

    if (writeback_state.insn.rd == 0) begin
      w_we = 1'b0;
    end
  end

  assign rf_we = w_we;
  assign rf_rd = writeback_state.insn.rd;
  assign rf_rd_data = w_value;

  assign halt = w_halt;

  assign trace_completed_pc = writeback_state.pc;
  assign trace_completed_insn = writeback_state.insn.insn;
  assign trace_completed_cycle_status = writeback_state.cycle_status;

endmodule

module MemorySingleCycle #(
    parameter int NUM_WORDS = 512
) (
    input wire rst,
    input wire clk,
    input wire [`REG_SIZE] pc_to_imem,
    output logic [`REG_SIZE] insn_from_imem,
    input wire [`REG_SIZE] addr_to_dmem,
    output logic [`REG_SIZE] load_data_from_dmem,
    input wire [`REG_SIZE] store_data_to_dmem,
    input wire [3:0] store_we_to_dmem
);

  logic [`REG_SIZE] mem_array[NUM_WORDS];

  initial begin
    $readmemh("mem_initial_contents.hex", mem_array, 0);
  end

  always_comb begin
    assert (pc_to_imem[1:0] == 2'b00);
    assert (addr_to_dmem[1:0] == 2'b00);
  end

  localparam int AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam int AddrLsb = 2;

  always @(negedge clk) begin
    if (rst) begin
    end else begin
      insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
    end
  end

  always @(negedge clk) begin
    if (rst) begin
    end else begin
      if (store_we_to_dmem[0]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
      end
      if (store_we_to_dmem[1]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
      end
      if (store_we_to_dmem[2]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
      end
      if (store_we_to_dmem[3]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
      end
      load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
    end
  end
endmodule

module Processor (
    input  wire  clk,
    input  wire  rst,
    output logic halt,
    output wire [`REG_SIZE] trace_completed_pc,
    output wire [`INSN_SIZE] trace_completed_insn,
    output cycle_status_e trace_completed_cycle_status
);

  wire [`INSN_SIZE] insn_from_imem;
  wire [`REG_SIZE] pc_to_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [3:0] mem_data_we;
  wire [(8*32)-1:0] test_case;

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) memory (
      .rst                (rst),
      .clk                (clk),
      .pc_to_imem         (pc_to_imem),
      .insn_from_imem     (insn_from_imem),
      .addr_to_dmem       (mem_data_addr),
      .load_data_from_dmem(mem_data_loaded_value),
      .store_data_to_dmem (mem_data_to_write),
      .store_we_to_dmem   (mem_data_we)
  );

  DatapathPipelined datapath (
      .clk(clk),
      .rst(rst),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(mem_data_addr),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem(mem_data_we),
      .load_data_from_dmem(mem_data_loaded_value),
      .halt(halt),
      .trace_completed_pc(trace_completed_pc),
      .trace_completed_insn(trace_completed_insn),
      .trace_completed_cycle_status(trace_completed_cycle_status)
  );

endmodule
