// ECE:3350 SISC computer project
// Paul Sullivan, Daniel Marshall

`timescale 1ns/100ps

module ctrl (clk, rst_f, opcode, mm, stat, rf_we, alu_op, wb_sel,
             ir_load, pc_write, pc_sel, pc_rst, br_sel);

  /* Part 1 ports are carried forward unchanged. Part 2 adds five new
     output signals to support instruction fetch and branch execution.
     mm and stat are read during decode to decide if a branch is taken. */

  input clk, rst_f;              // clock and active-low reset
  input [3:0] opcode, mm, stat;  // opcode from IR, condition code field, status register
  output reg rf_we, wb_sel;      // register file write enable and writeback mux select
  output reg [3:0] alu_op;       // tells the ALU which operation to perform

  // Part 2 output signals added for instruction fetch and branch control

  output reg ir_load;  // when 1, the IR latches the instruction from memory
  output reg pc_write; // when 1, the PC saves its computed next value
  output reg pc_sel;   // 0 = use PC+1 as next address, 1 = use the branch target
  output reg pc_rst;   // when 1, forces the PC to hold 0x0000
  output reg br_sel;   // 0 = relative branch target, 1 = absolute branch target

  // state parameter declarations

  parameter start0 = 0, start1 = 1, fetch = 2, decode = 3, execute = 4, mem = 5, writeback = 6; // the seven FSM states

  // opcode parameter declarations

  parameter NOOP = 0, REG_OP = 1, REG_IM = 2, SWAP = 3, BRA = 4, BRR = 5, BNE = 6, BNR = 7;
  parameter JPA = 8, JPR = 9, LOD = 10, STR = 11, CALL = 12, RET = 13, HLT = 15;

  // addressing modes

  parameter AM_IMM = 8; // immediate addressing mode constant, used in later parts

  // state register and next state signal

  reg [2:0]  present_state, next_state; // hold the current and upcoming FSM states

  // initial procedure to initialize the present state to 'start0'

  initial
    present_state = start0; // simulation begins here before the first clock edge

  /* Procedure that progresses the FSM to the next state on the positive edge
     of the clock, OR resets the state to 'start1' on the negative edge of
     rst_f. The processor is in reset when rst_f is low, not high. */

  always @(posedge clk, negedge rst_f)
  begin
    if (rst_f == 1'b0)        // reset is active low, jump back immediately
      present_state <= start1;
    else                      // normal operation, step forward to next_state
      present_state <= next_state;
  end

  /* The following combinational procedure determines the next state of the FSM.
     The machine follows a fixed cycle: fetch, decode, execute, mem, writeback,
     then back to fetch. It holds in start1 until reset is released. */

  always @(present_state, rst_f)
  begin
    case(present_state)
      start0:                    // very first state on power-up
        next_state = start1;
      start1:                    // stays here while rst_f is low
	    if (rst_f == 1'b0) 
          next_state = start1;   // still in reset, keep waiting
	    else
          next_state = fetch;    // reset released, start running
      fetch:                     // reading an instruction from memory
        next_state = decode;
      decode:                    // figuring out what the instruction does
        next_state = execute;
      execute:                   // running the ALU
        next_state = mem;
      mem:                       // reserved for memory access in part 3
        next_state = writeback;
      writeback:                 // writing the result back to the register file
        next_state = fetch;
      default:                   // unknown state, reset to be safe
        next_state = start1;
    endcase
  end

  /* This combinational procedure generates all output control signals based on
     the current FSM state and the instruction being executed. All signals are
     set to safe defaults first, then overridden only in the states where they
     need to be active. mm and stat are in the sensitivity list so that branch
     decisions react immediately when the status register value changes. */

  always @(present_state, opcode, mm, stat)
  begin

    // default values for all control signals, keeps things safe between states
    rf_we    = 1'b0;    // do not write to the register file
    wb_sel   = 1'b0;    // point writeback mux at the ALU result
    alu_op   = 4'b0000; // ALU does nothing by default
    ir_load  = 1'b0;    // do not load the instruction register
    pc_write = 1'b0;    // do not update the program counter
    pc_sel   = 1'b0;    // select PC+1 as the default next address
    pc_rst   = 1'b0;    // do not hold the program counter at zero
    br_sel   = 1'b0;    // default to relative branch mode

    case (present_state)

      start1: // hold the PC frozen at 0x0000 for the entire duration of reset
      begin
        pc_rst = 1'b1; // freeze program counter at address zero
      end

      fetch: // load the instruction sitting at the current PC, then advance PC
      begin
        ir_load  = 1'b1; // latch the instruction memory output into the IR
        pc_write = 1'b1; // save the next PC value on this rising clock edge
        pc_sel   = 1'b0; // choose PC+1 as that next value, not a branch address
      end

      decode: // evaluate branch conditions and redirect the PC if a branch is taken
      begin
        /* The branch unit always computes a potential target address from
           the immediate field. We choose whether to actually use it by
           checking if the condition code bits in mm match the status flags
           in stat. If no branch fires, the PC keeps the PC+1 value that
           was already written during the fetch state, so nothing extra is needed. */
        case (opcode)

          BRA: // taken if (CC & STAT) != 0, jumps to an absolute address
          begin
            br_sel = 1'b1; // absolute mode: target address = 0 + immediate
            if ((mm & stat) != 4'b0000) // at least one matching flag is set
            begin
              pc_sel   = 1'b1; // point the PC mux at the computed branch target
              pc_write = 1'b1; // save that target address on the next clock edge
            end
          end

          BRR: // taken if (CC & STAT) != 0, jumps to a PC-relative address
          begin
            br_sel = 1'b0; // relative mode: target = (PC+1) + immediate
            if ((mm & stat) != 4'b0000) // same condition test as BRA
            begin
              pc_sel   = 1'b1;
              pc_write = 1'b1;
            end
          end

          BNE: // taken if (CC & STAT) == 0, jumps to an absolute address
          begin
            /* When mm = 0000 this branch is always taken, because
               (0000 & anything) is always 0000. That makes BNE #0
               work as an unconditional jump to any absolute address. */
            br_sel = 1'b1; // absolute mode
            if ((mm & stat) == 4'b0000) // no flagged condition is currently set
            begin
              pc_sel   = 1'b1;
              pc_write = 1'b1;
            end
          end

          BNR: // taken if (CC & STAT) == 0, jumps to a PC-relative address
          begin
            br_sel = 1'b0; // relative mode
            if ((mm & stat) == 4'b0000) // same condition test as BNE
            begin
              pc_sel   = 1'b1;
              pc_write = 1'b1;
            end
          end

          default: ; // not a branch instruction, nothing to do in decode
        endcase
      end

      execute, mem: // set alu_op so the ALU runs the right operation
      begin
        case (opcode) // only REG_OP and REG_IM actually use the ALU here
          REG_OP: alu_op = 4'b0001; // register-register: Rsa <funct> Rsb, update status
          REG_IM: alu_op = 4'b0011; // register-immediate: Rsa <funct> imm, update status
          default: alu_op = 4'b0000; // all other instructions leave the ALU idle
        endcase
      end

      writeback: // if present state is writeback, check opcode to decide what to write
      begin
        case (opcode)
          REG_OP, REG_IM: // these two types produce a result that goes into a register
          begin
            rf_we  = 1'b1; // enable the write port on the register file
            wb_sel = 1'b0; // route the ALU result into write_data, not a memory value
          end
          default: // everything else does not write back to the register file
          begin
            rf_we  = 1'b0;
            wb_sel = 1'b0;
          end
        endcase
      end

      default: ; // start0 or unknown state, all signals stay at their default values

    endcase

  end

// Halt on HLT instruction

  always @ (opcode)
  begin
    if (opcode == HLT) // opcode 0xF signals the end of the program
    begin
      #5 $display ("Halt."); // delay 5 ns so $monitor prints the halt instruction first
      $stop;
    end
  end


endmodule