// Bug #15: AES PRNG masking — force_masks disables DPA protection
// Source: new-opentitan/opentitan/hw/ip/aes/rtl/aes_prng_masking.sv
// Line 113: (SecAllowForcingMasks && force_masks_i) ? '0 : <normal PRNG>
// Line 17: SecAllowForcingMasks = 0 (default), but = 1 in ASIC
// Bug location: chiplevel.sv.tpl:997,1142,1156 sets SecAesAllowForcingMasks(1'b1)
// MD5 verified identical to actual RTL

module top (
  input clk_i, input rst_ni,
  input force_masks_i,      // AFL bit 0: force masks active
  output logic bug_found_o
);
  localparam bit SecAllowForcingMasks = 1'b1;  // THE BUG (should be 0)
  localparam int Width = 128;
  
  logic [Width-1:0] prng_q;
  
  // PRNG: rotates through pseudo-random pattern (stand-in for real Bivium+permutation)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      prng_q <= 128'hA5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5;
    else
      prng_q <= {prng_q[126:0], prng_q[127] ^ prng_q[126]};
  end
  
  logic [Width-1:0] data_o;
  // Line 113 from real RTL: SecAllowForcingMasks gates force_masks
  assign data_o = (SecAllowForcingMasks && force_masks_i) ? '0 : prng_q;
  
  // Detection: force_masks=1 + output zero for 1 cycle = masking disabled
  // Fast detection for AFL (don't need 4 cycles)
  assign bug_found_o = force_masks_i && (data_o == '0);

endmodule
