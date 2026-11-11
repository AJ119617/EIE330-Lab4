`timescale 1ns/1ps

module tb_screen_fsm;
    localparam [1:0] BARS = 2'b00, MUST = 2'b01, END_SCREEN = 2'b10;
    reg vga_clk = 0, sys_rst_n = 1, click_pulse = 0, frame_tick = 0;
    wire [1:0] screen_sel;
    screen_fsm dut(.*);
    always #20 vga_clk = ~vga_clk;

    task automatic check_outputs(input [1:0] expected_screen, input expected_pending);
        if (screen_sel !== expected_screen || dut.pending_click !== expected_pending)
            $fatal(1, "expected screen/pending=%02b/%b, got %02b/%b",
                   expected_screen, expected_pending, screen_sel, dut.pending_click);
    endtask

    task automatic step(input click, input boundary, input [1:0] expected_screen, input expected_pending);
        @(negedge vga_clk);
        click_pulse = click;
        frame_tick = boundary;
        @(posedge vga_clk);
        #1;
        check_outputs(expected_screen, expected_pending);
    endtask

    task automatic reset_to_bars;
        // Assert away from a rising clock edge and check before the next one.
        #3 sys_rst_n = 0;
        #1;
        check_outputs(BARS, 0);
        step(1, 1, BARS, 0);
        @(negedge vga_clk);
        click_pulse = 0;
        frame_tick = 0;
        sys_rst_n = 1;
        @(posedge vga_clk);
        #1;
        check_outputs(BARS, 0);
    endtask

    initial begin
        $dumpfile("tb_screen_fsm.vcd");
        $dumpvars(0, tb_screen_fsm);
        reset_to_bars();

        step(0, 1, BARS, 0);        // Frame boundary alone holds bars.
        step(1, 0, BARS, 1);        // Queue a click during active scan.
        step(0, 0, BARS, 1);        // It survives until the boundary.
        step(0, 1, MUST, 0);
        step(0, 1, MUST, 0);        // The consumed click cannot repeat.
        step(1, 1, END_SCREEN, 0);  // Same-edge click is accepted directly.
        step(0, 0, END_SCREEN, 0);
        step(1, 1, BARS, 0);
        reset_to_bars();            // From BARS.
        step(1, 1, MUST, 0);
        reset_to_bars();            // From MUST.
        step(1, 1, MUST, 0);
        step(1, 1, END_SCREEN, 0);
        step(1, 0, END_SCREEN, 1);
        reset_to_bars();            // From END with a queued click.
        step(0, 1, BARS, 0);        // The cleared event cannot advance it.
        $display("PASS screen_fsm: 00 -> 01 -> 10 -> 00, queued and same-edge clicks, hold, reset from every state");
        $finish;
    end
endmodule
