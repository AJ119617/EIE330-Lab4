`timescale 1ns/1ps

// Moore state machine: current state alone selects the active screen.
// A debounced click is remembered and applied at the next frame boundary,
// avoiding a visible split frame when the button is pressed mid-scan.
module screen_fsm (
    input wire vga_clk,
    input wire sys_rst_n,
    input wire click_pulse,
    input wire frame_tick,
    output wire [1:0] screen_sel
);
localparam [1:0] BARS=2'd0, MUST=2'd1, END_SCREEN=2'd2;
reg [1:0] state;
reg pending_click;
assign screen_sel = state;

always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        state <= BARS;
        pending_click <= 1'b0;
    end else begin
        if (click_pulse)
            pending_click <= 1'b1;
        if (frame_tick && (pending_click || click_pulse)) begin
            pending_click <= 1'b0;
            case (state)
                BARS:       state <= MUST;
                MUST:       state <= END_SCREEN;
                END_SCREEN: state <= BARS;
                default:    state <= BARS;
            endcase
        end
    end
end
endmodule
