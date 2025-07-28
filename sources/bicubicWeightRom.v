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

module bicubic_rom2d (
    input  wire [1:0] ix,
    input  wire [1:0] iy,
    output reg  [255:0] matrix_out  // 16×16bit = 256bit
);

    // addr = {iy, ix}
    wire [3:0] addr = {iy, ix};

    always @(*) begin
        case (addr)
            // ix=0, iy=0
            4'b0000: matrix_out = 256'h
                0000_0000_0000_0000_0000_7FFF_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
            // ix=1, iy=0
            4'b0001: matrix_out = 256'h
                0000_0000_0000_0000_F700_6F00_1D00_FD00_0000_0000_0000_0000_0000_0000_0000_0000;
            // ix=2, iy=0
            4'b0010: matrix_out = 256'h
                0000_0000_0000_0000_F800_4800_4800_F800_0000_0000_0000_0000_0000_0000_0000_0000;
            // ix=3, iy=0
            4'b0011: matrix_out = 256'h
                0000_0000_0000_0000_FD00_1D00_6F00_F700_0000_0000_0000_0000_0000_0000_0000_0000;

            // ix=0, iy=1
            4'b0100: matrix_out = 256'h
                0000_F700_0000_0000_0000_6F00_0000_0000_0000_1D00_0000_0000_0000_FD00_0000_0000;
            // ix=1, iy=1
            4'b0101: matrix_out = 256'h
                00A2_F832_FDF6_0036_F832_6042_1926_FD66_FDF6_1926_0692_FF52_0036_FD66_FF52_0012;
            // ix=2, iy=1
            4'b0110: matrix_out = 256'h
                0090_FAF0_FAF0_0090_F910_3E70_3E70_F910_FE30_1050_1050_FE30_0030_FE50_FE50_0030;
            // ix=3, iy=1
            4'b0111: matrix_out = 256'h
                0036_FDF6_F832_00A2_FD66_1926_6042_F832_FF52_0692_1926_FDF6_0012_FF52_FD66_0036;

            // ix=0, iy=2
            4'b1000: matrix_out = 256'h
                0000_F800_0000_0000_0000_4800_0000_0000_0000_4800_0000_0000_0000_F800_0000_0000;
            // ix=1, iy=2
            4'b1001: matrix_out = 256'h
                0090_F910_FE30_0030_FAF0_3E70_1050_FE50_FAF0_3E70_1050_FE50_0090_F910_FE30_0030;
            // ix=2, iy=2
            4'b1010: matrix_out = 256'h
                0080_FB80_FB80_0080_FB80_2880_2880_FB80_FB80_2880_2880_FB80_0080_FB80_FB80_0080;
            // ix=3, iy=2
            4'b1011: matrix_out = 256'h
                0030_FE30_F910_0090_FE50_1050_3E70_FAF0_FE50_1050_3E70_FAF0_0030_FE30_F910_0090;

            // ix=0, iy=3
            4'b1100: matrix_out = 256'h
                0000_FD00_0000_0000_0000_1D00_0000_0000_0000_6F00_0000_0000_0000_F700_0000_0000;
            // ix=1, iy=3
            4'b1101: matrix_out = 256'h
                0036_FD66_FF52_0012_FDF6_1926_0692_FF52_F832_6042_1926_FD66_00A2_F832_FDF6_0036;
            // ix=2, iy=3
            4'b1110: matrix_out = 256'h
                0030_FE50_FE50_0030_FE30_1050_1050_FE30_F910_3E70_3E70_F910_0090_FAF0_FAF0_0090;
            // ix=3, iy=3
            4'b1111: matrix_out = 256'h
                0012_FF52_FD66_0036_FF52_0692_1926_FDF6_FD66_1926_6042_F832_0036_FDF6_F832_00A2;

            default: matrix_out = {16{16'h0000}}; 
        endcase
    end

endmodule
