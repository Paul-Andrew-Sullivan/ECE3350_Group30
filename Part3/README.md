# ECE:3350 SISC Processor Self-Test

These files let you automatically check your processor's output against the
expected values from `imem.data`. Use them early and often as you build Parts
1, 2, and 3 — they'll tell you exactly which part is broken.

## Quick Start (ModelSim)

1. Copy all files from this folder into your project directory (next to your `.v` files).
2. Open ModelSim and navigate to your project directory.
3. In the transcript:

```
source run_selftest.tcl
run_checkpoint_test
```

That's it. You'll see PASS/FAIL for each checked value, organized by part.

## Quick Start (Icarus Verilog)

```bash
iverilog -g2005 -o test autograder_checkpoint_tb.v sisc.v ctrl.v rf.v alu.v \
    mux32.v statreg.v br.v im.v ir.v pc.v dm.v mux4.v mux16.v
vvp test
```

## Available Tests

### `run_checkpoint_test` (recommended)

Checks register values at four intermediate points as `imem.data` executes:

| Checkpoint | When | What it checks |
|---|---|---|
| 1 | After addr 0x0B | Part 1 Section 1: arithmetic/logic results |
| 2 | After addr 0x11 | Part 1 Section 2: status flag results |
| 3 | After addr 0x1D | Part 2: branch loop results (R4 should be 6) |
| 4 | At HLT (0x25)   | Part 3: load/store results + data memory |

This is the most useful test because it narrows down failures. If checkpoints
1 and 2 pass but 3 fails, your branches are broken. If 1-3 pass but 4 fails,
check your load/store implementation.

### `run_main_test`

Checks only the final state at HLT — all 16 registers and 2 memory locations.
Gives you a single score out of 18 checks. Also prints diagnostic hints if
common failure patterns are detected.

## Expected Final Values

After all instructions in `imem.data` execute and HLT is reached:

| Register | Expected | Set by |
|---|---|---|
| R0 | 00000000 | Always zero |
| R1 | 00000001 | Parts 1-3 |
| R2 | FF000019 | Part 3 (LDA R2, #0009) |
| R3 | 00000006 | Part 3 (LDX R3, R3, #16) |
| R4 | 00000006 | Part 2 (branch loop counter) |
| R5 | FF000019 | Part 1 (OR result) |
| R6-R15 | 00000000 | Unused |
| M[8] | 00000006 | Part 3 (STA R4, #0008) |
| M[9] | FF000019 | Part 3 (STX R5, R1, #0008) |

See `golden_reference.txt` for a complete instruction-by-instruction trace
showing expected values after every single instruction.

## Instance Naming

The testbenches access your register file and data memory using hierarchical
references. Your `sisc.v` must use these instance names:

```
rf       u2        // Register file
ir       u9        // Instruction register
pc       u10       // Program counter
dm       u11       // Data memory
ctrl     u1        // Control unit
```

If you use different names, search the testbench files for `uut.u2`, `uut.u9`,
`uut.u10`, `uut.u11` and update them to match yours.

## Troubleshooting

**"TIMEOUT" message:** Your processor is stuck in an infinite loop. Check that
`pc_write` and `ir_load` are asserted during fetch, and that your FSM
transitions are correct.

**All values are `xxxxxxxx`:** Your register file isn't being written. Check
that `rf_we` is asserted during writeback for REG_OP and REG_IM instructions.

**Checkpoints 1-2 pass, checkpoint 3 fails:** Branch logic is wrong. Verify
your decode state handles BRA/BRR/BNE/BNR correctly — pay attention to the
difference between `(mm & stat) != 0` and `(mm & stat) == 0`.

**Checkpoints 1-3 pass, checkpoint 4 fails:** Load/store is wrong. Common
issues: `dm_we` not asserted for stores, `wb_sel` not selecting DM output
for loads, `rb_sel` not routing Rd for store data, or `mux16` address
selection incorrect.

**Compilation error about port mismatch:** Your `sisc.v` may still have `ir`
as a port from Part 1. For Parts 2+, the port list should be
`module sisc (clk, rst_f);` since the IR is now an internal module.
