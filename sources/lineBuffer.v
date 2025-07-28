// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// MIT License
// 
// Copyright (c) 2025 Gwangsun Shin
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// -----------------------------------------------------------------------------

module lineBuffer#(
    parameter WIDTH = 320
)(
   input          i_clk,
   input          i_rst,
   input          i_data_valid,
   input  [7:0]   i_data_r,
   input  [7:0]   i_data_g,
   input  [7:0]   i_data_b,
   input          i_rd_data,
   output [31:0]  o_data_r, // 8bit x 4
   output [31:0]  o_data_g, // 8bit x 4
   output [31:0]  o_data_b // 8bit x 4
);

reg [7:0] line_r [0:1023];
reg [7:0] line_g [0:1023];
reg [7:0] line_b [0:1023];

reg [9:0]   wrPntr;
reg [9:0]   rdPntr;

always @(posedge i_clk) begin
   if (i_data_valid) begin
      line_r[wrPntr] <= i_data_r;
      line_g[wrPntr] <= i_data_g;
      line_b[wrPntr] <= i_data_b;
   end
end

always @(posedge i_clk) begin
    if (i_rst) begin
        wrPntr <= 'd0;
    end
    else if (i_data_valid) begin
        if (wrPntr == 319) begin
            wrPntr <= 'd0;
        end
        else begin
            wrPntr <= wrPntr + 'd1; 
        end
    end
end

always @(posedge i_clk) begin
    if (i_rst) begin
        rdPntr <= 'd0;
    end
    else if (i_rd_data) begin
        if (rdPntr == 319) begin
            rdPntr <= 'd0;
        end
        else begin
            rdPntr <= rdPntr + 'd1; 
        end
    end
end

assign o_data_r = {line_r[rdPntr], line_r[rdPntr+1], line_r[rdPntr+2], line_r[rdPntr+3]};
assign o_data_g = {line_g[rdPntr], line_g[rdPntr+1], line_g[rdPntr+2], line_g[rdPntr+3]};
assign o_data_b = {line_b[rdPntr], line_b[rdPntr+1], line_b[rdPntr+2], line_b[rdPntr+3]};

// assign o_data_r = {line_r[rdPntr+3], line_r[rdPntr+2], line_r[rdPntr+1], line_r[rdPntr]};
// assign o_data_g = {line_g[rdPntr+3], line_g[rdPntr+2], line_g[rdPntr+1], line_g[rdPntr]};
// assign o_data_b = {line_b[rdPntr+3], line_b[rdPntr+2], line_b[rdPntr+1], line_b[rdPntr]};
   
endmodule