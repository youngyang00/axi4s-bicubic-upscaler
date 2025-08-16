`ifndef INC_RECEIVER_SV
`define INC_RECEIVER_SV
`include "axi4s_io.sv"
class Receiver;
   virtual axi4s_io.TB vif;
   mailbox#(int) out_box;
   integer master_ready_pause_cycles;
   integer master_ready_burst_len;
   int red,green,blue;

   function new(virtual axi4s_io.TB vif = null,
                mailbox #(int) out_box,
                int master_ready_burst_len = 20,
                int master_ready_pause_cycles = 5);
      this.vif = vif;
      this.master_ready_burst_len = master_ready_burst_len;
      this.master_ready_pause_cycles = master_ready_pause_cycles;
      this.out_box = out_box;
   endfunction

   task GenReady();
      forever begin
         @(vif.cb);
         vif.signal_drv.m_axis_tready <= 0;
         for (int i = 0; i < master_ready_burst_len; i++) begin
            @(vif.cb);
            vif.signal_drv.m_axis_tready <= 1;
         end
         @(vif.cb);
         wait(vif.cb.m_axis_tvalid == 1);
         vif.signal_drv.m_axis_tready <= 0;
         for (int i = 0; i < master_ready_pause_cycles ;i++) begin
            @(vif.cb);
         end  
      end
   endtask

   task recv();
      @(vif.cb);
      if (vif.cb.m_axis_tvalid && vif.signal_smp.m_axis_tready) begin
         red   = vif.cb.m_axis_tdata[7:0];
         green = vif.cb.m_axis_tdata[15:8];
         blue  = vif.cb.m_axis_tdata[23:16];
         out_box.put({byte'(blue),byte'(green),byte'(red)});
      end
   endtask

   task run();
   fork
      GenReady();
      begin
         forever begin
            recv();
         end
      end
   join
   endtask
endclass

`endif