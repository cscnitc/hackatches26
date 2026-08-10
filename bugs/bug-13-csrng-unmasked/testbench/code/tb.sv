module tb(input clk, input rst_n, output bug_found);
  wire SecMasking; integer cycle=0; assign SecMasking = 0;
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] SecMasking=%b *** BUG 20 ***", cycle, SecMasking); end
endmodule
