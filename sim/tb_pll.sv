`timescale 1ns/1ps

module tb_pll;
    reg sys_clk = 0, sys_rst_n = 1;
    wire vga_clk;
    pll dut(.*);
    always #10 sys_clk = ~sys_clk;

    integer edge_number;
    time first_rise, second_rise;
    initial begin
        $dumpfile("tb_pll.vcd");
        $dumpvars(0, tb_pll);
        #3 sys_rst_n = 0;
        #1;
        if (vga_clk !== 0) $fatal(1, "asynchronous reset failed");
        @(negedge sys_clk);
        sys_rst_n = 1;
        for (edge_number = 1; edge_number <= 8; edge_number = edge_number + 1) begin
            @(posedge sys_clk);
            #1;
            if (vga_clk !== edge_number[0]) $fatal(1, "wrong phase at edge %0d", edge_number);
            if (edge_number == 1) first_rise = $time;
            if (edge_number == 3) second_rise = $time;
            @(negedge sys_clk);
            #1;
            if (vga_clk !== edge_number[0]) $fatal(1, "output changed on falling edge");
        end
        if (second_rise - first_rise != 40) $fatal(1, "pixel clock period mismatch");

        // Reset while the divided clock is high, between source edges.
        @(posedge sys_clk);
        #3 sys_rst_n = 0;
        #1;
        if (vga_clk !== 0) $fatal(1, "running clock did not reset immediately");
        @(posedge sys_clk);
        #1;
        if (vga_clk !== 0) $fatal(1, "clock toggled while held in reset");
        @(negedge sys_clk);
        sys_rst_n = 1;
        @(posedge sys_clk);
        #1;
        if (vga_clk !== 1) $fatal(1, "wrong first edge after reset");
        $display("PASS pll: 50 MHz input, 25 MHz output, asynchronous reset and restart");
        $finish;
    end
endmodule
