module tb(input clk, input rst_n, output bug_found);
  wire SecAllowForcingMasks; integer cycle=0;
  assign SecAllowForcingMasks = 1; // 1b1
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] SecAllowForcingMasks=%b *** BUG 15 ***", cycle, SecAllowForcingMasks); end
endmodule
