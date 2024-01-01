/*
这个模块用来处理寄存器依赖问题
*/
module Issue (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low


    input wire inst_valid
);
endmodule
