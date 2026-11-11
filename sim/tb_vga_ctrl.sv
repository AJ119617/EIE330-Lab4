`timescale 1ns/1ps
module tb_vga_ctrl;
    localparam integer LINE_CLOCKS = 800, FRAME_LINES = 525;
    localparam integer LEFT = 144, TOP = 35, WIDTH = 640, HEIGHT = 480;
    reg vga_clk = 0;
    reg sys_rst_n = 1;
    reg [15:0] pix_data;
    wire [9:0] pix_x, pix_y;
    wire hsync, vsync, frame_tick;
    wire [15:0] rgb;
    integer line, slot;
    integer active_pixels = 0, requests = 0, line_sync_clocks = 0;
    reg [15:0] expected_rgb;
    reg [9:0] expected_x, expected_y;
    time frame_start;

    always #20 vga_clk = ~vga_clk;
    vga_ctrl dut (.*);

    // Stand in for a synchronous pixel source. Every tag is nonblack, even
    // for (0,0), so the first pixel can be distinguished from blanking.
    function automatic [15:0] tag(input [9:0] x, y);
        tag = {1'b1, y[4:0], x};
    endfunction
    always @(posedge vga_clk)
        pix_data <= tag(pix_x, pix_y);

    initial begin
        $dumpfile("tb_vga_ctrl.vcd");
        $dumpvars(0, vga_clk, sys_rst_n, pix_x, pix_y, pix_data, hsync, vsync, rgb, frame_tick);
        #3;
        sys_rst_n = 0;
        @(negedge vga_clk);
        sys_rst_n = 1;
        #1;
        frame_start = $time;

        for (line = 0; line < FRAME_LINES; line = line + 1) begin
            for (slot = 0; slot < LINE_CLOCKS; slot = slot + 1) begin
                // Keep the VCD small: beginning of frame, first active line,
                // and the frame-end pulse. Assertions run on every clock.
                if (line == 1 && slot == 0) $dumpoff;
                if (line == TOP && slot == 0) $dumpon;
                if (line == TOP + 1 && slot == 0) $dumpoff;
                if (line == FRAME_LINES - 1 && slot == LINE_CLOCKS - 3) $dumpon;

                if (hsync !== (slot < 96) || vsync !== (line < 2))
                    $fatal(1, "wrong sync: slot=%0d line=%0d H=%b V=%b", slot, line, hsync, vsync);
                if (hsync) line_sync_clocks = line_sync_clocks + 1;
                if (frame_tick !== (line == FRAME_LINES-1 && slot == LINE_CLOCKS-1))
                    $fatal(1, "wrong frame_tick at slot=%0d line=%0d", slot, line);

                expected_rgb = 16'h0000;
                if (line >= TOP && line < TOP + HEIGHT && slot >= LEFT && slot < LEFT + WIDTH) begin
                    expected_rgb = tag(slot - LEFT, line - TOP);
                    active_pixels = active_pixels + 1;
                end
                if (rgb !== expected_rgb)
                    $fatal(1, "slot=%0d line=%0d RGB expected=%h got=%h", slot, line, expected_rgb, rgb);

                expected_x = 10'h3ff;
                expected_y = 10'h3ff;
                if (line >= TOP && line < TOP + HEIGHT && slot + 1 >= LEFT && slot + 1 < LEFT + WIDTH) begin
                    expected_x = slot + 1 - LEFT;
                    expected_y = line - TOP;
                    requests = requests + 1;
                end
                if (pix_x !== expected_x || pix_y !== expected_y)
                    $fatal(1, "prefetch at slot=%0d line=%0d expected=(%0d,%0d) got=(%0d,%0d)",
                           slot, line, expected_x, expected_y, pix_x, pix_y);
                @(negedge vga_clk);
                #1;
            end
        end
        if (hsync !== 1'b1 || vsync !== 1'b1 || frame_tick !== 1'b0 || rgb !== 0)
            $fatal(1, "frame did not wrap to the sync/blank interval");
        if ($time - frame_start != 16800000 || active_pixels != 307200 ||
            requests != active_pixels || line_sync_clocks != 50400)
            $fatal(1, "frame totals inconsistent");
        $display("PASS tb_vga_ctrl: 420000 clocks, %0d active pixels, %0d look-ahead requests, period %0d ns",
                 active_pixels, requests, $time - frame_start);
        $finish;
    end
endmodule
