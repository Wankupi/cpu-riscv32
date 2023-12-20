`include "const.v"

module ReorderBuffer #(
    parameter ROB_SIZE_BIT = `ROB_WIDTH_BIT
) (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire inst_valid,
    input wire inst_ready,
    input wire [`ROB_TYPE_BIT - 1 : 0] inst_type,
    input wire [4:0] inst_rd,
    input wire [31:0] inst_value,
    input wire [31:0] inst_pc,
    input wire [31:0] inst_jump_addr,

    // from ReservationStation
    input wire                          rs_ready,
    input wire [`ROB_WIDTH_BIT - 1 : 0] rs_rob_id,
    input wire [                  31:0] rs_value,

    // from LoadStoreBuffer
    input wire                          lsb_ready,
    input wire [`ROB_WIDTH_BIT - 1 : 0] lsb_rob_id,
    input wire [                  31:0] lsb_value,

    output wire full,
    output wire empty,
    // to LoadStoreBuffer
    output wire [ROB_SIZE_BIT - 1 : 0] rob_id_head,
    // to Decoder
    output wire [ROB_SIZE_BIT - 1 : 0] rob_id_tail,

    // to Register
    output wire [                 4:0] set_reg_id,
    output wire [                31:0] set_val,
    output wire [`ROB_WIDTH_BIT - 1:0] set_reg_on_rob_id,
    output wire [                 4:0] set_dep_reg_id,
    output wire [`ROB_WIDTH_BIT - 1:0] set_dep_rob_id,


    output reg clear,
    output reg [31:0] new_pc
);

    localparam ROB_SIZE = 1 << ROB_SIZE_BIT;

    localparam TypeRg = `ROB_TYPE_BIT'b00;
    localparam TypeSt = `ROB_TYPE_BIT'b01;
    localparam TypeBr = `ROB_TYPE_BIT'b10;
    localparam TypeEx = `ROB_TYPE_BIT'b11;

    reg                       busy     [0 : ROB_SIZE - 1];
    reg                       ready    [0 : ROB_SIZE - 1];
    reg [`ROB_TYPE_BIT - 1:0] work_type[0 : ROB_SIZE - 1];
    reg [                4:0] rd       [0 : ROB_SIZE - 1];
    reg [               31:0] value    [0 : ROB_SIZE - 1];
    reg [               31:0] inst_addr[0 : ROB_SIZE - 1];
    reg [               31:0] jump_addr[0 : ROB_SIZE - 1];

    reg [ROB_SIZE_BIT - 1:0] head, tail;

    always @(posedge clk_in) begin
        if (rst_in || clear) begin
            clear  <= 0;
            new_pc <= 0;
            for (integer i = 0; i < ROB_SIZE; i = i + 1) begin
                busy[i] <= 0;
                ready[i] <= 0;
                work_type[i] <= 0;
                rd[i] <= 0;
                value[i] <= 0;
                inst_addr[i] <= 0;
                jump_addr[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else begin
            if (rs_ready) begin
                ready[rs_rob_id] <= 1;
                value[rs_rob_id] <= rs_value;
            end
            if (lsb_ready) begin
                ready[lsb_rob_id] <= 1;
                value[lsb_rob_id] <= lsb_value;
            end
            if (inst_valid) begin
                if (full) begin
                    $display("ReorderBuffer full but still adding");
                    $finish();
                end
                tail <= tail + 1;
                busy[tail] <= 1;
                ready[tail] <= inst_ready;
                work_type[tail] <= inst_type;
                rd[tail] <= inst_rd;
                value[tail] <= inst_value;
                inst_addr[tail] <= inst_pc;
                jump_addr[tail] <= inst_jump_addr;
            end
            if (busy[head] && ready[head]) begin
                head <= head + 1;
                case (work_type[head])
                    TypeRg: begin
                        // things are done by wire
                    end
                    TypeSt: begin
                        // do nothing
                    end
                    TypeBr: begin
                        if (value[head][0] ^ jump_addr[head][0]) begin
                            new_pc <= {jump_addr[head][31:1], 1'b0};
                            clear  <= 1;
                        end
                    end
                    TypeEx: begin
                        $display("Finish Insturction Submitted.");
                        $finish();
                    end
                endcase
            end
        end
    end

    assign full = head == tail && busy[head];
    assign empty = head == tail && !busy[head];

    assign rob_id_head = head;
    assign rob_id_tail = tail;

    wire need_set_reg = (rdy_in && busy[head] && ready[head] && work_type[head] == TypeRg);
    assign set_reg_id = need_set_reg ? rd[head] : 0;
    assign set_val = value[head];

    assign set_dep_reg_id = (rdy_in && inst_valid) ? inst_rd : 0;
    assign set_dep_rob_id = (rdy_in && inst_valid) ? tail : 0;

endmodule
