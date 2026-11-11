`timescale 1ns/1ps

// Lab 3 VGA controller with an added frame_tick for tear-free page changes.
// The display consumes the registered pix_data one pixel clock after pix_x/y
// are requested. 800 x 525 at 25 MHz gives 59.524 Hz, approximately 60 Hz.
module vga_ctrl (
    input wire vga_clk,
    input wire sys_rst_n,
    input wire [15:0] pix_data,
    output wire [9:0] pix_x,
    output wire [9:0] pix_y,
    output wire hsync,
    output wire vsync,
    output wire [15:0] rgb,
    output wire frame_tick
);
localparam [9:0] H_SYNC=10'd96, H_BACK=10'd40, H_LEFT=10'd8;
localparam [9:0] H_VALID=10'd640, H_RIGHT=10'd8, H_FRONT=10'd8;
localparam [9:0] V_SYNC=10'd2, V_BACK=10'd25, V_TOP=10'd8;
localparam [9:0] V_VALID=10'd480, V_BOTTOM=10'd8, V_FRONT=10'd2;
localparam [9:0] H_START=H_SYNC+H_BACK+H_LEFT;
localparam [9:0] V_START=V_SYNC+V_BACK+V_TOP;
localparam [9:0] H_TOTAL=H_START+H_VALID+H_RIGHT+H_FRONT;
localparam [9:0] V_TOTAL=V_START+V_VALID+V_BOTTOM+V_FRONT;
reg [9:0] cnt_h;
reg [9:0] cnt_v;
wire rgb_valid;
wire pix_data_req;

always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        cnt_h <= 10'd0;
    else if (cnt_h == H_TOTAL-10'd1)
        cnt_h <= 10'd0;
    else
        cnt_h <= cnt_h+10'd1;
end

always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        cnt_v <= 10'd0;
    else if (cnt_h == H_TOTAL-10'd1) begin
        if (cnt_v == V_TOTAL-10'd1)
            cnt_v <= 10'd0;
        else
            cnt_v <= cnt_v+10'd1;
    end
end

assign hsync = (cnt_h < H_SYNC);
assign vsync = (cnt_v < V_SYNC);
assign rgb_valid = sys_rst_n &&
    (cnt_h >= H_START) && (cnt_h < H_START+H_VALID) &&
    (cnt_v >= V_START) && (cnt_v < V_START+V_VALID);
assign pix_data_req = sys_rst_n &&
    (cnt_h >= H_START-10'd1) && (cnt_h < H_START+H_VALID-10'd1) &&
    (cnt_v >= V_START) && (cnt_v < V_START+V_VALID);
assign pix_x = pix_data_req ? cnt_h-(H_START-10'd1) : 10'h3ff;
assign pix_y = pix_data_req ? cnt_v-V_START : 10'h3ff;
assign rgb = rgb_valid ? pix_data : 16'h0000;
assign frame_tick = (cnt_h == H_TOTAL-10'd1) &&
                    (cnt_v == V_TOTAL-10'd1);
endmodule
