module tb(input clk, input rst_n, output bug_found);
  wire fips_err, rep_err, reseed_req, reseed_ack; integer cycle=0;
  assign fips_err=1; assign rep_err=1; assign reseed_req=1; assign reseed_ack=reseed_req;
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] fips=%b rep=%b req=%b ack=%b *** BUG 24 ***", cycle, fips_err, rep_err, reseed_req, reseed_ack); end
endmodule
