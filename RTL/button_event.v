`timescale 1ns/1ps

// Synchronize an active-low mechanical key and emit exactly one cycle-wide
// event after a stable press. A stable release rearms the next press.
// The default 500000 VGA-clock cycles at 25 MHz = 20 ms, longer than the
// specified 5-10 ms of contact bounce. Reset is asynchronous and immediate.
module button_event #(
    parameter integer DEBOUNCE_CYCLES = 500000
) (
    input wire vga_clk,
    input wire sys_rst_n,
    input wire key_in,
    output reg click_pulse
);
localparam integer COUNT_W = $clog2(DEBOUNCE_CYCLES+1);
localparam [COUNT_W-1:0] COUNT_LIMIT = DEBOUNCE_CYCLES-1;
reg key_meta;
reg key_sync;
reg stable_key;
reg armed;
reg [COUNT_W-1:0] debounce_count;

always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        // Initialize synchronizers low: a key already held through reset
        // must not be mistaken for a fresh press on reset release.
        key_meta <= 1'b0;
        key_sync <= 1'b0;
        stable_key <= 1'b1;
        armed <= 1'b0;
        debounce_count <= {COUNT_W{1'b0}};
        click_pulse <= 1'b0;
    end else begin
        key_meta <= key_in;
        key_sync <= key_meta;
        click_pulse <= 1'b0;
        if (stable_key && key_sync)
            armed <= 1'b1;

        if (key_sync == stable_key)
            debounce_count <= {COUNT_W{1'b0}};
        else if (debounce_count == COUNT_LIMIT) begin
            debounce_count <= {COUNT_W{1'b0}};
            stable_key <= key_sync;
            if (key_sync)
                armed <= 1'b1;
            else if (armed)
                click_pulse <= 1'b1;
        end else
            debounce_count <= debounce_count + 1'b1;
    end
end
endmodule
