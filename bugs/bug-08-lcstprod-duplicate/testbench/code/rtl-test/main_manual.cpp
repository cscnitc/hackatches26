#include "Vtb.h"
#include "verilated.h"
#include <cstdio>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb* top = new Vtb;
    top->rst_n = 0;
    // reset for 2 cycles
    for (int i = 0; i < 2; i++) { top->clk = 0; top->eval(); top->clk = 1; top->eval(); }
    top->rst_n = 1;
    // run 200 cycles
    for (int i = 0; i < 200; i++) { top->clk = 0; top->eval(); top->clk = 1; top->eval(); }
    printf("done, state=%u\n", top->state);
    delete top;
    return 0;
}
