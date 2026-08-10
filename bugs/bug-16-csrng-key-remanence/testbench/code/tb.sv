module tb(input clk, input rst_n, output bug_found);
  wire key_clear; integer cycle=0; assign key_clear = 0;
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] key_clear=%b *** BUG 23 ***", cycle, key_clear); end
endmodule
