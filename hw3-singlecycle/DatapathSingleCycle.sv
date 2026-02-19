`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31:0

// insns are 32 bits in RV32IM
`define INSN_SIZE 31:0

// RV opcodes are 7 bits
`define OPCODE_SIZE 6:0

`include "../hw2a-divider/DividerUnsigned.sv"
/* verilator lint_off UNOPTFLAT */
`include "../hw2b-cla/CarryLookaheadAdder.sv"
/* verilator lint_on UNOPTFLAT */
`include "cycle_status.sv"

module RegFile (
    input  logic [ 4:0] rd,
    input  logic [`REG_SIZE] rd_data,
    input  logic [ 4:0] rs1,
    output logic [`REG_SIZE] rs1_data,
    input  logic [ 4:0] rs2,
    output logic [`REG_SIZE] rs2_data,
    input  logic clk,
    input  logic we,
    input  logic rst
);
  localparam int NumRegs = 32;
  logic [`REG_SIZE] regs[NumRegs];

  always_comb begin
    rs1_data = regs[rs1];
    rs2_data = regs[rs2];
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < NumRegs; i++) regs[i] <= 32'b0;
    end else if (we && (rd != 5'd0)) begin
      regs[rd] <= rd_data;
    end
  end
endmodule


module DatapathSingleCycle (
    input  wire                clk,
    input  wire                rst,
    output logic               halt,
    output logic [`REG_SIZE]   pc_to_imem,
    input  wire  [`INSN_SIZE]  insn_from_imem,
    output logic [`REG_SIZE]   addr_to_dmem,
    input  logic [`REG_SIZE]   load_data_from_dmem,
    output logic [`REG_SIZE]   store_data_to_dmem,
    output logic [3:0]         store_we_to_dmem,
    output logic [`REG_SIZE]   trace_completed_pc,
    output logic [`INSN_SIZE]  trace_completed_insn,
    output cycle_status_e      trace_completed_cycle_status
);

  //--------------------------------------------------------------------------
  // Instruction decode
  //--------------------------------------------------------------------------
  wire [6:0] insn_funct7  = insn_from_imem[31:25];
  wire [4:0] insn_rs2     = insn_from_imem[24:20];
  wire [4:0] insn_rs1     = insn_from_imem[19:15];
  wire [2:0] insn_funct3  = insn_from_imem[14:12];
  wire [4:0] insn_rd      = insn_from_imem[11:7];
  wire [`OPCODE_SIZE] insn_opcode = insn_from_imem[6:0];

  // Immediate formats
  wire [11:0] imm_i      = insn_from_imem[31:20];
  wire [ 4:0] imm_shamt  = insn_from_imem[24:20];

  wire [11:0] imm_s;
  assign imm_s[11:5] = insn_funct7;
  assign imm_s[4:0]  = insn_rd;

  wire [12:0] imm_b;
  assign {imm_b[12], imm_b[10:5]} = insn_funct7;
  assign {imm_b[4:1], imm_b[11]}  = insn_rd;
  assign imm_b[0] = 1'b0;

  wire [20:0] imm_j;
  assign {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} =
         {insn_from_imem[31:12], 1'b0};

  wire [`REG_SIZE] imm_i_sext = {{20{imm_i[11]}},  imm_i};
  wire [`REG_SIZE] imm_s_sext = {{20{imm_s[11]}},  imm_s};
  wire [`REG_SIZE] imm_b_sext = {{19{imm_b[12]}},  imm_b};
  wire [`REG_SIZE] imm_j_sext = {{11{imm_j[20]}},  imm_j};

  //--------------------------------------------------------------------------
  // Opcode constants
  //--------------------------------------------------------------------------
  localparam bit [`OPCODE_SIZE] OpLoad    = 7'b00_000_11;
  localparam bit [`OPCODE_SIZE] OpStore   = 7'b01_000_11;
  localparam bit [`OPCODE_SIZE] OpBranch  = 7'b11_000_11;
  localparam bit [`OPCODE_SIZE] OpJalr    = 7'b11_001_11;
  localparam bit [`OPCODE_SIZE] OpMiscMem = 7'b00_011_11;
  localparam bit [`OPCODE_SIZE] OpJal     = 7'b11_011_11;
  localparam bit [`OPCODE_SIZE] OpRegImm  = 7'b00_100_11;
  localparam bit [`OPCODE_SIZE] OpRegReg  = 7'b01_100_11;
  localparam bit [`OPCODE_SIZE] OpEnviron = 7'b11_100_11;
  localparam bit [`OPCODE_SIZE] OpAuipc   = 7'b00_101_11;
  localparam bit [`OPCODE_SIZE] OpLui     = 7'b01_101_11;

  //--------------------------------------------------------------------------
  // Instruction decode: one-hot signals derived combinatorially
  //--------------------------------------------------------------------------
  // Funct7 shorthands
  wire f7_0    = (insn_funct7 == 7'd0);
  wire f7_sub  = (insn_funct7 == 7'b0100000);
  wire f7_mext = (insn_funct7 == 7'd1);

  // Branch
  wire insn_beq  = (insn_opcode == OpBranch) & (insn_funct3 == 3'b000);
  wire insn_bne  = (insn_opcode == OpBranch) & (insn_funct3 == 3'b001);
  wire insn_blt  = (insn_opcode == OpBranch) & (insn_funct3 == 3'b100);
  wire insn_bge  = (insn_opcode == OpBranch) & (insn_funct3 == 3'b101);
  wire insn_bltu = (insn_opcode == OpBranch) & (insn_funct3 == 3'b110);
  wire insn_bgeu = (insn_opcode == OpBranch) & (insn_funct3 == 3'b111);

  // Load
  wire insn_lb  = (insn_opcode == OpLoad) & (insn_funct3 == 3'b000);
  wire insn_lh  = (insn_opcode == OpLoad) & (insn_funct3 == 3'b001);
  wire insn_lw  = (insn_opcode == OpLoad) & (insn_funct3 == 3'b010);
  wire insn_lbu = (insn_opcode == OpLoad) & (insn_funct3 == 3'b100);
  wire insn_lhu = (insn_opcode == OpLoad) & (insn_funct3 == 3'b101);

  // Store
  wire insn_sb = (insn_opcode == OpStore) & (insn_funct3 == 3'b000);
  wire insn_sh = (insn_opcode == OpStore) & (insn_funct3 == 3'b001);
  wire insn_sw = (insn_opcode == OpStore) & (insn_funct3 == 3'b010);

  // RegImm
  wire insn_addi  = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b000);
  wire insn_slti  = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b010);
  wire insn_sltiu = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b011);
  wire insn_xori  = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b100);
  wire insn_ori   = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b110);
  wire insn_andi  = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b111);
  wire insn_slli  = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b001) & f7_0;
  wire insn_srli  = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b101) & f7_0;
  wire insn_srai  = (insn_opcode == OpRegImm) & (insn_funct3 == 3'b101) & f7_sub;

  // RegReg – base ISA
  wire insn_add  = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b000) & f7_0;
  wire insn_sub  = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b000) & f7_sub;
  wire insn_sll  = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b001) & f7_0;
  wire insn_slt  = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b010) & f7_0;
  wire insn_sltu = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b011) & f7_0;
  wire insn_xor  = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b100) & f7_0;
  wire insn_srl  = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b101) & f7_0;
  wire insn_sra  = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b101) & f7_sub;
  wire insn_or   = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b110) & f7_0;
  wire insn_and  = (insn_opcode == OpRegReg) & (insn_funct3 == 3'b111) & f7_0;

  // RegReg – M extension
  wire insn_mul    = (insn_opcode == OpRegReg) & f7_mext & (insn_funct3 == 3'b000);
  wire insn_mulh   = (insn_opcode == OpRegReg) & f7_mext & (insn_funct3 == 3'b001);
  wire insn_mulhsu = (insn_opcode == OpRegReg) & f7_mext & (insn_funct3 == 3'b010);
  wire insn_mulhu  = (insn_opcode == OpRegReg) & f7_mext & (insn_funct3 == 3'b011);
  wire insn_div    = (insn_opcode == OpRegReg) & f7_mext & (insn_funct3 == 3'b100);
  wire insn_divu   = (insn_opcode == OpRegReg) & f7_mext & (insn_funct3 == 3'b101);
  wire insn_rem    = (insn_opcode == OpRegReg) & f7_mext & (insn_funct3 == 3'b110);
  wire insn_remu   = (insn_opcode == OpRegReg) & f7_mext & (insn_funct3 == 3'b111);

  // Misc
  wire insn_lui   = (insn_opcode == OpLui);
  wire insn_auipc = (insn_opcode == OpAuipc);
  wire insn_jal   = (insn_opcode == OpJal);
  wire insn_jalr  = (insn_opcode == OpJalr);
  wire insn_ecall = (insn_opcode == OpEnviron) & (insn_from_imem[31:7] == 25'd0);
  wire insn_fence = (insn_opcode == OpMiscMem);

  //--------------------------------------------------------------------------
  // Disassembler (simulation only)
  //--------------------------------------------------------------------------
`ifndef SYNTHESIS
  `include "RvDisassembler.sv"
  string disasm_string;
  always_comb disasm_string = rv_disasm(insn_from_imem);
  wire [(8*32)-1:0] disasm_wire;
  genvar i;
  for (i = 0; i < 32; i = i + 1) begin : gen_disasm
    assign disasm_wire[(((i+1))*8)-1:((i)*8)] = disasm_string[31-i];
  end
`endif

  //--------------------------------------------------------------------------
  // Program counter
  //--------------------------------------------------------------------------
  logic [`REG_SIZE] pcNext, pcCurrent;
  always_ff @(posedge clk) begin
    pcCurrent <= rst ? 32'd0 : pcNext;
  end
  assign pc_to_imem = pcCurrent;

  // Cycle / insn counters
  logic [`REG_SIZE] cycles_current, num_insns_current;
  always_ff @(posedge clk) begin
    if (rst) begin
      cycles_current    <= 0;
      num_insns_current <= 0;
    end else begin
      cycles_current    <= cycles_current + 1;
      num_insns_current <= num_insns_current + 1;
    end
  end

  //--------------------------------------------------------------------------
  // Register file
  //--------------------------------------------------------------------------
  wire [`REG_SIZE] rs1_data, rs2_data;
  logic            rf_we;
  logic [`REG_SIZE] rd_data;

  RegFile rf (
      .clk    (clk),
      .rst    (rst),
      .we     (rf_we),
      .rd     (insn_rd),
      .rd_data(rd_data),
      .rs1    (insn_rs1),
      .rs2    (insn_rs2),
      .rs1_data(rs1_data),
      .rs2_data(rs2_data)
  );

  //--------------------------------------------------------------------------
  // CLA adder
  //--------------------------------------------------------------------------
  logic [31:0] cla_a, cla_b;
  logic        cla_cin;
  logic [31:0] cla_sum;

  CarryLookaheadAdder cla (
      .a  (cla_a),
      .b  (cla_b),
      .cin(cla_cin),
      .sum(cla_sum)
  );

  //--------------------------------------------------------------------------
  // SINGLE multiplier  (33-bit signed × 33-bit signed → 66-bit)
  // Covers mul / mulh / mulhsu / mulhu all from one multiply unit.
  //--------------------------------------------------------------------------
  logic [32:0] mul_op_a, mul_op_b;
  wire  [65:0] mul_result;
  assign mul_result = $signed(mul_op_a) * $signed(mul_op_b);

  //--------------------------------------------------------------------------
  // SINGLE divider  (shared between signed and unsigned divide/remainder)
  // For signed ops we pass absolute values and fix signs afterwards.
  //--------------------------------------------------------------------------
  logic [31:0] div_dividend, div_divisor;
  wire  [31:0] div_quotient, div_remainder;

  // Absolute values (cheap: just invert+1 when MSB set)
  wire [31:0] rs1_abs = rs1_data[31] ? (~rs1_data + 1) : rs1_data;
  wire [31:0] rs2_abs = rs2_data[31] ? (~rs2_data + 1) : rs2_data;

  DividerUnsigned u_div (
      .i_dividend (div_dividend),
      .i_divisor  (div_divisor),
      .o_quotient (div_quotient),
      .o_remainder(div_remainder)
  );

  //--------------------------------------------------------------------------
  // Main combinatorial datapath
  //--------------------------------------------------------------------------
  logic illegal_insn;
  logic [31:0] addr;          // effective address for load/store

  always_comb begin
    //-- safe defaults --
    illegal_insn       = 1'b0;
    halt               = 1'b0;
    rf_we              = 1'b0;
    rd_data            = 32'd0;
    pcNext             = pcCurrent + 32'd4;
    addr_to_dmem       = 32'd0;
    store_data_to_dmem = 32'd0;
    store_we_to_dmem   = 4'b0000;
    addr               = 32'd0;

    // CLA defaults (adder inputs)
    cla_a   = 32'd0;
    cla_b   = 32'd0;
    cla_cin = 1'b0;

    // Multiplier defaults: unsigned × unsigned (covers mul/mulhu)
    mul_op_a = {1'b0, rs1_data};
    mul_op_b = {1'b0, rs2_data};

    // Divider defaults: unsigned inputs
    div_dividend = rs1_data;
    div_divisor  = rs2_data;

    trace_completed_pc           = pcCurrent;
    trace_completed_insn         = insn_from_imem;
    trace_completed_cycle_status = CYCLE_NO_STALL;

    //----------------------------------------------------------------------
    unique case (insn_opcode)

      //--------------------------------------------------------------------
      // LUI
      //--------------------------------------------------------------------
      OpLui: begin
        rf_we   = 1'b1;
        rd_data = {insn_from_imem[31:12], 12'b0};
      end

      //--------------------------------------------------------------------
      // AUIPC
      //--------------------------------------------------------------------
      OpAuipc: begin
        rf_we   = 1'b1;
        rd_data = pcCurrent + {insn_from_imem[31:12], 12'b0};
      end

      //--------------------------------------------------------------------
      // OP-IMM
      //--------------------------------------------------------------------
      OpRegImm: begin
        rf_we = 1'b1;
        unique case (1'b1)
          insn_addi: begin
            cla_a   = rs1_data;
            cla_b   = imm_i_sext;
            cla_cin = 1'b0;
            rd_data = cla_sum;
          end
          insn_slti:  rd_data = ($signed(rs1_data) < $signed(imm_i_sext)) ? 32'b1 : 32'b0;
          insn_sltiu: rd_data = (rs1_data < imm_i_sext)                   ? 32'b1 : 32'b0;
          insn_xori:  rd_data = rs1_data ^ imm_i_sext;
          insn_ori:   rd_data = rs1_data | imm_i_sext;
          insn_andi:  rd_data = rs1_data & imm_i_sext;
          insn_slli:  rd_data = rs1_data << imm_shamt;
          insn_srli:  rd_data = rs1_data >> imm_shamt;
          insn_srai:  rd_data = $signed(rs1_data) >>> imm_shamt;
          default: begin
            rf_we        = 1'b0;
            illegal_insn = 1'b1;
          end
        endcase
      end

      //--------------------------------------------------------------------
      // OP (RegReg) – base ISA + M extension
      //--------------------------------------------------------------------
      OpRegReg: begin
        rf_we = 1'b1;
        unique case (1'b1)
          // --- Arithmetic ---
          insn_add: begin
            cla_a   = rs1_data;
            cla_b   = rs2_data;
            cla_cin = 1'b0;
            rd_data = cla_sum;
          end
          insn_sub: begin
            cla_a   = rs1_data;
            cla_b   = ~rs2_data;
            cla_cin = 1'b1;
            rd_data = cla_sum;
          end
          insn_sll:  rd_data = rs1_data << rs2_data[4:0];
          insn_slt:  rd_data = ($signed(rs1_data) < $signed(rs2_data)) ? 32'b1 : 32'b0;
          insn_sltu: rd_data = (rs1_data < rs2_data)                   ? 32'b1 : 32'b0;
          insn_xor:  rd_data = rs1_data ^ rs2_data;
          insn_srl:  rd_data = rs1_data >> rs2_data[4:0];
          insn_sra:  rd_data = $signed(rs1_data) >>> rs2_data[4:0];
          insn_or:   rd_data = rs1_data | rs2_data;
          insn_and:  rd_data = rs1_data & rs2_data;

          // --- M: multiply ---
          // mul  : lower 32 bits of unsigned product
          insn_mul: begin
            mul_op_a = {1'b0, rs1_data};
            mul_op_b = {1'b0, rs2_data};
            rd_data  = mul_result[31:0];
          end
          // mulh : upper 32 bits of signed × signed
          insn_mulh: begin
            mul_op_a = {rs1_data[31], rs1_data};
            mul_op_b = {rs2_data[31], rs2_data};
            rd_data  = mul_result[63:32];
          end
          // mulhsu: upper 32 bits of signed × unsigned
          insn_mulhsu: begin
            mul_op_a = {rs1_data[31], rs1_data};
            mul_op_b = {1'b0, rs2_data};
            rd_data  = mul_result[63:32];
          end
          // mulhu : upper 32 bits of unsigned × unsigned
          insn_mulhu: begin
            mul_op_a = {1'b0, rs1_data};
            mul_op_b = {1'b0, rs2_data};
            rd_data  = mul_result[63:32];
          end

          // --- M: divide (signed) ---
          insn_div: begin
            div_dividend = rs1_abs;
            div_divisor  = rs2_abs;
            if (rs2_data == 32'b0) begin
              rd_data = 32'hFFFF_FFFF;
            end else if (rs1_data == 32'h8000_0000 && rs2_data == 32'hFFFF_FFFF) begin
              rd_data = 32'h8000_0000;
            end else begin
              // negate if signs differ
              rd_data = (rs1_data[31] ^ rs2_data[31])
                        ? (~div_quotient + 1)
                        : div_quotient;
            end
          end

          // --- M: divide (unsigned) ---
          insn_divu: begin
            div_dividend = rs1_data;
            div_divisor  = rs2_data;
            rd_data = (rs2_data == 32'b0) ? 32'hFFFF_FFFF : div_quotient;
          end

          // --- M: remainder (signed) ---
          insn_rem: begin
            div_dividend = rs1_abs;
            div_divisor  = rs2_abs;
            if (rs2_data == 32'b0) begin
              rd_data = rs1_data;
            end else if (rs1_data == 32'h8000_0000 && rs2_data == 32'hFFFF_FFFF) begin
              rd_data = 32'b0;
            end else begin
              // sign of remainder follows dividend
              rd_data = rs1_data[31]
                        ? (~div_remainder + 1)
                        : div_remainder;
            end
          end

          // --- M: remainder (unsigned) ---
          insn_remu: begin
            div_dividend = rs1_data;
            div_divisor  = rs2_data;
            rd_data = (rs2_data == 32'b0) ? rs1_data : div_remainder;
          end

          default: begin
            illegal_insn = 1'b1;
            rf_we        = 1'b0;
          end
        endcase
      end

      //--------------------------------------------------------------------
      // BRANCH
      //--------------------------------------------------------------------
      OpBranch: begin
        logic take;
        take = 1'b0;
        unique case (1'b1)
          insn_beq:  take = (rs1_data == rs2_data);
          insn_bne:  take = (rs1_data != rs2_data);
          insn_blt:  take = ($signed(rs1_data) < $signed(rs2_data));
          insn_bge:  take = ($signed(rs1_data) >= $signed(rs2_data));
          insn_bltu: take = (rs1_data < rs2_data);
          insn_bgeu: take = (rs1_data >= rs2_data);
          default:   illegal_insn = 1'b1;
        endcase
        if (take) pcNext = pcCurrent + imm_b_sext;
      end

      //--------------------------------------------------------------------
      // JAL
      //--------------------------------------------------------------------
      OpJal: begin
        rf_we   = 1'b1;
        rd_data = pcCurrent + 32'd4;
        pcNext  = pcCurrent + imm_j_sext;
      end

      //--------------------------------------------------------------------
      // JALR
      //--------------------------------------------------------------------
      OpJalr: begin
        rf_we   = 1'b1;
        rd_data = pcCurrent + 32'd4;
        pcNext  = (rs1_data + imm_i_sext) & ~32'd1;
      end

      //--------------------------------------------------------------------
      // LOAD
      //--------------------------------------------------------------------
      OpLoad: begin
        rf_we        = 1'b1;
        addr         = rs1_data + imm_i_sext;
        addr_to_dmem = {addr[31:2], 2'b00};

        unique case (1'b1)
          insn_lb: begin
            unique case (addr[1:0])
              2'b00: rd_data = {{24{load_data_from_dmem[7]}},  load_data_from_dmem[7:0]};
              2'b01: rd_data = {{24{load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
              2'b10: rd_data = {{24{load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
              2'b11: rd_data = {{24{load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
            endcase
          end
          insn_lh: begin
            unique case (addr[1])
              1'b0: rd_data = {{16{load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
              1'b1: rd_data = {{16{load_data_from_dmem[31]}}, load_data_from_dmem[31:16]};
            endcase
          end
          insn_lw:  rd_data = load_data_from_dmem;
          insn_lbu: begin
            unique case (addr[1:0])
              2'b00: rd_data = {24'b0, load_data_from_dmem[7:0]};
              2'b01: rd_data = {24'b0, load_data_from_dmem[15:8]};
              2'b10: rd_data = {24'b0, load_data_from_dmem[23:16]};
              2'b11: rd_data = {24'b0, load_data_from_dmem[31:24]};
            endcase
          end
          insn_lhu: begin
            unique case (addr[1])
              1'b0: rd_data = {16'b0, load_data_from_dmem[15:0]};
              1'b1: rd_data = {16'b0, load_data_from_dmem[31:16]};
            endcase
          end
          default: begin
            rf_we        = 1'b0;
            illegal_insn = 1'b1;
          end
        endcase
      end

      //--------------------------------------------------------------------
      // STORE
      //--------------------------------------------------------------------
      OpStore: begin
        addr         = rs1_data + imm_s_sext;
        addr_to_dmem = {addr[31:2], 2'b00};

        unique case (1'b1)
          insn_sb: begin
            unique case (addr[1:0])
              2'b00: begin store_data_to_dmem = {24'b0,           rs2_data[7:0]};        store_we_to_dmem = 4'b0001; end
              2'b01: begin store_data_to_dmem = {16'b0, rs2_data[7:0], 8'b0};            store_we_to_dmem = 4'b0010; end
              2'b10: begin store_data_to_dmem = {8'b0,  rs2_data[7:0], 16'b0};           store_we_to_dmem = 4'b0100; end
              2'b11: begin store_data_to_dmem = {rs2_data[7:0],        24'b0};           store_we_to_dmem = 4'b1000; end
            endcase
          end
          insn_sh: begin
            unique case (addr[1])
              1'b0: begin store_data_to_dmem = {16'b0,      rs2_data[15:0]}; store_we_to_dmem = 4'b0011; end
              1'b1: begin store_data_to_dmem = {rs2_data[15:0], 16'b0};      store_we_to_dmem = 4'b1100; end
            endcase
          end
          insn_sw: begin
            store_data_to_dmem = rs2_data;
            store_we_to_dmem   = 4'b1111;
          end
          default: illegal_insn = 1'b1;
        endcase
      end

      //--------------------------------------------------------------------
      // SYSTEM (ecall → halt)
      //--------------------------------------------------------------------
      OpEnviron: begin
        if (insn_ecall) halt = 1'b1;
        else            illegal_insn = 1'b1;
      end

      //--------------------------------------------------------------------
      // MISC-MEM / FENCE (no-op)
      //--------------------------------------------------------------------
      OpMiscMem: begin
        if (!insn_fence) illegal_insn = 1'b1;
      end

      //--------------------------------------------------------------------
      default: illegal_insn = 1'b1;

    endcase
  end

endmodule


/* =========================================================================
 * MemorySingleCycle – unchanged from original
 * ========================================================================= */
module MemorySingleCycle #(
    parameter int NUM_WORDS = 512
) (
    input  wire             rst,
    input  wire             clock_mem,
    input  wire [`REG_SIZE] pc_to_imem,
    output logic [`INSN_SIZE] insn_from_imem,
    input  wire [`REG_SIZE] addr_to_dmem,
    output logic [`REG_SIZE] load_data_from_dmem,
    input  wire [`REG_SIZE] store_data_to_dmem,
    input  wire [3:0]       store_we_to_dmem
);
  logic [`REG_SIZE] mem_array[NUM_WORDS];

`ifdef SYNTHESIS
  initial begin
    $readmemh("mem_initial_contents.hex", mem_array);
  end
`endif

  always_comb begin
    assert (pc_to_imem[1:0]  == 2'b00);
    assert (addr_to_dmem[1:0] == 2'b00);
  end

  localparam int AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam int AddrLsb = 2;

  always @(posedge clock_mem) begin
    if (!rst) insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
  end

  always @(negedge clock_mem) begin
    if (!rst) begin
      if (store_we_to_dmem[0]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0]   <= store_data_to_dmem[7:0];
      if (store_we_to_dmem[1]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8]  <= store_data_to_dmem[15:8];
      if (store_we_to_dmem[2]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
      if (store_we_to_dmem[3]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
      load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
    end
  end
endmodule


/* =========================================================================
 * Processor – unchanged from original
 * ========================================================================= */
module Processor (
    input  wire               clock_proc,
    input  wire               clock_mem,
    input  wire               rst,
    output wire [`REG_SIZE]   trace_completed_pc,
    output wire [`INSN_SIZE]  trace_completed_insn,
    output cycle_status_e     trace_completed_cycle_status,
    output logic              halt
);
  wire [`REG_SIZE]  pc_to_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [`INSN_SIZE] insn_from_imem;
  wire [3:0]        mem_data_we;
  wire [(8*32)-1:0] test_case;

  MemorySingleCycle #(.NUM_WORDS(8192)) memory (
      .rst               (rst),
      .clock_mem         (clock_mem),
      .pc_to_imem        (pc_to_imem),
      .insn_from_imem    (insn_from_imem),
      .addr_to_dmem      (mem_data_addr),
      .load_data_from_dmem(mem_data_loaded_value),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem  (mem_data_we)
  );

  DatapathSingleCycle datapath (
      .clk                        (clock_proc),
      .rst                        (rst),
      .pc_to_imem                 (pc_to_imem),
      .insn_from_imem             (insn_from_imem),
      .addr_to_dmem               (mem_data_addr),
      .store_data_to_dmem         (mem_data_to_write),
      .store_we_to_dmem           (mem_data_we),
      .load_data_from_dmem        (mem_data_loaded_value),
      .trace_completed_pc         (trace_completed_pc),
      .trace_completed_insn       (trace_completed_insn),
      .trace_completed_cycle_status(trace_completed_cycle_status),
      .halt                       (halt)
  );
endmodule