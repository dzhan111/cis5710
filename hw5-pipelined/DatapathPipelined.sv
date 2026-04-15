`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31:0

// insns are 32 bits in RV32IM
`define INSN_SIZE 31:0

// RV opcodes are 7 bits
`define OPCODE_SIZE 6:0

`ifndef DIVIDER_STAGES
`define DIVIDER_STAGES 16
`endif

`ifndef SYNTHESIS
`include "../hw3-singlecycle/RvDisassembler.sv"
`endif
`include "../hw2b-cla/CarryLookaheadAdder.sv"
`include "../hw4-multicycle/DividerUnsignedPipelined.sv"
`include "../hw3-singlecycle/cycle_status.sv"

// STAGE STRUCTS FOR PIPELINE
// DECODE
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
} stage_decode_t;

// EXECUTE
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
  logic [6:0] funct7;
  logic [4:0] rs2;
  logic [4:0] rs1;
  logic [2:0] funct3;
  logic [4:0] rd;
  logic [`OPCODE_SIZE] opcode;
  logic [`REG_SIZE] rs1_data;
  logic [`REG_SIZE] rs2_data;
} stage_execute_t;

// MEMORY
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
  logic we;
  logic [4:0] rd;
  logic [`REG_SIZE] rd_data;
  logic is_load;
  logic is_store;
  logic [2:0] load_funct3;
  logic [`REG_SIZE] store_data;
  logic [4:0] rs2;
  logic [1:0] byte_off;
} stage_memory_t;

// WRITEBACK
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
  logic we;
  logic [4:0] rd;
  logic [`REG_SIZE] rd_data;
} stage_writeback_t;

module Disasm #(
    byte PREFIX = "D"
) (
    input wire [31:0] insn,
    output wire [(8*32)-1:0] disasm
);
`ifndef SYNTHESIS
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
`endif
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
  // genvar i;
  logic [`REG_SIZE] regs[NumRegs];

  integer i;
  always_comb begin
    rs1_data = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    rs2_data = (rs2 == 5'd0) ? 32'd0 : regs[rs2];
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < NumRegs; i = i + 1) begin
        regs[i] <= 32'd0;
      end
    end else begin

      if (we && rd != 5'd0) begin
        regs[rd] <= rd_data;
      end

      regs[5'd0] <= 32'd0;
    end
  end

endmodule

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

  // opcodes - see section 19 of RiscV spec
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

  // cycle counter, not really part of any stage but useful for orienting within GtkWave
  // do not rename this as the testbench uses this value
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

  logic x_branch_taken;
  logic [`REG_SIZE] f_pc_branch_decision;

  wire pipeline_stall;
  wire load_use_stall;

  // program counter
  always_ff @(posedge clk) begin
    if (rst) begin
      f_pc_current <= 32'd0;
      // NB: use CYCLE_NO_STALL since this is the value that will persist after the last reset cycle
      f_cycle_status <= CYCLE_NO_STALL;
    end else if (x_branch_taken) begin
      f_cycle_status <= CYCLE_NO_STALL;
      f_pc_current <= f_pc_branch_decision;
    end else if (pipeline_stall) begin  // hold pc while d/x (or whole front) stalled
      f_cycle_status <= CYCLE_NO_STALL;
      f_pc_current <= f_pc_current;
    end else begin
      f_cycle_status <= CYCLE_NO_STALL;
      f_pc_current <= f_pc_current + 4;
    end
  end
  // send PC to imem
  assign pc_to_imem = f_pc_current;
  assign f_insn = insn_from_imem;

  // Here's how to disassemble an insn into a string you can view in GtkWave.
  // Use PREFIX to provide a 1-character tag to identify which stage the insn comes from.
  wire [255:0] f_disasm;
  Disasm #(
      .PREFIX("F")
  ) disasm_0fetch (
      .insn  (f_insn),
      .disasm(f_disasm)
  );

  /****************/
  /* DECODE STAGE */
  /****************/

  stage_decode_t decode_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      decode_state <= '{
        pc: 0,
        insn: 0,
        cycle_status: CYCLE_RESET
      };
    end else if (x_branch_taken) begin
      decode_state <= '{
        pc: 0,
        insn: 0,
        cycle_status: CYCLE_TAKEN_BRANCH
      };
    end else if (pipeline_stall) begin 
      decode_state <= decode_state;
    end else begin
      begin
        decode_state <= '{
          pc: f_pc_current,
          insn: f_insn,
          cycle_status: f_cycle_status
        };
      end
    end
  end
  wire [255:0] d_disasm;
  Disasm #(
      .PREFIX("D")
  ) disasm_1decode (
      .insn  (decode_state.insn),
      .disasm(d_disasm)
  );

  wire [6:0] d_insn_funct7 = decode_state.insn[31:25];
  wire [4:0] d_insn_rs2 = decode_state.insn[24:20];
  wire [4:0] d_insn_rs1 = decode_state.insn[19:15];
  wire [2:0] d_insn_funct3 = decode_state.insn[14:12];
  wire [4:0] d_insn_rd = decode_state.insn[11:7];
  wire [`OPCODE_SIZE] d_insn_opcode = decode_state.insn[6:0];

  wire [`REG_SIZE] d_rs1_data_raw;
  wire [`REG_SIZE] d_rs2_data_raw;

  logic [`REG_SIZE] d_rs1_data;
  logic [`REG_SIZE] d_rs2_data;

  stage_execute_t execute_state;
  stage_memory_t memory_state;
  stage_writeback_t writeback_state;

  // REGISTER FILE
  RegFile rf (
    .clk     (clk),
    .rst     (rst),
    .we      (writeback_state.we),
    .rd      (writeback_state.rd),
    .rd_data (writeback_state.rd_data),
    .rs1     (d_insn_rs1),
    .rs2     (d_insn_rs2),
    .rs1_data(d_rs1_data_raw),
    .rs2_data(d_rs2_data_raw)
  );

  logic x_we;

  localparam int DVS = `DIVIDER_STAGES;
  logic [4:0] div_pipe_rd[0:DVS-1];
  logic div_pipe_valid[0:DVS-1];
  logic [`REG_SIZE] div_pipe_rs1[0:DVS-1];
  logic [`REG_SIZE] div_pipe_rs2[0:DVS-1];

  logic div_pipe_is_div[0:DVS-1];
  logic div_pipe_is_divu[0:DVS-1];
  logic div_pipe_is_rem[0:DVS-1];
  logic div_pipe_is_remu[0:DVS-1];
  logic [`REG_SIZE] div_pipe_pc[0:DVS-1];
  logic [`INSN_SIZE] div_pipe_insn[0:DVS-1];
  cycle_status_e div_pipe_cstat[0:DVS-1];

  wire d_reads_rs1_h = (d_insn_opcode == OpcodeLui || d_insn_opcode == OpcodeAuipc || d_insn_opcode == OpcodeJal) ? 1'b0 : 1'b1;
  wire d_reads_rs2_h = (d_insn_opcode == OpcodeRegReg || d_insn_opcode == OpcodeBranch);
  wire d_decode_is_div_h = decode_state.insn != 32'd0 && decode_state.insn[6:0] == OpcodeRegReg &&
      decode_state.insn[31:25] == 7'd1 && (decode_state.insn[14:12] == 3'b100 || decode_state.insn[14:12] == 3'b101 ||
       decode_state.insn[14:12] == 3'b110 || decode_state.insn[14:12] == 3'b111);

  wire x_is_load_h = execute_state.insn != 32'd0 && execute_state.opcode == OpcodeLoad;
  assign load_use_stall = x_is_load_h && (execute_state.rd != 5'd0) && (((d_reads_rs1_h && d_insn_rs1 == execute_state.rd) ||
        (d_reads_rs2_h && d_insn_rs2 == execute_state.rd)));

  logic div_stall_raw;
  logic div_any_inflight;
  logic div_nondiv_stall;
  always_comb begin
    div_stall_raw = 1'b0;
    div_any_inflight = 1'b0;
    for (int hk = 0; hk < DVS; hk++) begin
      if (div_pipe_valid[hk]) div_any_inflight = 1'b1;
    end
    if (d_reads_rs1_h && d_insn_rs1 != 5'd0) begin
      if (d_decode_is_div_h) begin
        for (int hi = 0; hi < DVS; hi++) begin
          if (div_pipe_valid[hi] && div_pipe_rd[hi] == d_insn_rs1) div_stall_raw = 1'b1;
        end
      end else begin
        for (int hi = 0; hi < DVS-1; hi++) begin
          if (div_pipe_valid[hi] && div_pipe_rd[hi] == d_insn_rs1) div_stall_raw = 1'b1;
        end
      end
    end
    if (d_reads_rs2_h && d_insn_rs2 != 5'd0) begin
      if (d_decode_is_div_h) begin
        for (int hj = 0; hj < DVS; hj++) begin
          if (div_pipe_valid[hj] && div_pipe_rd[hj] == d_insn_rs2) div_stall_raw = 1'b1;
        end
      end else begin
        for (int hj = 0; hj < DVS-1; hj++) begin
          if (div_pipe_valid[hj] && div_pipe_rd[hj] == d_insn_rs2) div_stall_raw = 1'b1;
        end
      end
    end
    div_nondiv_stall = div_any_inflight && !div_pipe_valid[DVS-1] &&
        (decode_state.insn != 32'd0) && !d_decode_is_div_h;
  end

  wire x_is_div_h = execute_state.insn != 32'd0 && execute_state.opcode == OpcodeRegReg &&
      execute_state.insn[31:25] == 7'd1 &&
      (execute_state.insn[14:12] == 3'b100 || execute_state.insn[14:12] == 3'b101 ||
       execute_state.insn[14:12] == 3'b110 || execute_state.insn[14:12] == 3'b111);

  wire div_out_valid = div_pipe_valid[DVS-1];
  wire div_mem_conflict = div_out_valid && execute_state.insn != 32'd0 && !x_is_div_h;

  wire div_stall = 1'b0;
  assign pipeline_stall = load_use_stall || div_stall_raw || div_nondiv_stall || div_mem_conflict;

  cycle_status_e ex_bubble_status;
  always_comb begin
    if (load_use_stall && (div_stall_raw || div_nondiv_stall))
      ex_bubble_status = cycle_status_e'(CYCLE_LOAD2USE | CYCLE_DIV);
    else if (load_use_stall) ex_bubble_status = CYCLE_LOAD2USE;
    else if (div_stall_raw || div_nondiv_stall) ex_bubble_status = CYCLE_DIV;
    else ex_bubble_status = CYCLE_NO_STALL;
  end

  wire d_decode_is_div = d_decode_is_div_h;

  always_ff @(posedge clk) begin
      if (rst) begin
        execute_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_RESET,
          funct7: 0,
          rs2: 0,
          rs1: 0,
          funct3: 0,
          rd: 0,
          opcode: 0,
          rs1_data: 0,
          rs2_data: 0
        };
        for (int di = 0; di < DVS; di++) begin
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
          div_pipe_cstat[di] <= CYCLE_NO_STALL;
        end
      end else if (x_branch_taken) begin
        execute_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_TAKEN_BRANCH,
          funct7: 0,
          rs2: 0,
          rs1: 0,
          funct3: 0,
          rd: 0,
          opcode: 0,
          rs1_data: 0,
          rs2_data: 0
        };
        for (int di = 0; di < DVS; di++) begin
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
          div_pipe_cstat[di] <= CYCLE_NO_STALL;
        end
      end else if (load_use_stall || div_stall_raw || div_nondiv_stall) begin
        execute_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: ex_bubble_status,
          funct7: 0,
          rs2: 0,
          rs1: 0,
          funct3: 0,
          rd: 0,
          opcode: 0,
          rs1_data: 0,
          rs2_data: 0
        };
        for (int di = DVS - 1; di > 0; di--) begin
          div_pipe_rd[di] <= div_pipe_rd[di-1];
          div_pipe_valid[di] <= div_pipe_valid[di-1];
          div_pipe_rs1[di] <= div_pipe_rs1[di-1];
          div_pipe_rs2[di] <= div_pipe_rs2[di-1];
          div_pipe_is_div[di] <= div_pipe_is_div[di-1];
          div_pipe_is_divu[di] <= div_pipe_is_divu[di-1];
          div_pipe_is_rem[di] <= div_pipe_is_rem[di-1];
          div_pipe_is_remu[di] <= div_pipe_is_remu[di-1];
          div_pipe_pc[di] <= div_pipe_pc[di-1];
          div_pipe_insn[di] <= div_pipe_insn[di-1];
          div_pipe_cstat[di] <= div_pipe_cstat[di-1];
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
        div_pipe_cstat[0] <= CYCLE_NO_STALL;
      end else if (div_mem_conflict) begin
        execute_state <= execute_state;  
        for (int di = DVS - 1; di > 0; di--) begin
          div_pipe_rd[di] <= div_pipe_rd[di-1];
          div_pipe_valid[di] <= div_pipe_valid[di-1];
          div_pipe_rs1[di] <= div_pipe_rs1[di-1];
          div_pipe_rs2[di] <= div_pipe_rs2[di-1];
          div_pipe_is_div[di] <= div_pipe_is_div[di-1];
          div_pipe_is_divu[di] <= div_pipe_is_divu[di-1];
          div_pipe_is_rem[di] <= div_pipe_is_rem[di-1];
          div_pipe_is_remu[di] <= div_pipe_is_remu[di-1];
          div_pipe_pc[di] <= div_pipe_pc[di-1];
          div_pipe_insn[di] <= div_pipe_insn[di-1];
          div_pipe_cstat[di] <= div_pipe_cstat[di-1];
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
        div_pipe_cstat[0] <= CYCLE_NO_STALL;
      end else begin
        execute_state <= '{
          pc: decode_state.pc,
          insn: decode_state.insn,
          cycle_status: decode_state.cycle_status,
          funct7: d_insn_funct7,
          rs2: d_insn_rs2,
          rs1: d_insn_rs1,
          funct3: d_insn_funct3,
          rd: d_insn_rd,
          opcode: d_insn_opcode,
          rs1_data: d_rs1_data,
          rs2_data: d_rs2_data
        };
        for (int di = DVS - 1; di > 0; di--) begin
          div_pipe_rd[di] <= div_pipe_rd[di-1];
          div_pipe_valid[di] <= div_pipe_valid[di-1];
          div_pipe_rs1[di] <= div_pipe_rs1[di-1];
          div_pipe_rs2[di] <= div_pipe_rs2[di-1];
          div_pipe_is_div[di] <= div_pipe_is_div[di-1];
          div_pipe_is_divu[di] <= div_pipe_is_divu[di-1];
          div_pipe_is_rem[di] <= div_pipe_is_rem[di-1];
          div_pipe_is_remu[di] <= div_pipe_is_remu[di-1];
          div_pipe_pc[di] <= div_pipe_pc[di-1];
          div_pipe_insn[di] <= div_pipe_insn[di-1];
          div_pipe_cstat[di] <= div_pipe_cstat[di-1];
        end
        begin
          if (d_decode_is_div) begin
            div_pipe_valid[0] <= 1'b1;
            div_pipe_rd[0] <= d_insn_rd;
            div_pipe_rs1[0] <= d_rs1_data;
            div_pipe_rs2[0] <= d_rs2_data;
            div_pipe_pc[0] <= decode_state.pc;
            div_pipe_insn[0] <= decode_state.insn;
            div_pipe_cstat[0] <= decode_state.cycle_status;
            div_pipe_is_div[0] <= decode_state.insn[14:12] == 3'b100;
            div_pipe_is_divu[0] <= decode_state.insn[14:12] == 3'b101;
            div_pipe_is_rem[0] <= decode_state.insn[14:12] == 3'b110;
            div_pipe_is_remu[0] <= decode_state.insn[14:12] == 3'b111;
          end else begin
            div_pipe_valid[0] <= 1'b0;
            div_pipe_rd[0] <= 5'd0;
            div_pipe_rs1[0] <= 32'd0;
            div_pipe_rs2[0] <= 32'd0;
            div_pipe_pc[0] <= 32'd0;
            div_pipe_insn[0] <= 32'd0;
            div_pipe_cstat[0] <= CYCLE_NO_STALL;
            div_pipe_is_div[0] <= 1'b0;
            div_pipe_is_divu[0] <= 1'b0;
            div_pipe_is_rem[0] <= 1'b0;
            div_pipe_is_remu[0] <= 1'b0;
          end
        end
      end
    end
    wire [255:0] x_disasm;
    Disasm #(
        .PREFIX("X")
    ) disasm_1execute (
        .insn  (execute_state.insn),
        .disasm(x_disasm)
    );

  wire [`REG_SIZE] x_imm_u = {execute_state.insn[31:12], 12'b0};

  wire [11:0] x_imm_s;
  assign x_imm_s[11:5] = execute_state.funct7, x_imm_s[4:0] = execute_state.rd;

  wire [11:0] x_imm_i;
  assign x_imm_i = execute_state.insn[31:20];
  wire [4:0] x_imm_shamt = execute_state.insn[24:20];

  logic [`REG_SIZE] x_cla_a, x_cla_b;
  logic             x_cla_cin;
  wire  [`REG_SIZE] x_cla_sum;


  wire [12:0] x_imm_b;
  assign {x_imm_b[12], x_imm_b[10:5]} = execute_state.funct7, {x_imm_b[4:1], x_imm_b[11]} = execute_state.rd, x_imm_b[0] = 1'b0;

  wire [20:0] x_imm_j;
  assign {x_imm_j[20], x_imm_j[10:1], x_imm_j[11], x_imm_j[19:12], x_imm_j[0]} = {execute_state.insn[31:12], 1'b0};

  wire [`REG_SIZE] x_imm_i_sext = {{20{x_imm_i[11]}}, x_imm_i[11:0]};
  wire [`REG_SIZE] x_imm_s_sext = {{20{x_imm_s[11]}}, x_imm_s[11:0]};
  wire [`REG_SIZE] x_imm_b_sext = {{19{x_imm_b[12]}}, x_imm_b[12:0]};
  wire [`REG_SIZE] x_imm_j_sext = {{11{x_imm_j[20]}}, x_imm_j[20:0]};


  CarryLookaheadAdder cla32 (
    .a   (x_cla_a),
    .b   (x_cla_b),
    .cin (x_cla_cin),
    .sum (x_cla_sum)
  );

  logic x_illegal_insn;

  logic [4:0]  x_rd;
  logic [4:0]  x_rs1;
  logic [4:0]  x_rs2;
  logic [`REG_SIZE] x_wdata;

  logic [`REG_SIZE] x_rs1_data, x_rs2_data;
  always_comb begin
    x_rs1_data = execute_state.rs1_data;
    x_rs2_data = execute_state.rs2_data;

    if (memory_state.we && memory_state.rd != 5'd0 && memory_state.rd == execute_state.rs1) begin
        x_rs1_data = memory_state.rd_data;
    end else if (writeback_state.we && writeback_state.rd != 5'd0 && writeback_state.rd == execute_state.rs1) begin
        x_rs1_data = writeback_state.rd_data;
    end

    if (memory_state.we && memory_state.rd != 5'd0 && memory_state.rd == execute_state.rs2) begin
        x_rs2_data = memory_state.rd_data;
    end else if (writeback_state.we && writeback_state.rd != 5'd0 && writeback_state.rd == execute_state.rs2) begin
        x_rs2_data = writeback_state.rd_data;
    end
  end

  wire [`REG_SIZE] x_ls_addr = x_rs1_data + x_imm_i_sext;
  wire [`REG_SIZE] x_ls_addr_s = x_rs1_data + x_imm_s_sext;

  wire insn_lui   = execute_state.opcode == OpcodeLui;
  wire insn_auipc = execute_state.opcode == OpcodeAuipc;
  wire insn_jal   = execute_state.opcode == OpcodeJal;
  wire insn_jalr  = execute_state.opcode == OpcodeJalr;

  wire insn_beq  = execute_state.opcode == OpcodeBranch && execute_state.insn[14:12] == 3'b000;
  wire insn_bne  = execute_state.opcode == OpcodeBranch && execute_state.insn[14:12] == 3'b001;
  wire insn_blt  = execute_state.opcode == OpcodeBranch && execute_state.insn[14:12] == 3'b100;
  wire insn_bge  = execute_state.opcode == OpcodeBranch && execute_state.insn[14:12] == 3'b101;
  wire insn_bltu = execute_state.opcode == OpcodeBranch && execute_state.insn[14:12] == 3'b110;
  wire insn_bgeu = execute_state.opcode == OpcodeBranch && execute_state.insn[14:12] == 3'b111;

  wire insn_lb  = execute_state.opcode == OpcodeLoad && execute_state.insn[14:12] == 3'b000;
  wire insn_lh  = execute_state.opcode == OpcodeLoad && execute_state.insn[14:12] == 3'b001;
  wire insn_lw  = execute_state.opcode == OpcodeLoad && execute_state.insn[14:12] == 3'b010;
  wire insn_lbu = execute_state.opcode == OpcodeLoad && execute_state.insn[14:12] == 3'b100;
  wire insn_lhu = execute_state.opcode == OpcodeLoad && execute_state.insn[14:12] == 3'b101;

  wire insn_sb = execute_state.opcode == OpcodeStore && execute_state.insn[14:12] == 3'b000;
  wire insn_sh = execute_state.opcode == OpcodeStore && execute_state.insn[14:12] == 3'b001;
  wire insn_sw = execute_state.opcode == OpcodeStore && execute_state.insn[14:12] == 3'b010;

  wire insn_addi  = execute_state.opcode == OpcodeRegImm && execute_state.insn[14:12] == 3'b000;
  wire insn_slti  = execute_state.opcode == OpcodeRegImm && execute_state.insn[14:12] == 3'b010;
  wire insn_sltiu = execute_state.opcode == OpcodeRegImm && execute_state.insn[14:12] == 3'b011;
  wire insn_xori  = execute_state.opcode == OpcodeRegImm && execute_state.insn[14:12] == 3'b100;
  wire insn_ori   = execute_state.opcode == OpcodeRegImm && execute_state.insn[14:12] == 3'b110;
  wire insn_andi  = execute_state.opcode == OpcodeRegImm && execute_state.insn[14:12] == 3'b111;

  wire insn_slli = execute_state.opcode == OpcodeRegImm && execute_state.insn[14:12] == 3'b001 && execute_state.insn[31:25] == 7'd0;
  wire insn_srli = execute_state.opcode == OpcodeRegImm && execute_state.insn[14:12] == 3'b101 && execute_state.insn[31:25] == 7'd0;
  wire insn_srai = execute_state.opcode == OpcodeRegImm && execute_state.insn[14:12] == 3'b101 && execute_state.insn[31:25] == 7'b0100000;

  wire insn_add  = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b000 && execute_state.insn[31:25] == 7'd0;
  wire insn_sub  = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b000 && execute_state.insn[31:25] == 7'b0100000;
  wire insn_sll  = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b001 && execute_state.insn[31:25] == 7'd0;
  wire insn_slt  = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b010 && execute_state.insn[31:25] == 7'd0;
  wire insn_sltu = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b011 && execute_state.insn[31:25] == 7'd0;
  wire insn_xor  = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b100 && execute_state.insn[31:25] == 7'd0;
  wire insn_srl  = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b101 && execute_state.insn[31:25] == 7'd0;
  wire insn_sra  = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b101 && execute_state.insn[31:25] == 7'b0100000;
  wire insn_or   = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b110 && execute_state.insn[31:25] == 7'd0;
  wire insn_and  = execute_state.opcode == OpcodeRegReg && execute_state.insn[14:12] == 3'b111 && execute_state.insn[31:25] == 7'd0;

  wire insn_mul    = execute_state.opcode == OpcodeRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b000;
  wire insn_mulh   = execute_state.opcode == OpcodeRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b001;
  wire insn_mulhsu = execute_state.opcode == OpcodeRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b010;
  wire insn_mulhu  = execute_state.opcode == OpcodeRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b011;
  wire insn_div    = execute_state.opcode == OpcodeRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b100;
  wire insn_divu   = execute_state.opcode == OpcodeRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b101;
  wire insn_rem    = execute_state.opcode == OpcodeRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b110;
  wire insn_remu   = execute_state.opcode == OpcodeRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b111;

  wire insn_ecall = execute_state.opcode == OpcodeEnviron && execute_state.insn[31:7] == 25'd0;
  wire insn_fence = execute_state.opcode == OpcodeMiscMem;

  wire signed [63:0] x_mulh_full = 64'($signed(x_rs1_data)) * 64'($signed(x_rs2_data));
  wire [63:0] x_mulhsu_full = $signed({{32{x_rs1_data[31]}}, x_rs1_data}) * $signed({32'b0, x_rs2_data});
  wire [63:0] x_mulhu_wide = 64'(x_rs1_data) * 64'(x_rs2_data);

  always_comb begin

    x_illegal_insn = 1'b0;
    x_branch_taken = 1'b0;

    x_rs1 = execute_state.rs1;
    x_rs2 = execute_state.rs2;
    x_rd = execute_state.rd;
    x_we = 1'b0;
    x_wdata = 32'd0;

    x_cla_a   = 32'd0;
    x_cla_b   = 32'd0;
    x_cla_cin = 1'b0;

    f_pc_branch_decision = execute_state.pc + 32'd4;

    case (execute_state.opcode)

    OpcodeLui: begin
      x_we    = 1'b1;
      x_wdata = x_imm_u;
    end

    OpcodeAuipc: begin
      x_we = 1'b1;
      x_wdata = execute_state.pc + x_imm_u;
    end

    OpcodeRegImm: begin

      x_we = 1'b1;

      if (insn_addi) begin
        x_cla_a   = x_rs1_data;
        x_cla_b   = x_imm_i_sext;
        x_cla_cin = 1'b0;

        x_wdata = x_cla_sum;
      end

      else if (insn_slti) begin
        x_wdata = ($signed(x_rs1_data) < $signed(x_imm_i_sext)) ? 32'd1 : 32'd0;
      end

      else if (insn_sltiu) begin
        x_wdata = (x_rs1_data < x_imm_i_sext) ? 32'd1 : 32'd0;
      end

      else if (insn_xori) begin
        x_wdata = x_rs1_data ^ x_imm_i_sext;
      end

      else if (insn_ori) begin
        x_wdata = x_rs1_data | x_imm_i_sext;
      end

      else if (insn_andi) begin
        x_wdata = x_rs1_data & x_imm_i_sext;
      end

      else if (insn_slli) begin
        x_wdata = x_rs1_data << x_imm_shamt;
      end

      else if (insn_srli) begin
        x_wdata = x_rs1_data >> x_imm_shamt;
      end

      else if (insn_srai) begin
        x_wdata = $signed(x_rs1_data) >>> x_imm_shamt;
      end

      else begin
        x_illegal_insn = 1'b1;
      end
    end


    OpcodeRegReg: begin

      x_we    = 1'b1;

      if (insn_add) begin
        x_cla_a   = x_rs1_data;
        x_cla_b   = x_rs2_data;
        x_cla_cin = 1'b0;

        x_wdata = x_cla_sum;
      end

      else if (insn_sub) begin
        x_cla_a   = x_rs1_data;
        x_cla_b   = ~x_rs2_data;
        x_cla_cin = 1'b1;

        x_wdata = x_cla_sum;
      end

      else if (insn_sll) begin
        x_wdata = x_rs1_data << x_rs2_data[4:0];
      end

      else if (insn_slt) begin
        x_wdata = ($signed(x_rs1_data) < $signed(x_rs2_data)) ? 32'd1 : 32'd0;
      end

      else if (insn_sltu) begin
        x_wdata = (x_rs1_data < x_rs2_data) ? 32'd1 : 32'd0;
      end

      else if (insn_xor) begin
        x_wdata = x_rs1_data ^ x_rs2_data;
      end

      else if (insn_srl) begin
        x_wdata = x_rs1_data >> x_rs2_data[4:0];
      end

      else if (insn_sra) begin
        x_wdata = $signed(x_rs1_data) >>> x_rs2_data[4:0];
      end

      else if (insn_or) begin
        x_wdata = x_rs1_data | x_rs2_data;
      end

      else if (insn_and) begin
        x_wdata = x_rs1_data & x_rs2_data;
      end

      else if (insn_mul) begin
        x_wdata = x_rs1_data * x_rs2_data;
      end

      else if (insn_mulh) begin
        x_wdata = x_mulh_full[63:32];
      end

      else if (insn_mulhsu) begin
        x_wdata = x_mulhsu_full[63:32];
      end

      else if (insn_mulhu) begin
        x_wdata = x_mulhu_wide[63:32];
      end

      else if (insn_div || insn_divu || insn_rem || insn_remu) begin
        // real write happens when div completes through m (not here)
        x_we = 1'b0;
      end

      else begin
        x_illegal_insn = 1'b1;
      end

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
      x_wdata = execute_state.pc + 32'd4;
      x_branch_taken = 1'b1;
      f_pc_branch_decision = execute_state.pc + x_imm_j_sext;
    end

    OpcodeJalr: begin
      x_we = 1'b1;
      x_wdata = execute_state.pc + 32'd4;
      x_branch_taken = 1'b1;
      f_pc_branch_decision = (x_rs1_data + x_imm_i_sext) & ~32'b1;
    end

    OpcodeBranch: begin

      if (insn_beq)
        x_branch_taken = (x_rs1_data == x_rs2_data);

      else if (insn_bne)
        x_branch_taken = (x_rs1_data != x_rs2_data);

      else if (insn_blt)
        x_branch_taken = ($signed(x_rs1_data) < $signed(x_rs2_data));

      else if (insn_bge)
        x_branch_taken = ($signed(x_rs1_data) >= $signed(x_rs2_data));

      else if (insn_bltu)
        x_branch_taken = (x_rs1_data < x_rs2_data);

      else if (insn_bgeu)
        x_branch_taken = (x_rs1_data >= x_rs2_data);

      else
        x_illegal_insn = 1'b1;

      if (!x_illegal_insn) begin
        if (x_branch_taken)
          f_pc_branch_decision = execute_state.pc + x_imm_b_sext;
      end
    end

    OpcodeEnviron: begin
    end

    default: begin
      x_illegal_insn = 1'b1;
    end

    endcase

  end

  wire d_fwd_mem_ok = memory_state.we && memory_state.rd != 5'd0 && !memory_state.is_load;
  wire d_fwd_ex_ok =
      (execute_state.insn != 32'd0) && x_we && (execute_state.opcode != OpcodeLoad);

  always_comb begin
    d_rs1_data = d_rs1_data_raw;
    d_rs2_data = d_rs2_data_raw;
    if (d_insn_rs1 != 5'd0) begin
      if (d_fwd_ex_ok && execute_state.rd == d_insn_rs1) d_rs1_data = x_wdata;
      else if (d_fwd_mem_ok && memory_state.rd == d_insn_rs1) d_rs1_data = memory_state.rd_data;
      else if (writeback_state.we && writeback_state.rd != 5'd0 && writeback_state.rd == d_insn_rs1)
        d_rs1_data = writeback_state.rd_data;
    end
    if (d_insn_rs2 != 5'd0) begin
      if (d_fwd_ex_ok && execute_state.rd == d_insn_rs2) d_rs2_data = x_wdata;
      else if (d_fwd_mem_ok && memory_state.rd == d_insn_rs2) d_rs2_data = memory_state.rd_data;
      else if (writeback_state.we && writeback_state.rd != 5'd0 && writeback_state.rd == d_insn_rs2)
        d_rs2_data = writeback_state.rd_data;
    end
  end

  wire [`REG_SIZE] d_div_rs1_abs = d_rs1_data[31] ? (~d_rs1_data + 32'd1) : d_rs1_data;
  wire [`REG_SIZE] d_div_rs2_abs = d_rs2_data[31] ? (~d_rs2_data + 32'd1) : d_rs2_data;
  wire div_issue_this_cycle = d_decode_is_div && !pipeline_stall && !x_branch_taken && !rst;

  logic [`REG_SIZE] div_i_dividend;
  logic [`REG_SIZE] div_i_divisor;
  always_comb begin
    div_i_dividend = 32'd0;
    div_i_divisor = 32'd1;
    if (div_issue_this_cycle) begin
      if (decode_state.insn[14:12] == 3'b100 || decode_state.insn[14:12] == 3'b110) begin
        div_i_dividend = d_div_rs1_abs;
        div_i_divisor = d_div_rs2_abs;
      end else begin
        div_i_dividend = d_rs1_data;
        div_i_divisor = d_rs2_data;
      end
    end
  end

  wire [`REG_SIZE] div_o_quotient;
  wire [`REG_SIZE] div_o_remainder;
  DividerUnsignedPipelined divider (
      .clk       (clk),
      .rst       (rst),
      .stall     (div_stall),
      .i_dividend(div_i_dividend),
      .i_divisor (div_i_divisor),
      .o_quotient(div_o_quotient),
      .o_remainder(div_o_remainder)
  );

  logic [`REG_SIZE] div_o_quotient_r;
  logic [`REG_SIZE] div_o_remainder_r;
  always_ff @(posedge clk) begin
    if (rst) begin
      div_o_quotient_r   <= 32'd0;
      div_o_remainder_r  <= 32'd0;
    end else if (!div_stall) begin
      div_o_quotient_r   <= div_o_quotient;
      div_o_remainder_r  <= div_o_remainder;
    end
  end

  logic [`REG_SIZE] div_m_wdata;
  always_comb begin
    div_m_wdata = 32'd0;
    if (div_pipe_valid[DVS-1]) begin
      if (div_pipe_is_div[DVS-1]) begin
        if (div_pipe_rs2[DVS-1] == 32'd0) div_m_wdata = 32'hFFFF_FFFF;
        else if (div_pipe_rs1[DVS-1] == 32'h8000_0000 && div_pipe_rs2[DVS-1] == 32'hFFFF_FFFF)
          div_m_wdata = 32'h8000_0000;
        else if (div_pipe_rs1[DVS-1][31] ^ div_pipe_rs2[DVS-1][31])
          div_m_wdata = ~div_o_quotient_r + 32'd1;
        else div_m_wdata = div_o_quotient_r;
      end else if (div_pipe_is_divu[DVS-1]) begin
        if (div_pipe_rs2[DVS-1] == 32'd0) div_m_wdata = 32'hFFFF_FFFF;
        else div_m_wdata = div_o_quotient_r;
      end else if (div_pipe_is_rem[DVS-1]) begin
        if (div_pipe_rs2[DVS-1] == 32'd0) div_m_wdata = div_pipe_rs1[DVS-1];
        else if (div_pipe_rs1[DVS-1] == 32'h8000_0000 && div_pipe_rs2[DVS-1] == 32'hFFFF_FFFF)
          div_m_wdata = 32'd0;
        else if (div_pipe_rs1[DVS-1][31]) div_m_wdata = ~div_o_remainder_r + 32'd1;
        else div_m_wdata = div_o_remainder_r;
      end else begin
        if (div_pipe_rs2[DVS-1] == 32'd0) div_m_wdata = div_pipe_rs1[DVS-1];
        else div_m_wdata = div_o_remainder_r;
      end
    end
  end

    always_ff @(posedge clk) begin
      if (rst) begin
        memory_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_RESET,
          we: 0,
          rd: 0,
          rd_data: 0,
          is_load: 0,
          is_store: 0,
          load_funct3: 0,
          store_data: 0,
          rs2: 0,
          byte_off: 0
        };
      end else if (div_pipe_valid[DVS-1]) begin
        memory_state <= '{
          pc: div_pipe_pc[DVS-1],
          insn: div_pipe_insn[DVS-1],
          cycle_status: div_pipe_cstat[DVS-1],
          we: (div_pipe_rd[DVS-1] != 5'd0),
          rd: div_pipe_rd[DVS-1],
          rd_data: div_m_wdata,
          is_load: 1'b0,
          is_store: 1'b0,
          load_funct3: 3'b000,
          store_data: 32'd0,
          rs2: 5'd0,
          byte_off: 2'd0
        };
      end else if (x_is_div_h) begin
        memory_state <= '{
          pc: 32'd0,
          insn: 32'd0,
          cycle_status: CYCLE_DIV,
          we: 1'b0,
          rd: 5'd0,
          rd_data: 32'd0,
          is_load: 1'b0,
          is_store: 1'b0,
          load_funct3: 3'b000,
          store_data: 32'd0,
          rs2: 5'd0,
          byte_off: 2'd0
        };
      end else begin
        memory_state <= '{
          pc: execute_state.pc,
          insn: execute_state.insn,
          cycle_status: execute_state.cycle_status,
          we: x_we,
          rd: execute_state.rd,
          rd_data: x_wdata,
          is_load: (execute_state.opcode == OpcodeLoad),
          is_store: (execute_state.opcode == OpcodeStore),
          load_funct3: execute_state.funct3,
          store_data: x_rs2_data,
          rs2: execute_state.rs2,
          byte_off: (execute_state.opcode == OpcodeLoad) ? x_ls_addr[1:0] : x_ls_addr_s[1:0]
        };
      end
    end
    wire [255:0] m_disasm;
    Disasm #(
        .PREFIX("M")
    ) disasm_1memory (
        .insn  (memory_state.insn),
        .disasm(m_disasm)
    );

  logic [`REG_SIZE] wb_rd_data_mux;
  always_comb begin
    wb_rd_data_mux = memory_state.rd_data;
    if (memory_state.is_load) begin
      unique case (memory_state.load_funct3)
        3'b000:
          wb_rd_data_mux = {
            {24{load_data_from_dmem[memory_state.byte_off * 8 + 7]}},
            load_data_from_dmem[memory_state.byte_off * 8 +: 8]
          };
        3'b001:
          wb_rd_data_mux = {
            {16{load_data_from_dmem[memory_state.byte_off * 8 + 15]}},
            load_data_from_dmem[memory_state.byte_off * 8 +: 16]
          };
        3'b010: wb_rd_data_mux = load_data_from_dmem;
        3'b100: wb_rd_data_mux = {24'd0, load_data_from_dmem[memory_state.byte_off * 8 +: 8]};
        3'b101: wb_rd_data_mux = {16'd0, load_data_from_dmem[memory_state.byte_off * 8 +: 16]};
        default: wb_rd_data_mux = memory_state.rd_data;
      endcase
    end
  end

  // WRITEBACK STAGE
  logic [`REG_SIZE] m_wm_store_data;
  always_comb begin
    m_wm_store_data = memory_state.store_data;
    if (writeback_state.we && writeback_state.rd != 5'd0 && writeback_state.rd == memory_state.rs2)
      m_wm_store_data = writeback_state.rd_data;
  end

    always_ff @(posedge clk) begin
      if (rst) begin
        writeback_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_RESET,
          we: 0,
          rd: 0,
          rd_data: 0
        };
      end else begin
        begin
          writeback_state <= '{
            pc: memory_state.pc,
            insn: memory_state.insn,
            cycle_status: memory_state.cycle_status,
            we: memory_state.we,
            rd: memory_state.rd,
            rd_data: wb_rd_data_mux
          };
        end
      end
    end
    wire [255:0] w_disasm;
    Disasm #(
        .PREFIX("W")
    ) disasm_1writeback (
        .insn  (writeback_state.insn),
        .disasm(w_disasm)
    );

    logic [`REG_SIZE] store_data_next;
    logic [`REG_SIZE] addr_to_dmem_next;
    logic [3:0] store_we_next;
    
    always_comb begin
      addr_to_dmem_next = 32'd0;
      store_we_next = 4'd0;
      store_data_next = 32'd0;
      if (memory_state.is_load) begin
        addr_to_dmem_next = memory_state.rd_data;
      end else if (memory_state.is_store) begin
        addr_to_dmem_next = memory_state.rd_data;
        unique case (memory_state.load_funct3)
          3'b000: begin
            store_we_next = 4'b0001 << memory_state.byte_off;
            store_data_next = {24'd0, m_wm_store_data[7:0]} << (memory_state.byte_off * 8);
          end
          3'b001: begin
            store_we_next = 4'b0011 << memory_state.byte_off;
            store_data_next = {16'd0, m_wm_store_data[15:0]} << (memory_state.byte_off * 8);
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

    assign halt = (writeback_state.insn == 32'h0000_0073);

    assign trace_completed_pc = writeback_state.pc;
    assign trace_completed_insn = writeback_state.insn;
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

`ifdef SYNTHESIS
  initial begin
    $readmemh("mem_initial_contents.hex", mem_array);
  end
`endif



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

  // This wire is set by cocotb to the name of the currently-running test, to make it easier
  // to see what is going on in the waveforms.
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
