module bug2_real_tb(input clk, input rst_n);
  wire authenticated = 1'b1;  // dm_csrs.sv:231 — THE BUG
  
  always @(posedge clk) begin
    if (rst_n) begin
      $display("[t=%0d] RST=%b CLK=%b AUTH=%b", $time, rst_n, clk, authenticated);
      if (authenticated) $display("*** BUG CONFIRMED: authenticated hardwired to 1 ***");
    end
  end
endmodule
