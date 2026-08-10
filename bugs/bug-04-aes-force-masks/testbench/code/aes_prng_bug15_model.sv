// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Bug #15 AFL-fuzzable target: AES PRNG masking with SecAllowForcingMasks=1
//
// Self-contained behavioral model of aes_prng_masking.sv / prim_trivium.sv.
// Includes working partial-reseed interface so AFL can discover that
// force_masks_i=1 + zero-seed-reseed causes permanent lockup & disabled masking.

module aes_prng_bug15_model #(
  parameter int unsigned Width        = 160,
  parameter int unsigned EntropyWidth = 32,
  parameter bit          SecAllowForcingMasks  = 1,  // THE BUG
  parameter bit          SecSkipPRNGReseeding  = 0   // allow reseed
) (
  input  logic                clk_i,
  input  logic                rst_ni,
  input  logic                force_masks_i,
  input  logic                data_update_i,
  output logic [Width-1:0]    data_o,
  input  logic                reseed_req_i,
  output logic                reseed_ack_o,
  output logic                entropy_req_o,
  input  logic                entropy_ack_i,
  input  logic [EntropyWidth-1:0] entropy_i,
  output logic                bug_found_o
);

  //////////////////////////////////////////////////////////////////
  // Bivium stream cipher (177-bit state)                         //
  //////////////////////////////////////////////////////////////////

  localparam int unsigned BiviumStateWidth = 177;
  localparam int unsigned NumStateParts =
      (BiviumStateWidth + EntropyWidth - 1) / EntropyWidth;  // ceil(177/32) = 6
  localparam int unsigned StateIdxWidth = $clog2(NumStateParts + 1) > 1 ?
                                          $clog2(NumStateParts + 1) : 2;  // min 2 bits

  // Default seed: lower 177 bits of RndCnstTriviumLfsrSeedDefault
  localparam logic [BiviumStateWidth-1:0] StateSeed =
      177'h082a30c132b5723c5a4cf4743b3c7c32d580f74f1713a;

  logic [BiviumStateWidth-1:0] state_q, state_d;

  // Bivium update function -- EXACT copy from prim_trivium_pkg.sv
  function automatic logic [BiviumStateWidth-1:0] bivium_update_state(
    logic [BiviumStateWidth-1:0] in
  );
    logic mul_90_91, mul_174_175;
    logic add_65_92, add_161_176;
    logic [BiviumStateWidth-1:0] out;
    mul_90_91 = in[90] & in[91];
    add_65_92 = in[65] ^ in[92];
    mul_174_175 = in[174] & in[175];
    add_161_176 = in[161] ^ in[176];
    out[0]   = in[68] ^ (mul_174_175 ^ add_161_176);
    out[93]  = in[170] ^ add_65_92 ^ mul_90_91;
    out[92:1]   = in[91:0];
    out[176:94] = in[175:93];
    return out;
  endfunction

  // Bivium key stream generation -- EXACT copy from prim_trivium_pkg.sv
  function automatic logic bivium_generate_key_stream(
    logic [BiviumStateWidth-1:0] state
  );
    logic add_65_92, add_161_176;
    add_65_92   = state[65] ^ state[92];
    add_161_176 = state[161] ^ state[176];
    return add_161_176 ^ add_65_92;
  endfunction

  //////////////////////////////////////////////////////////////////
  // Reseed state machine                                        //
  //////////////////////////////////////////////////////////////////

  logic seed_req_q, seed_req_d;
  logic [StateIdxWidth-1:0] state_idx_q, state_idx_d;
  logic last_state_part;
  logic prng_seed_en;
  logic prng_seed_done;
  logic wr_en_seed;
  logic [BiviumStateWidth-1:0] state_seed;

  assign prng_seed_en = SecSkipPRNGReseeding ? 1'b0 : reseed_req_i;
  assign reseed_ack_o  = SecSkipPRNGReseeding ? reseed_req_i : prng_seed_done;

  // Latch seed_en and keep requesting until last part is acked
  assign seed_req_d = (prng_seed_en | seed_req_q) & (~entropy_ack_i | ~last_state_part);
  assign entropy_req_o = prng_seed_en | seed_req_q;
  assign wr_en_seed = entropy_req_o & entropy_ack_i;

  // Track which state part we're on (0..NumStateParts-1)
  logic [StateIdxWidth-1:0] last_part_val;
  assign last_part_val = NumStateParts - 1;
  assign last_state_part = state_idx_q == last_part_val;
  assign state_idx_d = wr_en_seed &  last_state_part ? '0 :
                       wr_en_seed & ~last_state_part ? state_idx_q + 1'b1 :
                       state_idx_q;

  // Reseed done when last part is received
  assign prng_seed_done = entropy_req_o & entropy_ack_i & last_state_part;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      seed_req_q  <= 1'b0;
      state_idx_q <= '0;
    end else begin
      seed_req_q  <= seed_req_d;
      state_idx_q <= state_idx_d;
    end
  end

  // Partial seed injection
  always_comb begin
    state_seed = state_q;
    if (wr_en_seed) begin
      // Overwrite the current state part with entropy_i (padded to PartWidth)
      for (int unsigned i = 0; i < EntropyWidth; i++) begin
        if ((state_idx_q * EntropyWidth + i) < BiviumStateWidth) begin
          state_seed[state_idx_q * EntropyWidth + i] = entropy_i[i];
        end
      end
    end
  end

  //////////////////////////////////////////////////////////////////
  // State update and output                                     //
  //////////////////////////////////////////////////////////////////

  logic lockup;
  logic restore;
  logic allow_lockup;
  logic [BiviumStateWidth-1:0] state_update;
  logic [Width-1:0] prng_key;

  assign lockup = ~(|state_q);
  assign allow_lockup = SecAllowForcingMasks & force_masks_i;
  // restore: when lockup occurs, restore UNLESS we're allowing lockup
  assign restore = lockup & ~allow_lockup;

  // Generate updated state and key stream (unrolled Width times)
  always_comb begin
    state_update = state_q;
    for (int unsigned i = 0; i < Width; i++) begin
      prng_key[i] = bivium_generate_key_stream(state_update);
      state_update = bivium_update_state(state_update);
    end
  end

  // Next state: restore > seed > update > hold
  assign state_d = restore    ? StateSeed  :
                   wr_en_seed ? state_seed :
                   data_update_i ? state_update :
                   state_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= StateSeed;
    end else begin
      state_q <= state_d;
    end
  end

  //////////////////////////////////////////////////////////////////
  // Output permutation (zero-preserving)                         //
  //////////////////////////////////////////////////////////////////
  for (genvar b = 0; b < Width; b++) begin : gen_perm
    localparam int unsigned perm_idx = (b * 37 + 13) % Width;
    assign data_o[b] = prng_key[perm_idx];
  end

  //////////////////////////////////////////////////////////////////
  // Bug detection                                                //
  //////////////////////////////////////////////////////////////////
  // bug_found_o: force_masks_i active AND PRNG output is all zeros
  // -> masking is effectively disabled (the vulnerability)
  assign bug_found_o = force_masks_i & ~(|data_o);

endmodule
