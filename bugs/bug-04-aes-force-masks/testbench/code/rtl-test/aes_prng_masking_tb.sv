// Bug #15: AES force masks — masking PRNG can be locked to all-zero — ACTUAL RTL test
// Instantiates aes_prng_masking.sv from hw/ip/aes/rtl (competition RTL)
//
// Bug: chip_earlgrey_*.sv instantiate top_earlgrey with SecAesAllowForcingMasks=1'b1
// (must be 1'b0 per static assertion AesSecAllowForcingMasksNonDefault).
//
// Attack (matches sw/device/lib/testing/aes_testutils.c kAesMaskingPrngZeroOutputSeed
// + aes_sca.c): software sets CTRL_AUX_SHADOWED.FORCE_MASKS=1 and feeds an
// all-zero seed to the masking PRNG. In prim_trivium:
//   lockup = ~(|state_q);  restore = lockup & (StrictLockupProtection | ~allow_lockup_i)
// With SecAllowForcingMasks=1 -> StrictLockupProtection=0 and allow_lockup_i=1,
// restore=0 -> the all-zero state is KEPT -> key stream = 0 -> masks CONSTANT ZERO.
// Normal config (SecAllowForcingMasks=0) auto-restores from lockup (mask != 0).
//
// Two phases:
//  A) force_masks_i=0 + zero seed: state auto-restores (mask != 0)
//  B) force_masks_i=1 + zero seed: lockup kept (mask == 0)  <-- BUG

module tb(
  input logic clk,
  input logic rst_n,
  output logic [3:0] state,
  output logic bug_found
);
  import aes_pkg::*;
  import edn_pkg::*;

  localparam int unsigned Width = 2*2*32;  // PRDMasking width used in aes_cipher_core
  localparam int unsigned EntropyWidth = edn_pkg::ENDPOINT_BUS_WIDTH;

  logic force_masks_i;
  logic data_update_i;
  logic [Width-1:0] data_o;
  logic reseed_req_i, reseed_ack_o;
  logic entropy_req_o, entropy_ack_i;
  logic [EntropyWidth-1:0] entropy_i;

  logic [Width-1:0] phaseA_mask, phaseB_mask;
  logic [Width-1:0] phaseA_mask2, phaseB_mask2;

  // BUG: SecAllowForcingMasks=1 (chip_earlgrey sets this — must be 0)
  aes_prng_masking #(
    .Width(Width),
    .EntropyWidth(EntropyWidth),
    .SecAllowForcingMasks(1'b1),
    .SecSkipPRNGReseeding(1'b0)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .force_masks_i,
    .data_update_i,
    .data_o,
    .reseed_req_i, .reseed_ack_o,
    .entropy_req_o, .entropy_ack_i,
    .entropy_i
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      force_masks_i <= 0;
      data_update_i <= 0;
      reseed_req_i <= 0;
      entropy_ack_i <= 0;
      entropy_i <= '0;
      phaseA_mask <= '0; phaseA_mask2 <= '0;
      phaseB_mask <= '0; phaseB_mask2 <= '0;
      bug_found <= 0;
    end else begin
      case (state)
        // ============ PHASE A: force_masks=0, zero seed ============
        0: begin
             entropy_i <= '0;            // all-zero entropy (the magic seed)
             reseed_req_i <= 1;
             entropy_ack_i <= 1;
             force_masks_i <= 0;
             state <= 1;
           end
        1: begin
             if (reseed_ack_o) state <= 2;  // wait until full reseed done
           end
        2: begin
             reseed_req_i <= 0;
             entropy_ack_i <= 0;
             data_update_i <= 1;          // let PRNG advance
             state <= 3;
           end
        3: begin
             phaseA_mask <= data_o;       // sample key stream
             state <= 4;
           end
        4: begin
             phaseA_mask2 <= data_o;
             state <= 5;
           end
        // ============ PHASE B: force_masks=1, zero seed ============
        5: begin
             data_update_i <= 0;
             reseed_req_i <= 1;           // re-seed with zeros
             entropy_ack_i <= 1;
             entropy_i <= '0;
             force_masks_i <= 1;          // BUG: software FORCE_MASKS bit
             state <= 6;
           end
        6: begin
             if (reseed_ack_o) state <= 7;
           end
        7: begin
             reseed_req_i <= 0;
             entropy_ack_i <= 0;
             data_update_i <= 1;
             state <= 8;
           end
        8: begin
             phaseB_mask <= data_o;
             state <= 9;
           end
        9: begin
             phaseB_mask2 <= data_o;
             state <= 10;
           end
        10: begin
             $display("=== AES masking PRNG (SecAllowForcingMasks=1) ===");
             $display("  Phase A (force_masks=0, zero seed): mask=0x%032x / 0x%032x",
                      phaseA_mask, phaseA_mask2);
             $display("  Phase B (force_masks=1, zero seed): mask=0x%032x / 0x%032x",
                      phaseB_mask, phaseB_mask2);
             if ((phaseB_mask === '0 || phaseB_mask2 === '0) &&
                 (phaseA_mask !== '0 || phaseA_mask2 !== '0)) begin
               bug_found <= 1;
               $display("");
               $display("==================================================");
               $display("*** BUG #15 CONFIRMED on actual OpenTitan RTL ***");
               $display("==================================================");
               $display("chip_earlgrey instantiates top_earlgrey with");
               $display("SecAesAllowForcingMasks=1'b1 (must be 1'b0 per");
               $display("AesSecAllowForcingMasksNonDefault static assert).");
               $display("");
               $display("Software: set CTRL_AUX_SHADOWED.FORCE_MASKS=1 and");
               $display("seed PRNG with zeros -> prim_trivium allow_lockup_i=1");
               $display("-> all-zero state KEPT -> masks CONSTANT ZERO.");
               $display("Phase A shows normal auto-restore (mask != 0);");
               $display("Phase B shows lockup (mask == 0).");
               $display("");
               $display("Impact: side-channel (power/EM) attacks on AES");
               $display("with no masking protection.");
               $display("==================================================");
             end else begin
               $display("  (unexpected result)");
             end
             state <= 11;
           end
        11: $finish;
      endcase
    end
  end
endmodule
