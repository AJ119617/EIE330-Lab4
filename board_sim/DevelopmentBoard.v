`timescale 1ns/1ps

// EIE330 Simple-VGA-Simulator's real board wrapper for the Lab 4 top module.
// RESET and B2 are active-low virtual buttons; the other inputs are unused.
module DevelopmentBoard(
    input wire clk,
    input wire reset, B2, B3, B4, B5,
    output wire h_sync, v_sync,
    output wire [15:0] rgb,
    output wire led1, led2, led3, led4, led5
);
    lab4_top lab4_inst (
        .sys_clk(clk),
        .sys_rst_n(reset),
        .key_in(B2),
        .hsync(h_sync),
        .vsync(v_sync),
        .rgb(rgb)
    );

    // The extra virtual keys are unused by the Lab 4 design; LEDs just expose them.
    assign {led1, led2, led3, led4, led5} = {B3, B4, B5, 2'b11};
endmodule
