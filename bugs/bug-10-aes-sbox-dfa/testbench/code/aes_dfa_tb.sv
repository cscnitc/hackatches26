// Real aes_cipher_core driver for DFA (bug #17 vector).
// SecMasking=0 -> NumShares=1, real UNMASKED ciphertext (clean for DFA).
// Good + faulty ciphertext pairs: fault injects into the round-9 datapath
// (the observable effect of the bug-17 DOM-sbox count_q stage skip, which is
// itself proven silent at module level on aes_sbox_dom real RTL).
module tb;
  import aes_pkg::*;

  parameter bit FAULT = 0;
  parameter int  FAULT_BYTE = 0;   // which byte of the round-9 state to corrupt
  parameter logic [7:0] FAULT_VAL = 8'hFF;  // injected byte value

  logic clk=0, rst_n=0;
  sp2v_e in_valid_i=SP2V_LOW, crypt_i=SP2V_LOW, dec_key_gen_i=SP2V_LOW;
  sp2v_e in_ready_o, out_valid_o;
  sp2v_e out_ready_i=SP2V_LOW;
  logic cfg_valid_i=1, prng_reseed_i=0, key_clear_i=0, data_out_clear_i=0;
  logic alert_fatal_i=0, force_masks_i=0, entropy_ack_i=1;
  ciph_op_e op_i=CIPH_FWD;
  key_len_e key_len_i;
  logic [3:0][3:0][7:0] state_init[1], state_o[1];
  logic [7:0][31:0]     key_init[1];
  logic [7:0][31:0]     prd_clearing_key[1];
  logic [3:0][3:0][7:0] prd_clearing_state[1];
  logic entropy_req_o, prng_reseed_o, key_clear_o, data_out_clear_o, alert_o;
  sp2v_e crypt_o, dec_key_gen_o;
  logic [3:0][3:0][7:0] data_in_mask_o;
  logic [31:0] entropy_i='0;

  aes_cipher_core #(
    .AES192Enable(0),
    .CiphOpFwdOnly(1),
    .SecMasking(0),                 // => NumShares=1, UNMASKED real ciphertext
    .SecSBoxImpl(SBoxImplLut)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .in_valid_i, .in_ready_o, .out_valid_o, .out_ready_i,
    .cfg_valid_i, .op_i, .key_len_i,
    .crypt_i, .crypt_o, .dec_key_gen_i, .dec_key_gen_o,
    .prng_reseed_i, .prng_reseed_o, .key_clear_i, .key_clear_o,
    .data_out_clear_i, .data_out_clear_o, .alert_fatal_i, .alert_o,
    .prd_clearing_state_i(prd_clearing_state), .prd_clearing_key_i(prd_clearing_key),
    .force_masks_i, .data_in_mask_o,
    .entropy_req_o, .entropy_ack_i, .entropy_i,
    .state_init_i(state_init), .key_init_i(key_init), .state_o(state_o)
  );
  always #5 clk = ~clk;

  logic [127:0] K = 128'h000102030405060708090a0b0c0d0e0f;
  logic [127:0] P = 128'h00112233445566778899aabbccddeeff;
  string pt_plus;
  integer flt_byte = 0;
  logic [7:0] flt_val = 8'hFF;
  bit fault_en = 0;
  integer fault_byte = 0;
  logic [7:0] fault_val = 8'hFF;

  // parse all plusargs first (single pass, before any datapath capture)
  initial begin
    if ($value$plusargs("pt=%s", pt_plus)) begin
      // manual hex parse (atohex truncates some 32-char strings)
      logic [127:0] tmp;
      tmp = '0;
      for (int i = 0; i < pt_plus.len(); i += 1) begin
        logic [3:0] nib;
        case (pt_plus[i])
          "0": nib = 4'h0; "1": nib = 4'h1; "2": nib = 4'h2; "3": nib = 4'h3;
          "4": nib = 4'h4; "5": nib = 4'h5; "6": nib = 4'h6; "7": nib = 4'h7;
          "8": nib = 4'h8; "9": nib = 4'h9;
          "a","A": nib = 4'ha; "b","B": nib = 4'hb; "c","C": nib = 4'hc;
          "d","D": nib = 4'hd; "e","E": nib = 4'he; "f","F": nib = 4'hf;
          default: nib = 4'h0;
        endcase
        tmp = (tmp << 4) | nib;
      end
      P = tmp;
    end
    if ($value$plusargs("fault_byte=%0d", flt_byte)) fault_en = 1;
    void'($value$plusargs("fault_val=%0h", flt_val));
    $display("PLAINTEXT: %032h  KEY: %032h  fault_en=%b fault_byte=%0d fault_val=%02h",
             P, K, fault_en, flt_byte, flt_val);
  end

  // FIPS-197: key=0x000102..0f (b0=0x00 leftmost), pt=0x001122..ff (b0=0x00),
  // C=0x69c4e0d8... leftmost first.
  function automatic logic [3:0][3:0][7:0] arr_state(input logic [127:0] v);
    logic [3:0][3:0][7:0] s;
    // state[r][c] = pt byte index (4c+r), b0 = leftmost = v[(15-0)*8 +: 8]
    for (int c=0;c<4;c++) for (int r=0;r<4;r++)
      s[r][c] = v[(15-(4*c+r))*8 +: 8];
    return s;
  endfunction
  function automatic logic [7:0][31:0] arr_key(input logic [127:0] v);
    logic [7:0][31:0] k;
    // key_init[0][w] = {b(4w+3), b(4w+2), b(4w+1), b(4w)}, b_i = v[(15-i)*8 +: 8]
    for (int w=0;w<4;w++) begin
      k[w][31:24] = v[(15-(4*w+3))*8 +: 8];
      k[w][23:16] = v[(15-(4*w+2))*8 +: 8];
      k[w][15:8]  = v[(15-(4*w+1))*8 +: 8];
      k[w][7:0]   = v[(15-(4*w+0))*8 +: 8];
    end
    return k;
  endfunction
  function automatic logic [127:0] state_to_int(input logic [3:0][3:0][7:0] s[1]);
    logic [127:0] r;
    for (int c=0;c<4;c++) for (int r=0;r<4;r++)
      r[(4*c+r)*8 +: 8] = s[0][r][c];
    return r;
  endfunction

  // monitor: dump state_o and rnd every posedge during rounds 8-10
  always @(posedge clk) begin
    if (rst_n && dut.u_aes_cipher_control.rnd_ctr >= 4'd8)
      $display("[t=%0t] mon rnd=%0d out_valid=%b state_o=%032h state_q=%032h",
               $time, dut.u_aes_cipher_control.rnd_ctr, out_valid_o,
               state_to_int(state_o), state_q_to_int());
  end
  function automatic logic [127:0] state_q_to_int();
    logic [127:0] r;
    for (int c=0;c<4;c++) for (int r=0;r<4;r++)
      r[(4*c+r)*8 +: 8] = dut.state_q[0][r][c];
    return r;
  endfunction
  // silence unused warnings
  logic unused_fi = 0;

  initial begin
    key_len_i = AES_128;
    @(negedge clk); rst_n=0; @(negedge clk); rst_n=0; @(negedge clk); rst_n=1;
    repeat (4) @(negedge clk);   // settle in IDLE

    state_init[0] = arr_state(P);
    key_init[0]   = arr_key(K);
    prd_clearing_state[0]='0;
    prd_clearing_key[0]='0;

    // sanity: check state loaded (raw indexing, no function)
    $display("[t=%0t] pre-start si00=%02h si03=%02h ki0=%08h",
             $time, state_init[0][0][0], state_init[0][0][3], key_init[0][0]);

    // start: wait until IDLE ready, then pulse in_valid + crypt
    wait (in_ready_o == SP2V_HIGH);
    @(negedge clk); crypt_i=SP2V_HIGH; in_valid_i=SP2V_HIGH;
    @(negedge clk); crypt_i=SP2V_LOW;  in_valid_i=SP2V_LOW;

    // watch progress
    @(posedge clk);
    $display("[t=%0t] after start: rnd=%0d state_q00=%02h state_q03=%02h",
             $time, dut.u_aes_cipher_control.rnd_ctr, dut.state_q[0][0][0], dut.state_q[0][0][3]);
    repeat (3) @(posedge clk);
    $display("[t=%0t] t+3: rnd=%0d state_q00=%02h state_q03=%02h",
             $time, dut.u_aes_cipher_control.rnd_ctr, dut.state_q[0][0][0], dut.state_q[0][0][3]);
    wait (out_valid_o == SP2V_HIGH);
    $display("[t=%0t] out_valid high, rnd=%0d", $time, dut.u_aes_cipher_control.rnd_ctr);
    // capture while out_valid is high, on the negedge (post-posedge may have
    // cleared state -> X). state_o = add_round_key_out is combinational.
    @(negedge clk);
    // FIPS byte order: ct[b] for b=0..15 = state row r=b%4, col c=b/4
    $display("CIPHERTEXT_HEX: %02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h",
      state_o[0][0][0],state_o[0][1][0],state_o[0][2][0],state_o[0][3][0],
      state_o[0][0][1],state_o[0][1][1],state_o[0][2][1],state_o[0][3][1],
      state_o[0][0][2],state_o[0][1][2],state_o[0][2][2],state_o[0][3][2],
      state_o[0][0][3],state_o[0][1][3],state_o[0][2][3],state_o[0][3][3]);
    out_ready_i=SP2V_HIGH;
    @(posedge clk); out_ready_i=SP2V_LOW;

    $finish;
  end

  // ------------------------------------------------------------------
  // Fault injection (params via plusargs; default FAULT=0)
  // ------------------------------------------------------------------
  `define STB(r,c) dut.state_q[0][r][c]   // state share0 byte [r][c]
  // (params parsed in the initial above; fault_byte/fault_val aliases kept
  //  for the injection block below)
  always @(posedge clk) begin
    fault_byte = flt_byte;
    fault_val  = flt_val;
  end
  // Force at rnd_ctr==9: at that point the round-9 output sits in state_q,
  // which is the round-10 SubBytes input. A single-byte fault here affects
  // exactly ONE ciphertext byte -> cleanest DFA model (Piret-Quisquater).
  always @(posedge clk) begin
    if (fault_en && rst_n && dut.u_aes_cipher_control.rnd_ctr == 4'd9) begin
      case (fault_byte)
        0:  force `STB(0,0) = fault_val;
        1:  force `STB(1,0) = fault_val;
        2:  force `STB(2,0) = fault_val;
        3:  force `STB(3,0) = fault_val;
        4:  force `STB(0,1) = fault_val;
        5:  force `STB(1,1) = fault_val;
        6:  force `STB(2,1) = fault_val;
        7:  force `STB(3,1) = fault_val;
        8:  force `STB(0,2) = fault_val;
        9:  force `STB(1,2) = fault_val;
        10: force `STB(2,2) = fault_val;
        11: force `STB(3,2) = fault_val;
        12: force `STB(0,3) = fault_val;
        13: force `STB(1,3) = fault_val;
        14: force `STB(2,3) = fault_val;
        15: force `STB(3,3) = fault_val;
        default: ;
      endcase
      `ifndef NO_FAULT_LOG
      $display("FAULT_INJ: byte[%0d] forced to %02h at rnd=%0d", fault_byte, fault_val,
               dut.u_aes_cipher_control.rnd_ctr);
      `endif
      @(posedge clk);
      case (fault_byte)
        0:  release `STB(0,0);
        1:  release `STB(1,0);
        2:  release `STB(2,0);
        3:  release `STB(3,0);
        4:  release `STB(0,1);
        5:  release `STB(1,1);
        6:  release `STB(2,1);
        7:  release `STB(3,1);
        8:  release `STB(0,2);
        9:  release `STB(1,2);
        10: release `STB(2,2);
        11: release `STB(3,2);
        12: release `STB(0,3);
        13: release `STB(1,3);
        14: release `STB(2,3);
        15: release `STB(3,3);
        default: ;
      endcase
    end
  end
endmodule