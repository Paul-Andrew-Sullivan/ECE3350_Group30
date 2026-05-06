# ============================================================================
# ECE:3350 SISC Self-Test - ModelSim TCL Script
# ============================================================================
#
# Usage in ModelSim:
#   1. Place these files in your project directory alongside your .v files.
#   2. Open ModelSim and navigate to your project directory.
#   3. In the transcript:  source run_selftest.tcl
#   4. Then run one of:
#        run_main_test        ;# Check final register/memory values
#        run_checkpoint_test  ;# Check values at each part boundary
#
# ============================================================================

proc compile_all {} {
    vlog alu.v br.v ctrl.v dm.v im.v ir.v mux4.v mux16.v mux32.v pc.v rf.v statreg.v sisc.v
}

proc run_main_test {} {
    puts "============================================================"
    puts "  Compiling for main test (imem.data Parts 1+2+3)..."
    puts "============================================================"
    
    compile_all
    vlog autograder_tb.v
    
    vsim -t 100ps sisc_autograder_tb
    
    puts "  Running simulation..."
    run -all
    
    puts ""
    puts "  Test complete. Review output above."
    puts "============================================================"
}

proc run_checkpoint_test {} {
    puts "============================================================"
    puts "  Compiling for checkpoint test..."
    puts "============================================================"
    
    compile_all
    vlog autograder_checkpoint_tb.v
    
    vsim -t 100ps sisc_checkpoint_tb
    
    puts "  Running simulation with per-part checkpoints..."
    run -all
    
    puts ""
    puts "  Checkpoint test complete. Review output above."
    puts "============================================================"
}

puts ""
puts "ECE:3350 SISC Self-Test loaded."
puts "Available commands:"
puts "  run_main_test        - Check final values after imem.data runs"
puts "  run_checkpoint_test  - Check values at each part boundary"
puts ""
