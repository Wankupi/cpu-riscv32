module debug_info (
    input  wire          clk,
    input  wire          rst,
    input  wire          rdy,
    input  wire          enable,
    input  wire [31 : 0] count_finished,
    input  wire [  71:0] rob_info,
    output wire          uart_en,
    output wire [   7:0] uart_data,
    output reg           stall
);
    function [7:0] char;
        input [3:0] num;
        begin
            case (num)
                4'd0:  char = 8'h30;
                4'd1:  char = 8'h31;
                4'd2:  char = 8'h32;
                4'd3:  char = 8'h33;
                4'd4:  char = 8'h34;
                4'd5:  char = 8'h35;
                4'd6:  char = 8'h36;
                4'd7:  char = 8'h37;
                4'd8:  char = 8'h38;
                4'd9:  char = 8'h39;
                4'd10: char = 8'h61;
                4'd11: char = 8'h62;
                4'd12: char = 8'h63;
                4'd13: char = 8'h64;
                4'd14: char = 8'h65;
                4'd15: char = 8'h66;
            endcase
        end
    endfunction

    localparam EN_BIT = 6;

    reg              working;
    reg [EN_BIT : 0] i;
    reg [EN_BIT : 0] len;
    reg [       7:0] buff    [0:2 ** EN_BIT - 1];

    assign uart_en   = working;
    assign uart_data = buff[i];

    wire [31:0] addr = rob_info[31:0];
    wire [1:0] work_type = rob_info[33:32];
    wire [4:0] rd = rob_info[38:34];
    wire [31:0] data = rob_info[71:40];
    reg extra_stall;

    integer j;

    always @(posedge clk) begin
        if (rst) begin
            working     <= 0;
            i           <= 0;
            len         <= 0;
            stall       <= 0;
            extra_stall <= 0;
        end
        else if (rdy) begin
            if (working) begin
                if (extra_stall) begin
                    working     <= 0;
                    i           <= 0;
                    len         <= 0;
                    stall       <= 0;
                    extra_stall <= 0;
                end
                else if (i == len && !stall) begin
                    stall <= 1;
                    extra_stall <= 1;
                end
                else if (stall) begin
                    stall <= 0;
                end
                else begin
                    i <= i + 1;
                    stall <= 1;
                end
            end
            else if (enable) begin : SET
                working <= 1;
                i       <= 0;
                stall   <= 1;
                j = 0;
                buff[j+0]  <= 8'h5B;  // '['
                buff[j+1]  <= char(count_finished[31:28]);
                buff[j+2]  <= char(count_finished[27:24]);
                buff[j+3]  <= char(count_finished[23:20]);
                buff[j+4]  <= char(count_finished[19:16]);
                buff[j+5]  <= char(count_finished[15:12]);
                buff[j+6]  <= char(count_finished[11:8]);
                buff[j+7]  <= char(count_finished[7:4]);
                buff[j+8]  <= char(count_finished[3:0]);
                buff[j+9]  <= 8'h5D;  // ']'
                buff[j+10] <= 8'h20;  // ' '
                j = j + 10;
                buff[j+1] <= char(addr[31:28]);
                buff[j+2] <= char(addr[27:24]);
                buff[j+3] <= char(addr[23:20]);
                buff[j+4] <= char(addr[19:16]);
                buff[j+5] <= char(addr[15:12]);
                buff[j+6] <= char(addr[11:8]);
                buff[j+7] <= char(addr[7:4]);
                buff[j+8] <= char(addr[3:0]);
                buff[j+9] <= 8'h20;  // ' '
                j = j + 9;
                case (work_type)
                    2'b00: begin  // reg
                        buff[j+1]  <= 8'h72;  // 'r'
                        buff[j+2]  <= 8'h20;  // ' '
                        buff[j+3]  <= rd[4] | 8'h30;  // 1/0
                        buff[j+4]  <= char(rd[3:0]);
                        buff[j+5]  <= 8'h20;  // ' '
                        buff[j+6]  <= char(data[31:28]);
                        buff[j+7]  <= char(data[27:24]);
                        buff[j+8]  <= char(data[23:20]);
                        buff[j+9]  <= char(data[19:16]);
                        buff[j+10] <= char(data[15:12]);
                        buff[j+11] <= char(data[11:8]);
                        buff[j+12] <= char(data[7:4]);
                        buff[j+13] <= char(data[3:0]);
                        buff[j+14] <= 8'h0A;  // '\n'
                        j = j + 14;
                        len <= j;
                    end
                    2'b01: begin
                        buff[j+1] <= 8'h73;  // 's'
                        buff[j+2] <= 8'h0A;  // '\n'
                        j = j + 2;
                        len <= j;
                    end
                    2'b10: begin
                        buff[j+1] <= 8'h62;  // 'b'
                        buff[j+2] <= 8'h20;  // ' '
                        buff[j+3] <= data[0] | 8'h30;  // 1/0
                        buff[j+4] <= 8'h0A;  // '\n'
                        j = j + 4;
                        len <= j;
                    end
                    default: len <= j;
                endcase
            end
        end
    end
endmodule
