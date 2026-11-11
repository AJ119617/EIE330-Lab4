`timescale 1ns/1ps

// Run with the original debounce setting (500,000 pixel clocks).
module lab4_tb;
    localparam MS = 1_000_000; // Timescale is ns.
    localparam BARS = 0, MUST = 1, END_SCREEN = 2;
    reg sys_clk = 0, sys_rst_n = 1, key_in = 1;
    wire hsync, vsync;
    wire [15:0] rgb;
    lab4_top dut(.*);
    always #10 sys_clk = ~sys_clk;

    // Short names for signals in the GTKWave viewer.
    wire click_pulse = dut.click_pulse;
    wire frame_tick = dut.frame_tick;
    wire [1:0] screen_sel = dut.screen_sel;
    wire pending_click = dut.screen_fsm_inst.pending_click;
    wire stable_key = dut.button_event_inst.stable_key;
    wire [18:0] debounce_count = dut.button_event_inst.debounce_count;
    reg count_window = 0;
    wire [18:0] count_sample = count_window ? debounce_count : 19'bx;
    integer pulses = 0, transitions = 0;
    time last_frame_edge, pulse_start;
    always @(posedge dut.vga_clk)
        if (frame_tick) last_frame_edge = $time;
    always @(posedge click_pulse) begin
        pulses = pulses + 1;
        pulse_start = $time;
        $display("  click #%0d at %0.6f ms", pulses, $realtime/MS);
    end
    always @(negedge click_pulse)
        if (sys_rst_n && pulses > 0 && $time - pulse_start != 40)
            $fatal(1, "click_pulse should last 40 ns");
    always @(screen_sel) begin
        if (sys_rst_n) begin
            if ($time !== last_frame_edge) $fatal(1, "screen changed within a frame");
            transitions = transitions + 1;
        end
        $display("  state=%0d at %0.6f ms", screen_sel, $realtime/MS);
    end
    initial begin
        $dumpfile("lab4.vcd");
        $dumpvars(0, sys_rst_n, key_in, stable_key, click_pulse, pending_click,
                  frame_tick, screen_sel, count_window, count_sample);
    end

    // These checks run alongside the button tests, at the actual VGA output.
    task automatic pixel(input integer x, input integer y, input [15:0] expected);
        begin
            wait (dut.vga_ctrl_inst.cnt_v == 35+y && dut.vga_ctrl_inst.cnt_h == 144+x);
            #1;
            $display("  pixel state=%0d (%0d,%0d) expected=%04h actual=%04h",
                     screen_sel, x, y, expected, rgb);
            if (rgb !== expected) $fatal(1, "RGB mismatch");
        end
    endtask
    reg pixel_pass = 0, timing_pass = 0;
    initial begin
        @(posedge sys_rst_n);
        pixel(0,0,16'hffff); pixel(80,0,16'hffe0);
        pixel(160,0,16'h07ff); pixel(240,0,16'h07e0);
        pixel(320,0,16'hf81f); pixel(400,0,16'hf800);
        pixel(480,0,16'h001f); pixel(560,0,16'h0000);
        wait (screen_sel == MUST);
        pixel(168,208,16'hffff); pixel(184,208,16'h0000); // First row of M: 11000011
        pixel(248,208,16'hffff); pixel(336,208,16'hffff); pixel(408,208,16'hffff);
        wait (screen_sel == END_SCREEN);
        pixel(207,208,16'h0000); pixel(208,208,16'hffff);
        pixel(288,208,16'hffff); pixel(368,208,16'hffff); pixel(431,208,16'h0000);
        pixel_pass = 1;
    end
    initial begin : timing
        time t;
        integer rows;
        @(posedge sys_rst_n);
        @(posedge hsync); t = $time;
        @(negedge hsync);
        if ($time-t != 3840) $fatal(1, "HSYNC width mismatch");
        @(posedge hsync);
        if ($time-t != 32000) $fatal(1, "line period mismatch");
        @(posedge vsync); t = $time;
        @(negedge vsync);
        if ($time-t != 64000) $fatal(1, "VSYNC width mismatch");
        // Sample between clock edges, away from combinational delta cycles.
        for (rows=0; rows<480; rows=rows+1) begin
            wait(dut.vga_ctrl_inst.cnt_v==35+rows && dut.vga_ctrl_inst.cnt_h==143);
            #1; if (dut.vga_ctrl_inst.rgb_valid !== 0) $fatal(1,"early valid");
            #40; if (dut.vga_ctrl_inst.rgb_valid !== 1) $fatal(1,"late valid");
            #(639*40); if (dut.vga_ctrl_inst.rgb_valid !== 1) $fatal(1,"short valid");
            #40; if (dut.vga_ctrl_inst.rgb_valid !== 0) $fatal(1,"long valid");
        end
        @(posedge vsync);
        if ($time-t != 16800000) $fatal(1, "frame period mismatch");
        $display("PASS timing: line=32 us, frame=16.8 ms, HSYNC=3.84 us, VSYNC=64 us");
        timing_pass = 1;
    end

    task automatic clean_press(input integer expected_state);
        integer p, s;
        begin
            p = pulses; s = transitions;
            key_in = 0;
            #(40*MS);
            if (pulses != p+1 || transitions != s+1 || screen_sel !== expected_state)
                $fatal(1, "clean press failed for state %0d", expected_state);
            key_in = 1;
            #(21*MS);
            $display("PASS clean press: state %0d, one pulse and one transition", expected_state);
        end
    endtask
    task automatic reset_to_bars;
        begin
            sys_rst_n = 0;
            #100;
            if (screen_sel !== BARS || pending_click !== 0) $fatal(1,"reset failed");
            sys_rst_n = 1;
            #500;
        end
    endtask

    integer p_before, s_before;
    initial begin
        #5; reset_to_bars();
        $display("TEST clean cycle BARS -> MUST -> END -> BARS");
        clean_press(MUST); clean_press(END_SCREEN); clean_press(BARS);
        $display("TEST reset from BARS");
        reset_to_bars();

        $display("TEST bouncing press, then long hold");
        p_before = pulses; s_before = transitions;
        key_in = 0; #(2*MS);
        key_in = 1; #(1*MS);
        key_in = 0; #(2*MS);
        key_in = 1; #(1*MS);
        if (pulses != p_before || screen_sel !== BARS) $fatal(1, "bounce triggered");
        key_in = 0;
        $display("  final stable low starts at %0.6f ms", $realtime/MS);
        // Record only the start and finish of the count to keep the VCD small.
        count_window = 1; #800; count_window = 0;
        #(20*MS-1600); count_window = 1; #1600; count_window = 0;
        if (pulses != p_before+1) $fatal(1, "20 ms debounce timeout");
        // Still held after a total of 60 ms. Only one event is allowed.
        #(40*MS-800);
        if (pulses != p_before+1 || transitions != s_before+1 || screen_sel !== MUST)
            $fatal(1, "long hold repeated or lost an event");
        $display("PASS bounce + 60 ms hold: one pulse and one transition");
        $display("TEST reset from MUST while B2 stays low");
        reset_to_bars();
        #(41*MS);
        if (screen_sel !== BARS || pulses != p_before+1) $fatal(1,"held key retriggered");
        key_in = 1;
        #(21*MS);
        $display("PASS held-through-reset; next press should rearm");
        clean_press(MUST); clean_press(END_SCREEN);
        $display("TEST reset from END during a new, unconfirmed press");
        key_in = 0; #(3*MS); reset_to_bars();
        if (!timing_pass || !pixel_pass) $fatal(1, "missing pixel/timing evidence");
        $display("ALL CHECKS PASSED");
        $finish;
    end
endmodule
