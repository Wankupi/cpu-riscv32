module RegisterFile (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire [ 4:0] set_reg_id,
    input wire [31:0] set_val,

    input  wire [ 4:0] get_id1,
    output wire [31:0] get_val1,
    input  wire [ 4:0] get_id2,
    output wire [31:0] get_val2
);
    reg [31:0] regs[0:31];

    assign get_val1 = regs[get_id1];
    assign get_val2 = regs[get_id2];

    always @(posedge clk_in) begin
        if (rst_in) begin
            for (integer i = 0; i < 32; ++i) begin
                regs[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else begin
            if (set_reg_id) begin
                regs[set_reg_id] <= set_val;
            end
        end
    end
endmodule
