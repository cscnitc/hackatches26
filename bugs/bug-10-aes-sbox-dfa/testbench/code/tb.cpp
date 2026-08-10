#include "Vtop.h"
#include <cstdlib>
#include <cstdio>
int main(){Vtop*top=new Vtop;top->clk_i=0;top->eval();
uint8_t buf;while(fread(&buf,1,1,stdin)==1){
top->rst_ni=1;top->en_i=1;top->fault_inject=(buf>>4)&7;
for(int i=0;i<8;i++){top->clk_i=0;top->eval();top->clk_i=1;top->eval();
if(i>=4)top->fault_inject=0;if(top->bug_found_o){abort();}}}
delete top;return 0;}
