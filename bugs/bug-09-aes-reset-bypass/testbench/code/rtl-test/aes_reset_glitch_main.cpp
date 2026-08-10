#include "Vtb.h"
#include "verilated.h"
#include <cstdio>
#include <csignal>

// Harness for the AES reset-bypass demo (real aes_core).
// - normal reset at start (2 cycles)
// - when the TB raises glitch_req (it has detected data_out_we==SP2V_HIGH at the
//   cipher-completion output cycle), drop rst_n for exactly ONE full clock
//   period around that posedge, then restore — i.e. a reset glitch landing
//   precisely on the cycle that would write data_out_q.
// - the TB itself finishes via $finish (AES_DONE).

volatile sig_atomic_t stop = 0;
void handler(int) { stop = 1; }

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb* top = new Vtb;
    top->rst_n = 0;
    for (int i = 0; i < 2; i++) { top->clk = 0; top->eval(); top->clk = 1; top->eval(); }
    top->rst_n = 1;

    bool glitch_done = false;
    for (long i = 0; i < 60000 && !Verilated::gotFinish() && !stop; i++) {
        top->clk = 0;
        top->eval();
        if (top->glitch_req && !glitch_done) {
            // landing pad: keep rst low across the NEXT posedge (the output
            // write edge) then restore after one period
            top->rst_n = 0;
            top->clk = 1; top->eval();     // posedge: rst low & we==HIGH
            top->clk = 0; top->eval();
            top->rst_n = 1;                // restore
            glitch_done = true;
        } else {
            top->clk = 1; top->eval();
        }
        (void)glitch_done;
    }
    printf("done, glitch=%d finished=%d state=%u\n",
           (int)glitch_done, (int)Verilated::gotFinish(), (unsigned)top->state);
    delete top;
    return 0;
}
