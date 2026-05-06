// ECE:3350 SISC computer project
// Paul Sullivan, Daniel Marshall

`timescale 1ns/100ps

module ctrl (clk, rst_f, opcode, mm, stat, rf_we, alu_op, wb_sel,
             ir_load, pc_write, pc_sel, pc_rst, br_sel,
             dm_we, rb_sel, addr_sel);

  input clk, rst_f;
  input [3:0] opcode, mm, stat;
  output reg rf_we, wb_sel;
  output reg [3:0] alu_op;
  output reg ir_load, pc_write, pc_sel, pc_rst, br_sel;

  // Part 3 control outputs
  output reg dm_we;    // assert during mem to write data memory (stores)
  output reg rb_sel;   // 0=Rt, 1=Rd routed to RF second read port (store data)
  output reg addr_sel; // 0=immediate, 1=alu_result as DM effective address

  parameter start0 = 0, start1 = 1, fetch = 2, decode = 3, execute = 4, mem = 5, writeback = 6;

  parameter NOOP = 0, REG_OP = 1, REG_IM = 2, SWAP = 3, BRA = 4, BRR = 5, BNE = 6, BNR = 7;
  parameter JPA = 8, JPR = 9, LOD = 10, STR = 11, CALL = 12, RET = 13, HLT = 15;

  parameter AM_IMM = 8; // MFF bit 3 set = indexed addressing mode

  reg [2:0] present_state, next_state;

  initial
    present_state = start0;

  always @(posedge clk, negedge rst_f)
  begin
    if (rst_f == 1'b0)
      present_state <= start1;
    else
      present_state <= next_state;
  end

  always @(present_state, rst_f)
  begin
    case (present_state)
      start0:    next_state = start1;
      start1:    if (rst_f == 1'b0) next_state = start1; else next_state = fetch;
      fetch:     next_state = decode;
      decode:    next_state = execute;
      execute:   next_state = mem;
      mem:       next_state = writeback;
      writeback: next_state = fetch;
      default:   next_state = start1;
    endcase
  end

  always @(present_state, opcode, mm, stat)
  begin
    rf_we    = 1'b0;
    wb_sel   = 1'b0;
    alu_op   = 4'b0000;
    ir_load  = 1'b0;
    pc_write = 1'b0;
    pc_sel   = 1'b0;
    pc_rst   = 1'b0;
    br_sel   = 1'b0;
    dm_we    = 1'b0;
    rb_sel   = 1'b0;
    addr_sel = 1'b0;

    case (present_state)

      start1:
      begin
        pc_rst = 1'b1;
      end

      fetch:
      begin
        ir_load  = 1'b1;
        pc_write = 1'b1;
        pc_sel   = 1'b0;
      end

      decode:
      begin
        case (opcode)
          BRA:
          begin
            br_sel = 1'b1;
            if ((mm & stat) != 4'b0000) begin pc_sel = 1'b1; pc_write = 1'b1; end
          end
          BRR:
          begin
            br_sel = 1'b0;
            if ((mm & stat) != 4'b0000) begin pc_sel = 1'b1; pc_write = 1'b1; end
          end
          BNE:
          begin
            br_sel = 1'b1;
            if ((mm & stat) == 4'b0000) begin pc_sel = 1'b1; pc_write = 1'b1; end
          end
          BNR:
          begin
            br_sel = 1'b0;
            if ((mm & stat) == 4'b0000) begin pc_sel = 1'b1; pc_write = 1'b1; end
          end
          // Route Rd to the RF second read port so it's latched before execute
          STR: rb_sel = 1'b1;
          default: ;
        endcase
      end

      execute:
      begin
        case (opcode)
          REG_OP: alu_op = 4'b0001;
          REG_IM: alu_op = 4'b0011;
          LOD, STR:
          begin
            // Indexed mode (MFF bit 3 set): ALU computes Rs + sign_ext(imm)
            // alu_op 4'b0100 = Rsa + imm_ext, no status update
            if (mm[3]) alu_op = 4'b0100;
            // Keep Rd on the RF second read port through the execute->mem latch
            if (opcode == STR) rb_sel = 1'b1;
          end
          default: alu_op = 4'b0000;
        endcase
      end

      mem:
      begin
        case (opcode)
          REG_OP: alu_op = 4'b0001; // carry forward for consistency
          REG_IM: alu_op = 4'b0011;
          STR:
          begin
            dm_we    = 1'b1;
            addr_sel = mm[3]; // 1=indexed (STX), 0=absolute (STA)
            rb_sel   = 1'b1;  // Rd must be on rsb when dm_we falls to trigger write
          end
          LOD:
          begin
            addr_sel = mm[3]; // 1=indexed (LDX), 0=absolute (LDA)
          end
          default: ;
        endcase
      end

      writeback:
      begin
        case (opcode)
          REG_OP, REG_IM:
          begin
            rf_we  = 1'b1;
            wb_sel = 1'b0; // ALU result
          end
          LOD:
          begin
            rf_we  = 1'b1;
            wb_sel = 1'b1; // DM read_data
          end
          default: begin rf_we = 1'b0; wb_sel = 1'b0; end
        endcase
      end

      default: ;

    endcase
  end

  always @(opcode)
  begin
    if (opcode == HLT)
    begin
      #5 $display("Halt.");
      $stop;
    end
  end

endmodule
