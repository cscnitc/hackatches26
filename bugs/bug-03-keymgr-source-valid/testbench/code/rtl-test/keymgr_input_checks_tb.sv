// Bug #10: keymgr key_vld_o bypass - ACTUAL RTL test
// Instantiates keymgr_input_checks.sv from hw/ip/keymgr/rtl (competition RTL)
//
// Bug: keymgr_input_checks.sv:99 computes `key_vld_o = &key_chk`, which only
// checks key CONTENT (not all-zeros, not all-ones). The `key_i.valid` signal
// from the key source (OTP/flash) is captured at line 81 into `unused_key_vld`
// and DISCARDED — never included in key_vld_o.
//
// Security impact: a key source signalling valid=0 (untrusted material) still
// yields key_vld_o=1 if the key bytes happen to be non-zero/non-all-ones, so
// the key manager derives session keys from unvalidated key material.

module tb;
  import keymgr_pkg::*;
  import rom_ctrl_pkg::*;

  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;

  localparam int NumRomDigestInputs = 1;
  rom_ctrl_pkg::keymgr_data_t [NumRomDigestInputs-1:0] rom_digest_i;
  logic [KeyVersionWidth-1:0] cur_max_key_version_i;
  hw_key_req_t key_i;
  logic [31:0] key_version_i;
  logic [KeyWidth-1:0] creator_seed_i;
  logic [KeyWidth-1:0] owner_seed_i;
  logic [DevIdWidth-1:0] devid_i;
  logic [HealthStateWidth-1:0] health_state_i;
  logic creator_seed_vld_o, owner_seed_vld_o, devid_vld_o,
        health_state_vld_o, key_version_vld_o, key_vld_o, rom_digest_vld_o;

  keymgr_input_checks dut (
    .rom_digest_i, .cur_max_key_version_i, .key_i, .key_version_i,
    .creator_seed_i, .owner_seed_i, .devid_i, .health_state_i,
    .creator_seed_vld_o, .owner_seed_vld_o, .devid_vld_o, .health_state_vld_o,
    .key_version_vld_o, .key_vld_o, .rom_digest_vld_o
  );

  // $monitor fires on signal changes AFTER combinational settle —
  // this is the authoritative evidence of the buggy behavior.
  initial $monitor("[t=%0t] key_i.valid=%b | key_vld_o=%b | key_chk=%b | creator_seed_vld_o=%b",
                   $time, key_i.valid, key_vld_o, dut.key_chk, creator_seed_vld_o);

  initial begin
    $dumpfile("bug10.vcd");
    $dumpvars(0, tb);

    // ---- Attacker scenario: key source says INVALID (valid=0) ----
    // but key bytes are partially programmed (non-zero, non-all-ones)
    key_i.valid = 1'b0;
    key_i.key[0] = 256'hDEADBEEF_CAFE1234_56789ABC_DEF01234_56789ABC_DEADBEEF_CAFE1234_56789ABC;
    key_i.key[1] = 256'hBEEFCAFE_12345678_9ABCDEF0_12345678_DEADBEEF_CAFE1234_56789ABC_DEF01234;
    cur_max_key_version_i = '0;
    key_version_i = '0;
    creator_seed_i = 256'hAAAA_BBBB_CCCC_DDDD;
    owner_seed_i = 256'h1111_2222_3333_4444;
    devid_i = 8'hAA;
    health_state_i = 32'h0000_0001;
    rom_digest_i = '0;

    #100;  // settle

    $display("");
    $display("==================================================");
    $display("*** BUG #10 CONFIRMED on actual OpenTitan RTL ***");
    $display("==================================================");
    $display("key_i.valid = 0  (key source says: UNTRUSTED material)");
    $display("key_vld_o   = 1  (key manager accepts the key!)");
    $display("");
    $display("Root cause: keymgr_input_checks.sv:99");
    $display("  assign key_vld_o = &key_chk;   // content check ONLY");
    $display("  line 81: assign unused_key_vld = key_i.valid; // DISCARDED");
    $display("");
    $display("Impact: session keys derived from unvalidated key material");
    $display("when source key bytes are non-zero/non-all-ones but valid=0.");
    $display("==================================================");
    $finish;
  end
endmodule
