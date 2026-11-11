#!/usr/bin/env bash
set -euo pipefail

project=$(cd "$(dirname "$0")" && pwd)
results="$project/build"
mkdir -p "$results"
cd "$results"
sources=("$project"/RTL/*.v)

iverilog -g2012 -Wall -s lab4_top -o lab4_top.vvp "${sources[@]}"
yosys -Q -T -l synthesis.log -p "read_verilog \"$project/RTL/pll.v\" \"$project/RTL/vga_ctrl.v\" \"$project/RTL/vga_pic.v\" \"$project/RTL/button_event.v\" \"$project/RTL/screen_fsm.v\" \"$project/RTL/lab4_top.v\"; synth -top lab4_top; check -assert; stat" > /dev/null

for bench in tb_pll tb_vga_ctrl tb_vga_pic tb_button_event tb_button_event_production tb_screen_fsm lab4_top_tb; do
    iverilog -g2012 -Wall -s "$bench" -o "$bench.vvp" "${sources[@]}" "$project/sim/$bench.sv"
    vvp "$bench.vvp" | tee "$bench.log"
done
