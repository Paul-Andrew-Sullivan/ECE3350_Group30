// ECE:3350 SISC computer project
// finite state machine

`timescale 1ns/100ps

module ctrl (clk, rst_f, opcode, mm, stat, rf_we, alu_op, wb_sel);

  /* Declare the ports listed above as inputs or outputs.  Note that this is
     only the signals for part 1.  You will be adding signals for parts 2,
     2, and 4. */
  
  input clk, rst_f;
  input [3:0] opcode, mm, stat;
  output reg rf_we, wb_sel;
  output reg [3:0] alu_op;
  
  // state parameter declarations
  
  parameter start0 = 0, start1 = 1, fetch = 2, decode = 3, execute = 4, mem = 5, writeback = 6;
   
  // opcode parameter declarations
  
  parameter NOOP = 0, REG_OP = 1, REG_IM = 2, SWAP = 3, BRA = 4, BRR = 5, BNE = 6, BNR = 7;
  parameter JPA = 8, JPR = 9, LOD = 10, STR = 11, CALL = 12, RET = 13, HLT = 15;
	
  // addressing modes
  
  parameter AM_IMM = 8;

  // state register and next state signal
  
  reg [2:0]  present_state, next_state;

  // initial procedure to initialize the present state to 'start0'.

  initial
    present_state = start0;

  /* Procedure that progresses the fsm to the next state on the positive edge of 
     the clock, OR resets the state to 'start1' on the negative edge of rst_f. 
     Notice that the computer is reset when rst_f is low, not high. */

  always @(posedge clk, negedge rst_f)
  begin
    if (rst_f == 1'b0)
      present_state <= start1;
    else
      present_state <= next_state;
  end
  
  /* The following combinational procedure determines the next state of the fsm. */

  always @(present_state, rst_f)
  begin
    case(present_state)
      start0:
        next_state = start1;
      start1:
	  if (rst_f == 1'b0) 
        next_state = start1;
	 else
         next_state = fetch;
      fetch:
        next_state = decode;
      decode:
        next_state = execute;
      execute:
        next_state = mem;
      mem:
        next_state = writeback;
      writeback:
        next_state = fetch;
      default:
        next_state = start1;
    endcase
  end

  always @(present_state, opcode)
  begin

  /* TODO: Generate combinational signals based on the FSM states and inputs. For Parts 2, 3 and 4 you will
       add the new control signals here. */
	// default values for register file, writeback select, alu op.
    rf_we = 1'b0; // By default, do not write to the register file
    wb_sel = 1'b0; // By default, select mux input 0 for writeback
    alu_op = 4'b0000; // For part 1 this could also work with only 3 bits

    case (present_state) 
	  execute, mem: // If present state is either execute or mem, check opcode
      begin
        case (opcode) // Set alu_op based on the the instruction opcode. default is just 0000
          REG_OP: alu_op = 4'b0001;
          REG_IM: alu_op = 4'b0011;
          default: alu_op = 4'b0000;
        endcase
      end

      writeback: //if present state is writeback, check opcode
      begin
        case (opcode) 
          REG_OP, REG_IM: //If opcode is REG_OP or REG_IM, set register file write enable and writeback select accordingly
          begin
            rf_we = 1'b1;
            wb_sel = 1'b0;
          end
          default: //If opcode is neither, set rf_we and wb_sel to 0
          begin
            rf_we = 1'b0;
            wb_sel = 1'b0;
          end
        endcase
      end								  
    endcase

  end

// Halt on HLT instruction
  
  always @ (opcode)
  begin
    if (opcode == HLT)
    begin 
      #5 $display ("Halt."); //Delay 5 ns so $monitor will print the halt instruction
      $stop;
    end
  end
    
  
endmodule