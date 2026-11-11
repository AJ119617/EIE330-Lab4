`timescale 1ns/1ps

// Integration test adapted from the Lab 4 practice testbench. The eight-cycle
// debounce parameter shortens the button stimulus; VGA timing is unchanged.
module lab4_top_tb;
    localparam [1:0] BARS = 0, MUST = 1, END_SCREEN = 2;
    reg sys_clk = 0;
    reg sys_rst_n = 1;
    reg key_in = 1;
    wire hsync, vsync;
    wire [15:0] rgb;
    lab4_top #(.DEBOUNCE_CYCLES(8)) dut (.*);
    always #10 sys_clk = ~sys_clk;

    wire vga_clk = dut.vga_clk;
    wire click_pulse = dut.click_pulse;
    wire frame_tick = dut.frame_tick;
    wire pending_click = dut.screen_fsm_inst.pending_click;
    wire [1:0] screen_sel = dut.screen_sel;
    wire visible = dut.vga_ctrl_inst.rgb_valid;
    integer pulses = 0, transitions = 0, samples = 0;
    integer line_intervals = 0, frame_intervals = 0, active_lines = 0;
    time click_start, last_frame_edge;
    time hsync_start, vsync_start, active_start;

    always @(posedge vga_clk)
        if (frame_tick) last_frame_edge = $time;
    always @(posedge click_pulse) begin
        pulses = pulses + 1;
        click_start = $time;
        $display("CLICK %0d at %0d ns", pulses, $time);
    end
    always @(negedge click_pulse)
        if (sys_rst_n && pulses && $time - click_start != 40)
            $fatal(1, "click_pulse width must be 40 ns");
    always @(screen_sel)
        if (sys_rst_n) begin
            if ($time !== last_frame_edge)
                $fatal(1, "screen change outside the frame boundary");
            transitions = transitions + 1;
            $display("SCREEN %0d at %0d ns", screen_sel, $time);
        end

    // Read the settled scan outputs halfway through each pixel. Reset may cut
    // a sync interval short, so start measuring at the first full rising edge.
    reg prev_h, prev_v, prev_visible;
    always @(negedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            hsync_start = 0; vsync_start = 0; active_start = 0;
            prev_h = 1; prev_v = 1; prev_visible = 0;
        end else begin
            if (hsync && !prev_h) begin
                if (hsync_start) begin
                    if ($time-hsync_start != 32000) $fatal(1, "line period");
                    line_intervals = line_intervals + 1;
                end
                hsync_start = $time;
            end
            if (!hsync && prev_h && hsync_start && $time-hsync_start != 3840)
                $fatal(1, "HSYNC high time");
            if (vsync && !prev_v) begin
                if (vsync_start) begin
                    if ($time-vsync_start != 16800000) $fatal(1, "frame period");
                    frame_intervals = frame_intervals + 1;
                end
                vsync_start = $time;
            end
            if (!vsync && prev_v && vsync_start && $time-vsync_start != 64000)
                $fatal(1, "VSYNC high time");
            if (visible && !prev_visible) active_start = $time;
            if (!visible && prev_visible) begin
                if ($time-active_start != 25600) $fatal(1, "active window width");
                active_lines = active_lines + 1;
            end
            prev_h = hsync; prev_v = vsync; prev_visible = visible;
        end
    end

    // Observe RGB after the output for this counter position has settled.
    task automatic sample_rgb(input [1:0] state_id, input integer h, v,
                              input bit active, input [15:0] expected_rgb);
        begin
            wait (dut.vga_ctrl_inst.cnt_h == h && dut.vga_ctrl_inst.cnt_v == v);
            #1;
            if (screen_sel !== state_id || visible !== active || rgb !== expected_rgb)
                $fatal(1, "at (%0d,%0d), state=%0d visible=%b rgb=%h expected=%h",
                       h, v, screen_sel, visible, rgb, expected_rgb);
            samples = samples + 1;
        end
    endtask
    task automatic pixel(input [1:0] state_id, input integer x, y, input [15:0] color);
        sample_rgb(state_id, 144+x, 35+y, 1, color);
    endtask

    reg bars_checked = 0;
    initial begin
        @(posedge sys_rst_n);
        sample_rgb(BARS, 100, 1, 0, 16'h0000);
        pixel(BARS, 40,0,16'hffff);  pixel(BARS,120,0,16'hffe0);
        pixel(BARS,200,0,16'h07ff);  pixel(BARS,280,0,16'h07e0);
        pixel(BARS,360,0,16'hf81f);  pixel(BARS,440,0,16'hf800);
        pixel(BARS,520,0,16'h001f);  pixel(BARS,600,0,16'h0000);
        pixel(BARS,440,479,16'hf800);
        bars_checked = 1;
        wait (screen_sel == MUST);
        pixel(MUST,167,208,16'h0000); pixel(MUST,168,208,16'hffff);
        pixel(MUST,184,208,16'h0000); pixel(MUST,248,208,16'hffff);
        pixel(MUST,336,208,16'hffff); pixel(MUST,408,208,16'hffff);
        wait (screen_sel == END_SCREEN);
        pixel(END_SCREEN,208,208,16'hffff); pixel(END_SCREEN,288,208,16'hffff);
        pixel(END_SCREEN,368,208,16'hffff); pixel(END_SCREEN,416,208,16'h0000);
    end

    task automatic press(input [1:0] expected_screen);
        integer p, s;
        begin
            p = pulses;
            s = transitions;
            @(negedge vga_clk);
            key_in = 0;
            repeat (20) @(negedge vga_clk);
            if (pulses != p+1) $fatal(1, "expected one accepted press");
            wait (screen_sel === expected_screen);
            // The state monitor also runs at this simulation time.
            @(negedge vga_clk);
            if (transitions != s+1 || pending_click !== 0)
                $fatal(1, "expected one committed screen change");
        end
    endtask
    task automatic release_key;
        begin
            key_in = 1;
            repeat (12) @(negedge vga_clk);
        end
    endtask
    task automatic reset_board;
        begin
            #1;
            sys_rst_n = 0;
            #1;
            if (screen_sel !== BARS || pending_click !== 0 || rgb !== 0)
                $fatal(1, "asynchronous reset");
            #98;
            sys_rst_n = 1;
            repeat (12) @(negedge vga_clk);
        end
    endtask

    initial begin
        $dumpfile("lab4_top.vcd");
        $dumpvars(0, sys_rst_n, key_in, click_pulse, pending_click,
                  frame_tick, screen_sel, hsync, vsync, visible);
        #5; reset_board();
        wait (bars_checked);
        press(MUST); release_key();
        press(END_SCREEN); release_key();
        press(BARS); release_key();
        reset_board(); // Reset while already showing bars.
        // A sequence of short low intervals must not count as a press.
        key_in = 0; repeat (3) @(negedge vga_clk);
        key_in = 1; repeat (2) @(negedge vga_clk);
        key_in = 0; repeat (3) @(negedge vga_clk);
        key_in = 1; repeat (6) @(negedge vga_clk);
        if (pulses != 3 || screen_sel !== BARS) $fatal(1, "bounce accepted");
        press(MUST);
        @(posedge frame_tick); // Hold through another full frame.
        repeat (2) @(negedge vga_clk);
        if (pulses != 4 || transitions != 4 || screen_sel !== MUST)
            $fatal(1, "long hold repeated");
        reset_board(); // Leave the button low before, during and after reset.
        @(posedge frame_tick);
        repeat (2) @(negedge vga_clk);
        if (screen_sel !== BARS || pulses != 4 || pending_click !== 0)
            $fatal(1, "held key retriggered after reset");
        release_key();
        press(MUST); release_key();
        press(END_SCREEN); release_key();
        key_in = 0; repeat (3) @(negedge vga_clk);
        reset_board(); // Reset END with a new, as yet unconfirmed press.
        if (pulses != 6 || transitions != 6 || samples != 20 ||
            line_intervals < 520 || frame_intervals < 1 || active_lines < 480)
            $fatal(1, "missing integration coverage");
        $display("PASS lab4_top: %0d pulses, %0d frame-aligned changes, %0d RGB samples",
                 pulses, transitions, samples);
        $display("PASS timing: %0d lines, %0d frame intervals, %0d active lines",
                 line_intervals, frame_intervals, active_lines);
        $finish;
    end
    initial #250_000_000 $fatal(1, "integration timeout");
endmodule
