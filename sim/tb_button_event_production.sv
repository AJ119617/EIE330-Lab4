`timescale 1ns/1ps

module tb_button_event_production;
    reg vga_clk = 0, sys_rst_n = 1, key_in = 1;
    wire click_pulse;
    button_event dut(.*);  // Exercise the unmodified 500,000-clock default.
    always #20 vga_clk = ~vga_clk;

    integer events = 0;
    time stable_press_start, first_pulse;
    always @(posedge click_pulse) begin
        if (sys_rst_n) begin
            events = events + 1;
            if (events == 1) first_pulse = $time;
        end
    end

    // Save long-run signals throughout. Expose the counter around the start
    // and threshold without recording its 500,000 intermediate increments.
    reg capture_count = 0;
    wire [18:0] count_sample = capture_count ? dut.debounce_count : 19'bx;
    initial begin
        $dumpfile("tb_button_event_production.vcd");
        $dumpvars(0, sys_rst_n, key_in, dut.key_sync, dut.stable_key,
                  dut.armed, click_pulse, count_sample, capture_count);
        #5 sys_rst_n = 0;
        @(negedge vga_clk);
        sys_rst_n = 1;
        repeat (10) @(posedge vga_clk);

        // 10 ms of alternating low/high intervals. None lasts 20 ms.
        key_in <= 0; #2_000_000;
        key_in <= 1; #2_000_000;
        key_in <= 0; #3_000_000;
        key_in <= 1; #3_000_000;
        if (events != 0 || dut.stable_key !== 1) $fatal(1, "event during the 10 ms bounce");

        // A nonblocking change on a positive edge is sampled on the next edge.
        stable_press_start = $time;
        key_in <= 0;
        capture_count = 1;
        #400 capture_count = 0;
        #(19_998_000 - 400);
        if (events != 0 || click_pulse !== 0) $fatal(1, "premature pulse at 19.998 ms");
        capture_count = 1;
        #2041;
        if (dut.debounce_count !== 19'd499999 || events != 0)
            $fatal(1, "expected count=499999 immediately before acceptance");
        #40;
        if (events != 1 || click_pulse !== 1 || first_pulse - stable_press_start != 20_000_080)
            $fatal(1, "production input-to-pulse delay mismatch");
        $display("Measured count=499999, no pulse at 19.998 ms, first pulse %0d ns after stable low",
                 first_pulse - stable_press_start);
        #40;
        if (click_pulse !== 0) $fatal(1, "pulse remained high after one 40 ns cycle");
        capture_count = 0;

        #40_000_000;
        if (events != 1) $fatal(1, "held input produced another pulse");
        @(negedge vga_clk);
        key_in = 1;
        #20_001_000;
        if (dut.stable_key !== 1 || dut.armed !== 1) $fatal(1, "stable release did not rearm");
        @(negedge vga_clk);
        key_in = 0;
        #20_001_000;
        if (events != 2) $fatal(1, "second press did not produce exactly one event");
        $display("PASS button_event (500000 clocks): 10 ms bounce, 20 ms filter, 60 ms hold, release and second press");
        $finish;
    end
endmodule
