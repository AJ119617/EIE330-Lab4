`timescale 1ns/1ps

// One registered pixel generator for all three screens. pix_x/y are the
// Lab 3 one-clock-ahead requests; pix_data arrives at the active pixel.
module vga_pic (
    input wire vga_clk,
    input wire sys_rst_n,
    input wire [9:0] pix_x,
    input wire [9:0] pix_y,
    input wire [1:0] screen_sel,
    output reg [15:0] pix_data
);
localparam [1:0] BARS=2'd0, MUST=2'd1, END_SCREEN=2'd2;
localparam [2:0] CHAR_M=3'd0, CHAR_U=3'd1, CHAR_S=3'd2,
                 CHAR_T=3'd3, CHAR_E=3'd4, CHAR_N=3'd5,
                 CHAR_D=3'd6;
localparam [15:0] BLACK=16'h0000, WHITE=16'hffff;
// Each bitmap contains eight rows, from top to bottom, most significant
// bit first. The four MUST glyphs reuse Lab 3's 8x8 glyph patterns.
localparam [63:0] M_BITS={8'b11000011, 8'b11100111,
                         8'b11111111, 8'b11011011,
                         8'b11000011, 8'b11000011,
                         8'b11000011, 8'b11000011};
localparam [63:0] U_BITS={8'b11000011, 8'b11000011,
                         8'b11000011, 8'b11000011,
                         8'b11000011, 8'b11000011,
                         8'b01100110, 8'b00111100};
localparam [63:0] S_BITS={8'b01111110, 8'b11000000,
                         8'b11000000, 8'b01111110,
                         8'b00000011, 8'b00000011,
                         8'b11000011, 8'b01111110};
localparam [63:0] T_BITS={8'b11111111, 8'b11111111,
                         8'b00011000, 8'b00011000,
                         8'b00011000, 8'b00011000,
                         8'b00011000, 8'b00011000};
localparam [63:0] E_BITS={8'b11111111, 8'b11000000,
                         8'b11000000, 8'b11111110,
                         8'b11000000, 8'b11000000,
                         8'b11000000, 8'b11111111};
localparam [63:0] N_BITS={8'b11000011, 8'b11100011,
                         8'b11110011, 8'b11011011,
                         8'b11001111, 8'b11000111,
                         8'b11000011, 8'b11000011};
localparam [63:0] D_BITS={8'b11111100, 8'b11000110,
                         8'b11000011, 8'b11000011,
                         8'b11000011, 8'b11000011,
                         8'b11000110, 8'b11111100};

function glyph_on;
    input [2:0] glyph;
    input [2:0] row;
    input [2:0] col;
    reg [63:0] bitmap;
    begin
        case (glyph)
            CHAR_M: bitmap=M_BITS;
            CHAR_U: bitmap=U_BITS;
            CHAR_S: bitmap=S_BITS;
            CHAR_T: bitmap=T_BITS;
            CHAR_E: bitmap=E_BITS;
            CHAR_N: bitmap=N_BITS;
            CHAR_D: bitmap=D_BITS;
            default: bitmap=64'd0;
        endcase
        glyph_on=bitmap[6'd63-{row,col}];
    end
endfunction

wire [9:0] local_y = pix_y-10'd208;
wire [2:0] glyph_row = local_y[5:3];
reg [15:0] next_pixel;
reg [2:0] glyph;
reg [9:0] local_x;
reg in_glyph;
always @* begin
    next_pixel=BLACK;
    glyph=CHAR_M;
    local_x=10'd0;
    in_glyph=1'b0;
    if ((pix_x<10'd640) && (pix_y<10'd480)) begin
        case (screen_sel)
            BARS: begin
                // Eight equal-width bars, x ranges [0,80),...,[560,640).
                if (pix_x < 10'd80)       next_pixel=16'hffff; // white
                else if (pix_x < 10'd160) next_pixel=16'hffe0; // yellow
                else if (pix_x < 10'd240) next_pixel=16'h07ff; // cyan
                else if (pix_x < 10'd320) next_pixel=16'h07e0; // green
                else if (pix_x < 10'd400) next_pixel=16'hf81f; // magenta
                else if (pix_x < 10'd480) next_pixel=16'hf800; // red
                else if (pix_x < 10'd560) next_pixel=16'h001f; // blue
                else                      next_pixel=BLACK;
            end
            MUST: begin
                if ((pix_y >= 10'd208) && (pix_y < 10'd272)) begin
                    if ((pix_x >= 10'd168) && (pix_x < 10'd232)) begin
                        glyph=CHAR_M; local_x=pix_x-10'd168; in_glyph=1'b1;
                    end else if ((pix_x >= 10'd248) && (pix_x < 10'd312)) begin
                        glyph=CHAR_U; local_x=pix_x-10'd248; in_glyph=1'b1;
                    end else if ((pix_x >= 10'd328) && (pix_x < 10'd392)) begin
                        glyph=CHAR_S; local_x=pix_x-10'd328; in_glyph=1'b1;
                    end else if ((pix_x >= 10'd408) && (pix_x < 10'd472)) begin
                        glyph=CHAR_T; local_x=pix_x-10'd408; in_glyph=1'b1;
                    end
                end
                if (in_glyph && glyph_on(glyph, glyph_row,
                                         local_x[5:3]))
                    next_pixel=WHITE;
            end
            END_SCREEN: begin
                if ((pix_y >= 10'd208) && (pix_y < 10'd272)) begin
                    if ((pix_x >= 10'd208) && (pix_x < 10'd272)) begin
                        glyph=CHAR_E; local_x=pix_x-10'd208; in_glyph=1'b1;
                    end else if ((pix_x >= 10'd288) && (pix_x < 10'd352)) begin
                        glyph=CHAR_N; local_x=pix_x-10'd288; in_glyph=1'b1;
                    end else if ((pix_x >= 10'd368) && (pix_x < 10'd432)) begin
                        glyph=CHAR_D; local_x=pix_x-10'd368; in_glyph=1'b1;
                    end
                end
                if (in_glyph && glyph_on(glyph, glyph_row,
                                         local_x[5:3]))
                    next_pixel=WHITE;
            end
            default: next_pixel=BLACK;
        endcase
    end
end

always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        pix_data <= BLACK;
    else
        pix_data <= next_pixel;
end
endmodule
