module tb(input clk, input rst_n, output bug_found);
  reg digest_match_q, fault; integer cycle=0;
  always @(posedge clk) begin cycle=cycle+1; digest_match_q<=fault; fault<=~fault; if(rst_n) $display("[t=%0d] fault=%b match=%b *** BUG 21 ***", cycle, fault, digest_match_q); end
endmodule
