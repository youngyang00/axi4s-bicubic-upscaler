`ifndef INC_DRIVER_SV
`define INC_DRIVER_SV
`include "axi4s_io.sv"
class Driver;
   mailbox #(int)    in_box;
   virtual axi4s_io  vif;
   int               burst_len;
   int               pause_cycles;
   static int        DrivedFrameNum = 0;

   function new(virtual axi4s_io.TB vif = null,
                mailbox #(int) in_box,
                int burst_len,
                int pause_cycles);
      this.vif = vif;
      this.in_box = in_box;
      this.burst_len = burst_len;
      this.pause_cycles = pause_cycles;
   endfunction

   task reset_seq();
      @(vif.cb);
      vif.cb.i_rstn <= 0;
      repeat(10)@(vif.cb);
      vif.cb.i_rstn <= 1;
      @(vif.cb);
      vif.signal_drv.s_axis_tvalid <= 0;
   endtask

   task drive_frame();
      int burst_count = 0;
      int pixel;
      vif.signal_drv.s_axis_tvalid <= 0;
      forever begin
         @(vif.cb);
         in_box.get(pixel);
         wait (vif.cb.s_axis_tready);
         vif.cb.s_axis_tdata <= pixel;
         vif.signal_drv.s_axis_tvalid <= 1;
         burst_count++;
         if ((burst_count >= burst_len)) begin
            @(vif.cb);
            wait(vif.cb.s_axis_tready);
            vif.signal_drv.s_axis_tvalid <= 0;
            repeat(pause_cycles) @(vif.cb);
            burst_count = 0;
         end
      end
   endtask

   task run();
      reset_seq();
      drive_frame();
   endtask

endclass
`endif