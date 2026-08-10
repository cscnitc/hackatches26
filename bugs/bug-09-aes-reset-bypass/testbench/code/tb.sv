module tb(input clk, input rst_n, output logic bug_found);
  logic [7:0] data_out_q, data_in; logic we; integer cycle=0;
  assign data_in = 222; assign we = 1;
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n && !we) data_out_q<=0; else if(we) data_out_q<=data_in;
  end
  always @(posedge clk) begin cycle=cycle+1; if(rst_n && data_out_q!=0) begin bug_found<=1; $display("[t=%0d] data_out=%h *** BUG 16 ***", cycle, data_out_q); end end
endmodule
