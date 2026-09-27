#!/usr/bin/env bash
# Exercise the $fsm simulation model in a four-state simulator, before fsm_map.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/dut.v" <<'DUT'
module gold(input clk, reset, step, output boot, active, done);
  localparam IDLE=3'b000, RUN=3'b010, DONE=3'b101;
  reg [2:0] state = DONE;
  always @(posedge clk)
    if (reset) state <= IDLE;
    else case (state)
      IDLE: if (step) state <= RUN;
      RUN: if (step) state <= DONE;
      DONE: if (step) state <= IDLE;
      default: state <= IDLE;
    endcase
  assign boot = state == IDLE;
  assign active = state == RUN;
  assign done = state == DONE;
endmodule
DUT
cat > "$work/tb.v" <<'TB'
module tb;
  reg clk=0, reset=0, step=0;
  wire gb, ga, gd, tb_, ta, td;
  gold g(clk, reset, step, gb, ga, gd);
  gate t(clk, reset, step, tb_, ta, td);
  integer i;
  initial begin
    #1;
    if ({tb_, ta, td} !== 3'b001) $fatal(1, "incorrect power-up state");
    for (i=0; i<100; i=i+1) begin
      clk=0; reset=(i%11==3); step=(i%3!=1); #1;
      clk=1; #1;
      if ({gb,ga,gd} !== {tb_,ta,td}) $fatal(1, "FSM model mismatch");
    end
    $finish;
  end
endmodule
TB
"${YOSYS:-yosys}" -Q -T -p "read_verilog $work/dut.v; proc; opt -nosdff -nodffe; copy gold gate; fsm -nomap gate; write_verilog -noattr $work/netlist.v"
"${IVERILOG:-iverilog}" -g2012 -s tb -o "$work/model.vvp" \
    "$script_dir/../../techlibs/common/simlib.v" "$work/netlist.v" "$work/tb.v"
"${VVP:-vvp}" "$work/model.vvp"
