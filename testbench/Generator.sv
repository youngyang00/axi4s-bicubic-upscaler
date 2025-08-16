`ifndef INC_GENERATOR_SV
`define INC_GENERATOR_SV
`include "imageProcessPkg.sv"
import imageProcessPkg::*;

class Generator;
mailbox #(int) out_box;
int            width;
int            depth;
int            frame_count;
int            frame_r[][];
int            frame_g[][];
int            frame_b[][];

function new(string name = "Generator",
             int width = 0,
             int depth = 0,
             int frame_count = 0,
             mailbox #(int) out_box = null);
   this.width       = width;
   this.depth       = depth;
   this.frame_count = frame_count;
   this.out_box     = out_box;
endfunction

task gen(int fidx);
   string filename;
   frame_r = new[width];
   frame_g = new[width];
   frame_b = new[width];
   for (int i = 0; i < width; i++) begin
      frame_r[i] = new[depth];
      frame_g[i] = new[depth];
      frame_b[i] = new[depth];
   end
   filename = $sformatf("input_pixels%0d.txt", fidx);
   readPixelTxt_RGB(filename, frame_r, frame_g, frame_b);
endtask

task send();
   int pixel;
   for (int y = 0; y < depth; y++) begin
      for (int x = 0; x < width ;x++) begin
         pixel = {8'h0, byte'(frame_b[x][y]),byte'(frame_g[x][y]), byte'(frame_r[x][y])};
         out_box.put(pixel);
      end
   end
endtask

task run();
   for (int i = 1; i <=frame_count; i++) begin
      gen(i);
      send();
   end
endtask
endclass
`endif