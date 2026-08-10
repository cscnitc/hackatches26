// Bug #16 AFL-fuzzable testbench — data_out_reg reset bypass
// Uses the exact sp2v_e sparse type (3-bit) and always_ff block
// from OpenTitan aes_core.sv lines 872-878.
//
// AES data_out_reg is 128 bits (NumRegsData=4 x 32-bit).
// The bug: data_out_q only clears on reset when data_out_we != SP2V_HIGH.
// If write-enable is active during reset, data can survive.

module bug16_real_tb (
  input                clk,
  input  [2:0]         afl_we,           // data_out_we (3-bit sparse sp2v_e)
  input  [127:0]       afl_data_d,       // data_out_d value
  input  [7:0]         afl_rst_cycles,   // cycles to hold reset low
  input  [7:0]         afl_post_cycles,  // cycles after reset deassert
  output               bug_found_o
);

  // ── Replicate the exact sp2v_e sparse type from aes_pkg.sv ──
  // Mux2SelWidth = 3, MUX2_SEL_0 = 3'b011, MUX2_SEL_1 = 3'b100
  localparam int Sp2VWidth = 3;
  typedef logic [Sp2VWidth-1:0] sp2v_e;
  localparam sp2v_e SP2V_HIGH = 3'b011;
  localparam sp2v_e SP2V_LOW  = 3'b100;

  // ── Internal signals (matching aes_core.sv) ──
  logic          rst_n;
  sp2v_e         data_out_we;
  logic [127:0]  data_out_d;
  logic [127:0]  data_out_q;

  // ── BUGGY LOGIC: exact replica of aes_core.sv:872-878 ──
  // This is the buggy data_out_reg always_ff block.
  // The reset clears data_out_q ONLY when data_out_we != SP2V_HIGH.
  // If data_out_we == SP2V_HIGH during reset, the else-if branch
  // can write data into data_out_q, and it won't be cleared.
  always_ff @(posedge clk or negedge rst_n) begin : data_out_reg
    if (!rst_n && data_out_we != SP2V_HIGH) begin
      data_out_q <= '0;
    end else if (data_out_we == SP2V_HIGH) begin
      data_out_q <= data_out_d;
    end
  end

  // ── Simulation FSM ──
  logic [8:0] cycle_count;
  logic       phase;        // 0=reset, 1=post-reset check
  logic       rst_was_low;  // track that reset was asserted

  always_ff @(posedge clk) begin
    if (cycle_count == 9'd0) begin
      // Initialize — start in reset
      cycle_count  <= 9'd1;
      phase        <= 1'b0;
      rst_was_low  <= 1'b0;
      rst_n        <= 1'b0;
      data_out_we  <= sp2v_e'(afl_we);
      data_out_d   <= afl_data_d;
    end else if (!phase) begin
      // Reset phase: hold rst_n=0 for afl_rst_cycles
      rst_n       <= 1'b0;
      data_out_we <= sp2v_e'(afl_we);
      data_out_d  <= afl_data_d;
      rst_was_low <= 1'b1;

      if (afl_rst_cycles != 8'd0 && cycle_count >= {1'b0, afl_rst_cycles}) begin
        phase        <= 1'b1;
        cycle_count  <= 9'd1;
      end else begin
        cycle_count <= cycle_count + 9'd1;
      end
    end else begin
      // Post-reset phase: rst_n=1, data still applied
      rst_n       <= 1'b1;
      data_out_we <= sp2v_e'(afl_we);
      data_out_d  <= afl_data_d;

      if (afl_post_cycles != 8'd0 && cycle_count >= {1'b0, afl_post_cycles}) begin
        // Done — hold
        rst_n <= 1'b1;
      end else begin
        cycle_count <= cycle_count + 9'd1;
      end
    end
  end

  // ── Bug detection: data_out_q != 0 after reset was asserted ──
  logic bug_latched;
  always_ff @(posedge clk) begin
    if (phase && rst_was_low && (|data_out_q))
      bug_latched <= 1'b1;
  end

  assign bug_found_o = bug_latched;

endmodule
