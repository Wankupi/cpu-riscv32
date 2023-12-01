/*
before ready,
the other module should guarantee that:
    1. valid is 1
    2. wr, addr, len do not change
on the cycle of ready,
    1. valid, wr, addr, len can change
    2. when change, start work at the cycle
*/
module MemoryController (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,   // data input bus
    output wire [ 7:0] mem_dout,  // data output bus
    output wire [31:0] mem_a,     // address bus (only 17:0 is used)
    output wire        mem_wr,    // write/read signal (1 for write)

    input  wire        valid,  // need to do something
    input  wire        wr,     // write/read signal (1 for write)
    input  wire [31:0] addr,   // address
    input  wire [ 1:0] len,    // date size (0: byte, 1: half word, 10: word)
    input  wire [31:0] data,   // data to write
    output wire        ready,  // work finished
    output wire [31:0] res     // result
);
    function [31:0] get_result;
        input [1:0] len;
        input [31:0] result;
        input [7:0] mem_din;
        case (len)
            2'b00:   get_result = mem_din;
            2'b01:   get_result = {mem_din[7:0], result[7:0]};
            2'b10:   get_result = {mem_din[7:0], result[23:0]};
            default: get_result = 0;
        endcase
    endfunction
    reg        worked;
    reg [31:0] work_addr;
    reg        work_wr;
    reg [ 1:0] work_len;
    reg [ 2:0] work_cycle;
    reg [31:0] current_addr;
    reg [ 7:0] current_data;
    reg [31:0] result;

    assign ready = worked && work_cycle == 0 && work_addr == addr;
    wire need_work = valid && !ready;

    // `direct` choose direct or inner value
    // 0: direct, 1: inner
    // direct means connect the input of this module to the input of Memory directyly
    wire direct = work_cycle == 0 && need_work;
    assign mem_wr = direct ? wr : work_wr;
    assign mem_a = direct ? addr : current_addr;
    assign mem_dout = direct ? data[7:0] : current_data;

    assign res = get_result(len, result, mem_din);

    always @(posedge clk_in) begin
        if (rst_in) begin
            worked <= 0;
            work_addr <= 0;
            work_wr <= 0;
            work_len <= 0;
            work_cycle <= 0;
            current_addr <= 0;
            current_data <= 0;
            result <= 0;
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else begin
            case (work_cycle)
                3'b000: begin  // not working: waiting or done
                    if (need_work) begin
                        work_cycle <= (len ? 3'b001 : 3'b000);
                        work_addr  <= addr;
                        work_wr    <= wr;
                        work_len   <= len;
                        current_addr <= addr + 1;
                        current_data <= data[15:8];
                        result <= data;
                        worked <= 1;
                    end
                end
                3'b001: begin
                    result[7:0]  <= mem_din;
                    current_addr <= addr + 2;
                    current_data <= data[23:16];
                    if (work_len == 2'b01) begin
                        work_cycle <= 3'b000;
                    end
                    else begin
                        work_cycle <= 3'b010;
                    end
                end
                3'b010: begin
                    result[15:8] <= mem_din;
                    current_addr <= addr + 3;
                    current_data <= data[31:24];
                    work_cycle   <= 3'b011;
                end
                3'b011: begin
                    result[23:16] <= mem_din;
                    work_cycle <= 3'b000;
                end
            endcase
        end
    end

endmodule
