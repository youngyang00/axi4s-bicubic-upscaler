/*

MIT License

Copyright (c) 2025 Gwangsun Shin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

module pipelined_multiplier_2stage#(
  parameter INPUT_WIDTH = 18
)(
  input                   i_clk,
  input                   i_reset,
  input                   i_valid,
  input  signed [INPUT_WIDTH-1:0]    i_A,
  input  signed [INPUT_WIDTH-1:0]    i_B,
  output signed [INPUT_WIDTH*2-1:0]  o_out,
  output                  o_valid
);

  localparam HALF = INPUT_WIDTH/2;

  wire signed [HALF:0] B_lo_ext = {{1{1'b0}}, i_B[HALF-1:0]};  
  wire signed [HALF-1:0] B_hi    = i_B[INPUT_WIDTH-1:HALF];

  reg valid_1, valid_2;

  reg signed [INPUT_WIDTH+HALF-1:0] reg_p_lo;
  reg signed [INPUT_WIDTH+HALF-1:0] reg_p_hi;


  reg signed [INPUT_WIDTH*2-1:0] p;


  (* use_dsp = "no" *) 
  wire signed [INPUT_WIDTH+HALF-1:0] p_lo = $signed(i_A) * B_lo_ext;
  (* use_dsp = "no" *) 
  wire signed [INPUT_WIDTH+HALF-1:0] p_hi = $signed(i_A) * $signed(B_hi);

  always @(posedge i_clk) begin
    if (i_reset) begin
      valid_1  <= 1'b0;
      reg_p_lo <= 'd0;
      reg_p_hi <= 'd0;
    end else begin
      valid_1 <= i_valid;
      if (i_valid) begin
        reg_p_lo <= p_lo;
        reg_p_hi <= p_hi;
      end
    end
  end


  always @(posedge i_clk) begin
    if (i_reset) begin
      valid_2 <= 1'b0;
      p       <= 'd0;
    end else begin
      valid_2 <= valid_1;
      if (valid_1) begin
        p <= (reg_p_hi <<< HALF) + reg_p_lo;
      end
    end
  end

  assign o_out   = p;
  assign o_valid = valid_2;

endmodule
