`include "const.v"

module ReorderBuffer #(
    parameter ROB_SIZE_BIT = `ROB_WIDTH_BIT
) (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    // from decoder
    input wire                         inst_valid,
    input wire                         inst_ready,
    input wire [`ROB_TYPE_BIT - 1 : 0] inst_type,
    input wire [                  4:0] inst_rd,
    input wire [                 31:0] inst_value,
    input wire [                 31:0] inst_pc,
    input wire [                 31:0] inst_jump_addr,

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

    // between ReorderBuffer and Register
    input  wire [`ROB_WIDTH_BIT - 1 : 0] get_rob_id1,
    output wire                          rob_value1_ready,
    output wire [                  31:0] rob_value1,
    input  wire [`ROB_WIDTH_BIT - 1 : 0] get_rob_id2,
    output wire                          rob_value2_ready,
    output wire [                  31:0] rob_value2,

    output reg clear,
    output reg [31:0] new_pc
);

    localparam ROB_SIZE = 1 << ROB_SIZE_BIT;

    localparam TypeRg = `ROB_TYPE_RG;
    localparam TypeSt = `ROB_TYPE_ST;
    localparam TypeBr = `ROB_TYPE_BR;
    localparam TypeEx = `ROB_TYPE_EX;

    reg                       busy     [0 : ROB_SIZE - 1];
    reg                       ready    [0 : ROB_SIZE - 1];
    reg [`ROB_TYPE_BIT - 1:0] work_type[0 : ROB_SIZE - 1];
    reg [                4:0] rd       [0 : ROB_SIZE - 1];
    reg [               31:0] value    [0 : ROB_SIZE - 1];
    reg [               31:0] inst_addr[0 : ROB_SIZE - 1];
    reg [               31:0] jump_addr[0 : ROB_SIZE - 1];

    reg [ROB_SIZE_BIT - 1:0] head, tail;

    reg [31:0] dbg_size, dbg_stall;
    wire [31:0] dbg_pc_head = inst_addr[head];
    reg [31:0] dbg_commited;
    wire dbg_ready_head = ready[head];
    wire dbg_ready18 = ready[18];

    always @(posedge clk_in) begin
        if (rst_in) dbg_commited <= 1;
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
            head <= 0;
            tail <= 0;
            dbg_size <= 0;
            dbg_stall <= 0;
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
                if (head == tail && busy[head] && !ready[head]) begin
                    $display(`ERR("RoB"), "full but still adding");
                    $finish();
                end
                // $display(`LOG("RoB"), ": add inst %x", inst_pc);
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
                dbg_commited <= dbg_commited + 1;

`ifdef DEBUG
                $write("[%5d] ", dbg_commited);
`endif
                head <= head + 1;
                busy[head] <= 0;
                ready[head] <= 0;
                case (work_type[head])
                    TypeRg: begin
                        // things are done by wire
`ifdef DEBUG
                        $display("%h", inst_addr[head], " reg[%d] = %8h", rd[head], value[head]);
`endif
                    end
                    TypeSt: begin
                        // do nothing
`ifdef DEBUG
                        $display("%h", inst_addr[head], " st");
`endif
                    end
                    TypeBr: begin
                        if (value[head][0] ^ jump_addr[head][0]) begin
                            new_pc <= {jump_addr[head][31:1], 1'b0};
                            clear  <= 1;
                        end
`ifdef DEBUG
                        $display("%h", inst_addr[head], " br %8h", value[head] ? jump_addr[head] : inst_addr[head] + 4);
                        // if (inst_addr[head] == 32'h0000104c) $display($time);
`endif
                    end
                    TypeEx: begin
                        $finish();
                    end
                endcase
            end

            if (inst_valid && !(busy[head] && ready[head])) dbg_size <= dbg_size + 1;
            else if (!inst_valid && (busy[head] && ready[head])) dbg_size <= dbg_size - 1;
            if (ready[head]) dbg_stall <= 0;
            else dbg_stall <= dbg_stall + 1;
            if (dbg_stall > 50) begin
                $display(`ERR("RoB"), "stall too long");
                $finish();
            end
        end
    end

    assign full = (head == tail && busy[head]) || (tail + `ROB_WIDTH_BIT'b1 == head && inst_valid && !ready[head]);
    assign empty = head == tail && !busy[head];

    assign rob_id_head = head;
    assign rob_id_tail = tail;

    wire need_set_reg = (rdy_in && busy[head] && ready[head] && work_type[head] == TypeRg);
    assign set_reg_id = need_set_reg ? rd[head] : 0;
    assign set_reg_on_rob_id = need_set_reg ? head : 0;
    assign set_val = need_set_reg ? value[head] : 0;

    wire need_set_dep = rdy_in && inst_valid && inst_type == TypeRg;
    assign set_dep_reg_id = need_set_dep ? inst_rd : 0;
    assign set_dep_rob_id = need_set_dep ? tail : 0;

    assign rob_value1_ready = ready[get_rob_id1] || (rs_ready && rs_rob_id == get_rob_id1) || (lsb_ready && lsb_rob_id == get_rob_id1);
    assign rob_value1 = ready[get_rob_id1] ? value[get_rob_id1] : (rs_ready && rs_rob_id == get_rob_id1) ? rs_value : (lsb_ready && lsb_rob_id == get_rob_id1) ? lsb_value : 32'b0;
    assign rob_value2_ready = ready[get_rob_id2] || (rs_ready && rs_rob_id == get_rob_id2) || (lsb_ready && lsb_rob_id == get_rob_id2);
    assign rob_value2 = ready[get_rob_id2] ? value[get_rob_id2] : (rs_ready && rs_rob_id == get_rob_id2) ? rs_value : (lsb_ready && lsb_rob_id == get_rob_id2) ? lsb_value : 32'b0;

    wire [`ROB_TYPE_BIT -  1:0] dbg_head_work_type = work_type[head];
endmodule
