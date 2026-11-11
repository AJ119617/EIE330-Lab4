`timescale 1ns/1ps

module lab4_top #(
    parameter integer DEBOUNCE_CYCLES = 500000
) (
    input wire sys_clk,         // 50 MHz
    input wire sys_rst_n,       // active-low asynchronous reset
    input wire key_in,          // active-low screen-switch button
    output wire hsync,
    output wire vsync,
    output wire [15:0] rgb      // RGB565
);
wire vga_clk;
wire click_pulse;
wire frame_tick;
wire [1:0] screen_sel;
wire [9:0] pix_x, pix_y;
wire [15:0] pix_data;

pll pll_inst (
    .sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .vga_clk(vga_clk)
);
button_event #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) button_event_inst (
    .vga_clk(vga_clk), .sys_rst_n(sys_rst_n),
    .key_in(key_in), .click_pulse(click_pulse)
);
screen_fsm screen_fsm_inst (
    .vga_clk(vga_clk), .sys_rst_n(sys_rst_n),
    .click_pulse(click_pulse), .frame_tick(frame_tick),
    .screen_sel(screen_sel)
);
vga_pic vga_pic_inst (
    .vga_clk(vga_clk), .sys_rst_n(sys_rst_n),
    .pix_x(pix_x), .pix_y(pix_y),
    .screen_sel(screen_sel), .pix_data(pix_data)
);
vga_ctrl vga_ctrl_inst (
    .vga_clk(vga_clk), .sys_rst_n(sys_rst_n), .pix_data(pix_data),
    .pix_x(pix_x), .pix_y(pix_y), .hsync(hsync), .vsync(vsync),
    .rgb(rgb), .frame_tick(frame_tick)
);
endmodule
