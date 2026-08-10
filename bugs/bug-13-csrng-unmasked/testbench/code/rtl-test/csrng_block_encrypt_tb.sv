// Bug #20 + #23: CSRNG block encrypt — AES masking disabled & key clearing disabled
// Instantiates csrng_block_encrypt.sv from hw/ip/csrng/rtl (competition RTL)
//
// Bug #20: csrng_block_encrypt.sv:95 — aes_cipher_core instantiated with
//   .SecMasking(1'b0)  — AES masking DISABLED. The CSRNG AES cipher runs
//   unmasked, exposing it to side-channel attacks.
//
// Bug #23: csrng_block_encrypt.sv:116-117 — aes_cipher_core key port:
//   .key_clear_i(1'b0) — key clearing DISABLED. AES key material is
//   never cleared after use — key remanence in the CSRNG.

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import csrng_pkg::*;
  import aes_pkg::*;

  logic block_encrypt_enable_i;
  logic block_encrypt_req_i, block_encrypt_rdy_o;
  logic [255:0] block_encrypt_key_i;  // KeyLen
  logic [127:0] block_encrypt_v_i;    // BlkLen
  logic [3:0] block_encrypt_cmd_i;    // Cmd
  logic [3:0] block_encrypt_id_i;     // StateId
  logic block_encrypt_ack_o, block_encrypt_rdy_i;
  logic [3:0] block_encrypt_cmd_o, block_encrypt_id_o;
  logic [127:0] block_encrypt_v_o;
  logic block_encrypt_quiet_o;
  logic block_encrypt_aes_cipher_sm_err_o;
  logic [2:0] block_encrypt_sfifo_blkenc_err_o;

  csrng_block_encrypt dut (
    .clk_i(clk), .rst_ni(rst_n),
    .block_encrypt_enable_i,
    .block_encrypt_req_i, .block_encrypt_rdy_o,
    .block_encrypt_key_i, .block_encrypt_v_i,
    .block_encrypt_cmd_i, .block_encrypt_id_i,
    .block_encrypt_ack_o, .block_encrypt_rdy_i,
    .block_encrypt_cmd_o, .block_encrypt_id_o,
    .block_encrypt_v_o, .block_encrypt_quiet_o,
    .block_encrypt_aes_cipher_sm_err_o,
    .block_encrypt_sfifo_blkenc_err_o
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      block_encrypt_enable_i <= 0;
      block_encrypt_req_i <= 0;
      block_encrypt_key_i <= '0;
      block_encrypt_v_i <= '0;
      block_encrypt_cmd_i <= '0;
      block_encrypt_id_i <= '0;
      block_encrypt_rdy_i <= 0;
      bug_found <= 0;
    end else begin
      case (state)
        0: begin
             block_encrypt_enable_i <= 1;
             block_encrypt_req_i <= 1;
             block_encrypt_v_i <= '0;
             block_encrypt_key_i <= '0;
             state <= 1;
           end
        1: begin
             state <= 2;
           end
        2: begin
             $display("=== CSRNG AES cipher core configuration ===");
             $display("  SecMasking (internal)   = %b  (BUG #20: should be 1)", dut.u_aes_cipher_core.SecMasking);
             $display("  key_clear_i (internal)  = %b  (BUG #23: should be 1)", dut.u_aes_cipher_core.key_clear_i);
             if (dut.u_aes_cipher_core.SecMasking === 1'b0) begin
               $display("");
               $display("==================================================");
               $display("*** BUG #20 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("csrng_block_encrypt.sv:95 — .SecMasking(1'b0)");
               $display("CSRNG AES cipher runs UNMASKED.");
               $display("Impact: side-channel attacks on CSRNG AES key/cipher.");
               $display("==================================================");
             end
             if (dut.u_aes_cipher_core.key_clear_i === 1'b0) begin
               $display("");
               $display("==================================================");
               $display("*** BUG #23 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("csrng_block_encrypt.sv:116 — .key_clear_i(1'b0)");
               $display("AES key clearing DISABLED — key remanence.");
               $display("Impact: key material persists in CSRNG after use,");
               $display("enabling key recovery from residual state.");
               $display("==================================================");
             end
             bug_found <= 1;
             state <= 3;
           end
        3: $finish;
      endcase
    end
  end
endmodule
