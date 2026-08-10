#include "Vtop.h"
#include <cstdlib>
#include <cstdio>
#include <cstring>
Vtop* top;
int main(int argc, char** argv) {
    top = new Vtop;
    top->clk_i=0; top->eval(); top->clk_i=1; top->eval();
    uint8_t buf[17];
    while(fread(buf,1,17,stdin)==17){
        top->rst_ni=!(buf[0]&1);
        top->data_out_we=(buf[0]>>1)&7;
        memset(top->data_in,0,128/8);
        memcpy(top->data_in,buf+1,16);
        // Run 3 cycles per input — lets reset rise/fall propagate
        for(int i=0;i<3;i++){
            top->clk_i=0;top->eval(); top->clk_i=1;top->eval();
            if(top->bug_found_o){abort();}
        }
    }
    delete top; return 0;
}
