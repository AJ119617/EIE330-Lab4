# EIE330 FPGA Lab 4 – VGA screen controller

On reset, the display shows eight vertical color bars (`00`). A press of B2 switches to MUST (`01`), then END (`10`), and then back to the bars. Each accepted click takes effect at the next frame boundary. The active-low RESET input returns the controller to the bars immediately.

## Design and simulation

- `RTL/` contains the six Verilog modules used for the demonstration. `lab4_top` connects the 50 MHz input clock, the 25 MHz VGA clock, the debouncer, the screen state machine and the RGB565 display path.
- `sim/` contains seven self-checking testbenches covering the clock divider, the VGA scan, the pixel generator, the button at two thresholds, the three-state controller and the integrated design.
- `board_sim/DevelopmentBoard.v` maps the simulator clock, B2, RESET and VGA outputs to the design.

Run the following command in this directory with Bash, Icarus Verilog and Yosys installed:

```sh
bash check.sh
```

The script compiles the top level, runs generic synthesis, then runs the seven simulations. It writes logs and VCD waveforms to `build/`. The production button test uses 500,000 cycles at 25 MHz (20 ms). The integrated test shortens the debounce interval to eight cycles to exercise several complete frames.

These seven testbenches were prepared for publication to reproduce the reported checks. Their own logs contain the sample and event counts for this run. The earlier practice testbench and waveform plotting script are in `sim/practice/`.

[Virtual-board demonstration on Bilibili](https://www.bilibili.com/video/BV1jvW16JECn/)
