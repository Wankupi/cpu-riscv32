`include "const.v"

module RegisterFile (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire rob_clear,

    input wire [4:0] set_reg_id,
    input wire [31:0] set_val,
    input wire [`ROB_WIDTH_BIT - 1:0] set_reg_on_rob_id,

    input wire [                 4:0] set_dep_reg_id,
    input wire [`ROB_WIDTH_BIT - 1:0] set_dep_rob_id,

    input  wire [                 4:0] get_id1,
    output wire [                31:0] get_val1,
    output wire                        get_has_dep1,
    output wire [`ROB_WIDTH_BIT - 1:0] get_dep1,
    input  wire [                 4:0] get_id2,
    output wire [                31:0] get_val2,
    output wire                        get_has_dep2,
    output wire [`ROB_WIDTH_BIT - 1:0] get_dep2
);
    reg [31:0] regs[0:31];
    reg [`ROB_WIDTH_BIT - 1:0] dep[0:31];
    reg has_dep[0:31];

    assign get_val1 = regs[get_id1];
    assign get_val2 = regs[get_id2];
    assign get_has_dep1 = has_dep[get_id1];
    assign get_has_dep2 = has_dep[get_id2];
    assign get_dep1 = dep[get_id1];
    assign get_dep2 = dep[get_id2];

    always @(posedge clk_in) begin
        if (rst_in) begin
            for (integer i = 0; i < 32; ++i) begin
                regs[i] <= 0;
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else if (rob_clear) begin
            for (integer i = 0; i < 32; ++i) begin
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end
        else begin
            if (set_reg_id) begin
                $display(`LOG("RegisterFile"), "set reg[%d] = %x", set_reg_id, set_val);
                regs[set_reg_id] <= set_val;
                if (!set_dep_reg_id && set_reg_on_rob_id == dep[set_reg_id]) begin
                    has_dep[set_reg_id] <= 0;
                end
            end
            if (set_dep_reg_id) begin
                dep[set_dep_reg_id] <= set_dep_rob_id;
                has_dep[set_dep_reg_id] <= 1;
            end
        end
    end

`ifdef DEBUG
    generate
        genvar idx;
        for (idx = 0; idx < 32; idx = idx + 1) begin : rv
            wire [31:0] regv;
            assign regv = regs[idx];
        end
    endgenerate
`endif

endmodule
