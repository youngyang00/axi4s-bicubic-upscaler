`timescale 1ns/1ps
`include "axi4s_io.sv"
`include "Generator.sv"
`include "Driver.sv"
`include "Receiver.sv"
`include "Scoreboard.sv"

module tb_bicubic;
   logic clk = 0;
   axi4s_io tb_if(clk);

bicubicResizer DUT(
   .i_clk(clk),
   .i_rstn(tb_if.i_rstn),
   .s_axis_tdata(tb_if.s_axis_tdata), // MSB {8'hx,B,G,R} LSB
   .s_axis_tvalid(tb_if.s_axis_tvalid),
   .s_axis_tready(tb_if.s_axis_tready),
   .m_axis_tdata(tb_if.m_axis_tdata),
   .m_axis_tvalid(tb_if.m_axis_tvalid),
   .m_axis_tready(tb_if.m_axis_tready),
   .EOL(),
   .EOF()
);


//    design_1_wrapper dut (
//      .S_AXIS_tdata  (tb_if.s_axis_tdata),
//      .S_AXIS_tready (tb_if.s_axis_tready),
//      .S_AXIS_tuser  (/* unused */),
//      .S_AXIS_tvalid (tb_if.s_axis_tvalid),
//      .m_axis_0_tdata  (tb_if.m_axis_tdata),
//      .m_axis_0_tready (tb_if.m_axis_tready),
//      .m_axis_0_tvalid (tb_if.m_axis_tvalid),
//      .s_aclk        (clk),
//      .s_aresetn     (tb_if.i_rstn)
//    );
   
   mailbox #(int) mbox_drv = new();
   mailbox #(int) mbox_Recv = new();
   Generator gen;
   Driver drv;
   Receiver recv;
   Scoreboard sc;

  always #5 clk = ~clk;

  initial begin
   automatic int width = 320;
   automatic int depth = 180;
   automatic int frame_count = 2;
   automatic int burst_len = 500;
   automatic int pause_cycles = 1;
   automatic int out_width = 4*width;
   automatic int out_depth = 4*depth;

   gen = new("gen", width, depth, frame_count, mbox_drv);
   drv = new(tb_if.TB, mbox_drv, burst_len, pause_cycles);
   recv = new(tb_if.TB, mbox_Recv ,100 ,1);
   sc = new(mbox_Recv, out_width, out_depth, frame_count);

   fork
      drv.run();
      gen.run();
      recv.run();
      sc.run();
   join
  end
endmodule