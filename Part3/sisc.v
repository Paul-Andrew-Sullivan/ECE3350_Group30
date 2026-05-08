// ECE:3350 SISC processor project
// Paul Sullivan, Daniel Marshall

`timescale 1ns/100ps

module sisc (clk, rst_f);

  input clk, rst_f;

  // Part 1 wires
  wire rf_we;
  wire wb_sel;
  wire [3:0] alu_op;
  wire [31:0] rsa, rsb;
  wire [31:0] alu_result;
  wire [31:0] write_data;
  wire [3:0]  alu_stat;
  wire [3:0]  stat_en;
  wire [3:0]  stat_out;

  // Part 2 wires
  wire ir_load, pc_write, pc_sel, pc_rst, br_sel;
  wire [31:0] instr;
  wire [15:0] pc_out;
  wire [15:0] br_addr;
  wire [31:0] im_data;

  // Part 3 wires
  wire dm_we;
  wire rb_sel;          // selects Rd (1) or Rt (0) as RF second read address
  wire addr_sel;        // selects ALU result (1) or immediate (0) as DM address
  wire wb_addr_sel;     // selects Rs (1) or Rd (0) as RF write address for SWAP
  wire [31:0] dm_read_data;
  wire [15:0] dm_addr;
  wire [3:0]  rb_addr;  // mux4 output: second RF read address
  wire [3:0]  rf_write_addr; // mux: Rd normally, Rs for SWAP second write

  ctrl u1 (clk, rst_f, instr[31:28], instr[27:24], stat_out,
           rf_we, alu_op, wb_sel,
           ir_load, pc_write, pc_sel, pc_rst, br_sel,
           dm_we, rb_sel, addr_sel, wb_addr_sel);

  // mux4 routes Rd address to the RF second port for store instructions
  mux4 u12 (instr[15:12], instr[23:20], rb_sel, rb_addr);

  // wb_addr_sel=1 during SWAP writeback2 to write old Rd value into Rs
  assign rf_write_addr = wb_addr_sel ? instr[19:16] : instr[23:20];

  rf u2 (clk, instr[19:16], rb_addr, rf_write_addr, write_data, rf_we, rsa, rsb);

  alu u3 (clk, rsa, rsb, instr[15:0], stat_out[3], alu_op, instr[27:24], alu_result, alu_stat, stat_en);

  statreg u4 (clk, alu_stat, stat_en, stat_out);

  // sel=0: ALU result (REG_OP/REG_IM), sel=1: DM read data (LOD)
  mux32 u5 (alu_result, dm_read_data, wb_sel, write_data);

  im u6 (pc_out, im_data);

  br u7 (pc_out, instr[15:0], br_sel, br_addr);

  ir u9 (clk, ir_load, im_data, instr);

  pc u10 (clk, br_addr, pc_sel, pc_write, pc_rst, pc_out);

  // sel=0: instr[15:0] (absolute), sel=1: alu_result[15:0] (indexed Rs+imm)
  mux16 u13 (instr[15:0], alu_result[15:0], addr_sel, dm_addr);

  // dm read and write share the same effective address from mux16
  // rsb carries Rd value (rb_sel=1 during mem) as the word to store
  dm u11 (dm_addr, dm_addr, rsb, dm_we, dm_read_data);

  initial begin
    $monitor($time," IR=%h PC=%h R1=%h R2=%h R3=%h R4=%h ALU_OP=%h DM_WE=%b WB_SEL=%b ADDR_SEL=%b",
             instr, pc_out,
             u2.ram_array[1], u2.ram_array[2], u2.ram_array[3], u2.ram_array[4],
             alu_op, dm_we, wb_sel, addr_sel);
  end

endmodule
