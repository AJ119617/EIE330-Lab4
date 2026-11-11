`timescale 1ns/1ps

// Reused from Lab 3: 50 MHz board clock divided by two for 25 MHz VGA.
module pll (
    input wire sys_clk,
    input wire sys_rst_n,
    output reg vga_clk
);
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        vga_clk <= 1'b0;
    else
        vga_clk <= ~vga_clk;
end
endmodule
