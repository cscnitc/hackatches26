module tb(input clk, input rst_n);
  reg digest_match_q, fault; integer cycle;
  always @(posedge clk) begin cycle <= cycle + 1; if(rst_n) begin
    digest_match_q <= fault; $display("[t=%0d] fault=%b digest_match=%b *** BUG: single-bit FF ***", cycle, fault, digest_match_q);
    fault <= ~fault; end
  end
endmodule
