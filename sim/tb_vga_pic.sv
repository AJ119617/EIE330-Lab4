`timescale 1ns/1ps
module tb_vga_pic;
    localparam [1:0] BARS = 0, MUST = 1, END_SCREEN = 2;
    localparam [15:0] WHITE = 16'hffff, BLACK = 16'h0000;
    reg vga_clk = 0;
    reg sys_rst_n = 1;
    reg [9:0] pix_x = 0, pix_y = 0;
    reg [1:0] screen_sel = BARS;
    wire [15:0] pix_data;
    integer samples = 0;
    integer bar;
    reg [15:0] palette [0:7];

    always #20 vga_clk = ~vga_clk;
    vga_pic dut (.*);

    task automatic sample(input [1:0] screen, input integer x, y,
                          input [15:0] expected);
        reg [15:0] previous_pixel;
        begin
            @(negedge vga_clk);
            previous_pixel = pix_data;
            screen_sel = screen;
            pix_x = x;
            pix_y = y;
            #1;
            if (pix_data !== previous_pixel)
                $fatal(1, "pix_data changed before the rising edge at (%0d,%0d)", x, y);
            @(posedge vga_clk);
            #1;
            if (pix_data !== expected)
                $fatal(1, "screen=%0d pixel=(%0d,%0d) expected=%h got=%h",
                       screen, x, y, expected, pix_data);
            samples = samples + 1;
        end
    endtask

    // One distinctive foreground cell and one background cell per glyph.
    // Probe opposite corners of each enlarged cell and the margins of its box.
    task automatic letter(input [1:0] screen, input integer left,
                          input integer ink_col, ink_row, gap_col, gap_row);
        begin
            sample(screen, left + 8*ink_col,     208 + 8*ink_row,     WHITE);
            sample(screen, left + 8*ink_col + 7, 208 + 8*ink_row + 7, WHITE);
            sample(screen, left + 8*gap_col,     208 + 8*gap_row,     BLACK);
            sample(screen, left + 8*gap_col + 7, 208 + 8*gap_row + 7, BLACK);
            sample(screen, left - 1, 240, BLACK);
            sample(screen, left + 64, 240, BLACK);
            sample(screen, left + 8*ink_col, 207, BLACK);
            sample(screen, left + 8*ink_col, 272, BLACK);
        end
    endtask

    initial begin
        $dumpfile("tb_vga_pic.vcd");
        $dumpvars(0, vga_clk, sys_rst_n, screen_sel, pix_x, pix_y, pix_data);
        #3;
        sys_rst_n = 0;
        #1;
        if (pix_data !== BLACK) $fatal(1, "reset did not clear the pixel");
        sys_rst_n = 1;

        palette[0] = WHITE;    palette[1] = 16'hffe0;
        palette[2] = 16'h07ff; palette[3] = 16'h07e0;
        palette[4] = 16'hf81f; palette[5] = 16'hf800;
        palette[6] = 16'h001f; palette[7] = BLACK;
        for (bar = 0; bar < 8; bar = bar + 1) begin
            sample(BARS, 80*bar,      0,   palette[bar]);
            sample(BARS, 80*bar + 79, 0,   palette[bar]);
            sample(BARS, 80*bar,      479, palette[bar]);
            sample(BARS, 80*bar + 79, 479, palette[bar]);
        end
        sample(BARS, 640, 0, BLACK);
        sample(BARS, 0, 480, BLACK);

        letter(MUST, 168, 2,1, 3,1); // M: upper diagonal next to its notch
        letter(MUST, 248, 3,7, 0,7); // U: rounded base
        letter(MUST, 328, 7,4, 0,4); // S: right-hand lower stroke
        letter(MUST, 408, 3,5, 2,5); // T: narrow stem
        letter(END_SCREEN, 208, 6,3, 7,3); // E: end of middle bar
        letter(END_SCREEN, 288, 5,4, 3,4); // N: descending diagonal
        letter(END_SCREEN, 368, 7,3, 5,3); // D: curved outside edge
        sample(MUST, 231, 271, WHITE);
        sample(MUST, 408, 208, WHITE);
        sample(END_SCREEN, 208, 271, WHITE);
        sample(END_SCREEN, 431, 271, BLACK);
        sample(2'd3, 0, 0, BLACK);

        // Assert reset while the output is white, between rising edges.
        sample(BARS, 1, 1, WHITE);
        #5;
        sys_rst_n = 0;
        #1;
        if (pix_data !== BLACK) $fatal(1, "asynchronous clear of a white pixel failed");
        $display("PASS tb_vga_pic: %0d registered samples, 8 bars and all 7 glyphs", samples);
        $finish;
    end
endmodule
