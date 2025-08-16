`ifndef INC_SCOREBOARD
`define INC_SCOREBOARD
`include "imageProcessPkg.sv"
import imageProcessPkg::*;
class Scoreboard;
   mailbox #(int) in_box;
   int            width;
   int            depth;
   int            frame_count;
   int            frame_r_ref[][];
   int            frame_g_ref[][];
   int            frame_b_ref[][];
   static int     received_Frame = 0;
   logic [7:0]    red,green,blue;
   real           coverage_result;


   covergroup pixelCov;
      coverpoint red;
      coverpoint green;
      coverpoint blue;
   endgroup

function new(mailbox #(int) in_box,
             int width, int depth,
             int frame_count);
   this.in_box = in_box;
   this.width = width;
   this.depth = depth;
   this.frame_count = frame_count;

   pixelCov = new();
endfunction

task RefLoad(int fidx);
   string filename;
   int fd;
   string line;
   int x,y;
   int code;
   int r_val,g_val,b_val;
   filename = $sformatf("output_pixels%0d.txt", fidx);
   fd = $fopen(filename, "r");
   if (fd == 0) begin
      $display("ERROR: Cannot open file %s", filename);
      $finish;
   end
   if (!$fgets(line, fd)) begin
      $display("ERROR: Empty file %s", filename);
      $finish;
   end

   frame_r_ref = new[width];
   frame_g_ref = new[width];
   frame_b_ref = new[width];
   for (int i = 0; i < width ; i++) begin
      frame_r_ref[i] = new[depth];
      frame_g_ref[i] = new[depth];
      frame_b_ref[i] = new[depth];
   end

   while (!$feof(fd)) begin
      if (!$fgets(line, fd)) break;
      // 주석(#) 또는 빈 줄 skip
      if (line.len() == 0 || line.substr(0,1) == "#") continue;
      // 행 파싱
      code = $sscanf(line, "%d %d %h %h %h", x, y, r_val, g_val, b_val);
      if (code != 5) begin
         $display("ERROR: Malformed line: %s", line);
         $finish;
      end
      frame_r_ref[x][y] = r_val;
      frame_g_ref[x][y] = g_val;
      frame_b_ref[x][y] = b_val;
   end
endtask

task evalValue();
   int            pixels;
   forever begin
      RefLoad(received_Frame + 1);
      for (int y = 0; y < depth; y++) begin
         for (int x = 0; x < width; x++) begin
            in_box.get(pixels);
            red   = pixels[7:0];
            green = pixels[15:8];
            blue  = pixels[23:16];
            if(!valueCompare(real'(red),real'(frame_r_ref[x][y]),0.01, 255)&&
               !valueCompare(real'(green),real'(frame_g_ref[x][y]),0.01, 255) &&
               !valueCompare(real'(blue),real'(frame_b_ref[x][y]),0.01, 255))begin
               $display("\nTest Passed [Frame%0d][x:%0d][y:%0d] R:%0h, G:%0h, B:%0h",
               received_Frame, x, y, red, green, blue);      
            end
            else begin
               $display("\nTest failed [Frame%0d][x:%0d][y:%0d] Ref:R:%0h, G:%0h, B:%0h Received Value: R:%0h, G:%0h, B:%0h at %0dns",received_Frame,x, y, frame_r_ref[x][y], frame_g_ref[x][y], frame_b_ref[x][y],red, green, blue, $realtime);
               $finish;
            end
            pixelCov.sample();
            coverage_result = $get_coverage();
            $display("cvrg = %3.2f",coverage_result);
         end
      end
      received_Frame++;
   end
endtask

task run();
   evalValue();
endtask



endclass
`endif