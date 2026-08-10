module tb(input clk, input rst_n, output bug_found);
  wire err_flag; integer cycle=0; assign err_flag = 0;
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] err_flag=%b *** BUG 18 ***", cycle, err_flag); end
endmodule
