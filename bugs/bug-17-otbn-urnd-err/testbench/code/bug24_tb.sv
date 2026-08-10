module tb(input clk, input rst_n);
  reg fips_err, rep_err, req; wire ack = req; integer cycle;
  always @(posedge clk) begin cycle <= cycle + 1; if(rst_n) begin
    fips_err<=1; rep_err<=1; req<=1;
    $display("[t=%0d] fips=%b rep=%b req=%b ack=%b *** BUG: no err gate ***", cycle, fips_err, rep_err, req, ack); end
  end
endmodule
