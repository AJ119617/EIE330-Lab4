`timescale 1ns/1ps

module tb_button_event;
    reg vga_clk = 0, sys_rst_n = 1, key_in = 1;
    wire click_pulse;
    integer events = 0;
    time pulse_start;
    button_event #(.DEBOUNCE_CYCLES(8)) dut(.*);
    always #20 vga_clk = ~vga_clk;

    always @(posedge click_pulse) begin
        if (sys_rst_n) begin
            events = events + 1;
            pulse_start = $time;
        end
    end
    always @(negedge click_pulse)
        if (sys_rst_n && events > 0 && $time - pulse_start != 40)
            $fatal(1, "click pulse was not one pixel clock wide");

    task automatic drive(input level, input integer cycles);
        @(negedge vga_clk);
        key_in = level;
        repeat (cycles) @(posedge vga_clk);
        #1;
    endtask

    task automatic check_events(input integer expected);
        if (events != expected) $fatal(1, "expected %0d pulses, saw %0d", expected, events);
    endtask

    initial begin
        $dumpfile("tb_button_event.vcd");
        $dumpvars(0, tb_button_event);
        #5 sys_rst_n = 0;
        #1;
        if (click_pulse !== 0 || dut.debounce_count !== 0) $fatal(1, "reset failed");
        @(negedge vga_clk);
        sys_rst_n = 1;
        drive(1, 12);
        if (dut.armed !== 1) $fatal(1, "idle key did not arm");

        drive(0, 3); drive(1, 2); drive(0, 2); drive(1, 3);
        check_events(0);
        drive(0, 9);  // Two synchronizer edges and seven counter increments.
        check_events(0);
        if (dut.key_sync !== 0 || dut.debounce_count !== 7) $fatal(1, "threshold count mismatch");
        drive(0, 1);
        check_events(1);
        if (click_pulse !== 1 || dut.stable_key !== 0) $fatal(1, "press was not accepted");
        drive(0, 35);
        check_events(1);

        drive(1, 4); drive(0, 12);  // False release cannot rearm another press.
        check_events(1);
        drive(1, 12); drive(0, 12);
        check_events(2);

        // Keep the key low through reset. Releasing reset cannot generate a click.
        #3 sys_rst_n = 0;
        #1;
        if (click_pulse !== 0 || dut.armed !== 0 || dut.debounce_count !== 0)
            $fatal(1, "asynchronous reset while held failed");
        @(negedge vga_clk);
        sys_rst_n = 1;
        drive(0, 25);
        check_events(2);
        drive(1, 12); drive(0, 12);
        check_events(3);
        $display("PASS button_event (8 clocks): bounce, threshold, 40 ns pulse, hold, stable rearm and held-through-reset");
        $finish;
    end
endmodule
