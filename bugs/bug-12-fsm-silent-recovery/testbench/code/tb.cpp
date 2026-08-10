#include "Vtop.h"
#include <cstdlib>
#include <cstdio>
#include <cstring>
int main(){Vtop*top=new Vtop;
top->rst_ni=0; top->clk_i=0;top->eval();top->clk_i=1;top->eval(); // reset
top->rst_ni=1;
uint8_t buf[3];while(fread(buf,1,3,stdin)==3){
memcpy(&top->state_in,buf,2);top->state_load=buf[2]&1;
for(int i=0;i<4;i++){top->clk_i=0;top->eval();top->clk_i=1;top->eval();
if(top->bug_found_o){abort();}}}
delete top;return 0;}
