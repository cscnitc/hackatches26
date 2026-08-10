#include "Vtop.h"
#include <cstdlib>
#include <cstdio>
#include <cstring>
int main(){Vtop*top=new Vtop;
top->rst_ni=0;top->clk_i=0;top->eval();top->clk_i=1;top->eval();
top->rst_ni=1;
uint8_t buf[5];while(fread(buf,1,5,stdin)==5){
memcpy(&top->entropy_i,buf,4);top->entropy_valid=buf[4]&1;
for(int i=0;i<4;i++){top->clk_i=0;top->eval();top->clk_i=1;top->eval();
if(top->bug_found_o){abort();}}}
delete top;return 0;}
