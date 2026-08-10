module tb(input clk, input rst_n, output bug_found);
  logic [2:0] count_q, count_d; logic en=1; logic [3:0] we; logic out_req; integer cycle=0;
  assign count_d = out_req ? count_q : en ? count_q+1 : count_q;
  always_ff @(posedge clk or negedge rst_n) if(!rst_n) count_q<=0; else count_q<=count_d;
  assign out_req = en && count_q==4; assign we[0]=en && count_q==0; assign we[1]=en && count_q==1; assign we[2]=en && count_q==2; assign we[3]=en && count_q==3;
  always @(posedge clk) begin cycle=cycle+1; if(rst_n) $display("[t=%0d] count=%0d we=%b out_req=%b *** BUG 17 ***", cycle, count_q, we, out_req); end
endmodule
