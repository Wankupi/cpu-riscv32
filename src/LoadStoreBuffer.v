`include "const.v"

module LoadStoreBuffer #(
    parameter LSB_SIZE_BIT = 4
) (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    // from Decoder
    input  wire                        inst_valid,
    input  wire [`LS_TYPE_BIT - 1 : 0] inst_type,
    input  wire [                31:0] inst_r1,
    input  wire [                31:0] inst_r2,
    input  wire [`ROB_WIDTH_BIT - 1:0] inst_dep1,
    input  wire [`ROB_WIDTH_BIT - 1:0] inst_dep2,
    input  wire                        inst_has_dep1,
    input  wire                        inst_has_dep2,
    input  wire [                11:0] inst_offset,
    input  wire [`ROB_WIDTH_BIT - 1:0] inst_rob_id,
    // to Decoder
    output wire                        full,

    // with cache
    /*
	cache_size[1:0] 0: byte, 1: halfword, 2: word
    cache_size[2] signed or not signed
	*/
    output wire        cache_valid,
    output wire        cache_wr,
    output wire [ 2:0] cache_size,
    output wire [31:0] cache_addr,
    output wire [31:0] cache_value,
    input  wire        cache_ready,
    input  wire [31:0] cache_res,

    // from ReservationStation
    input wire                          rs_ready,
    input wire [`ROB_WIDTH_BIT - 1 : 0] rs_rob_id,
    input wire [                  31:0] rs_value,

    // output LoadStoreBuffer result
    output wire                         lsb_ready,
    output wire [`ROB_WIDTH_BIT- 1 : 0] lsb_rob_id,
    output wire [                 31:0] lsb_value
);

    localparam LSB_SIZE = 1 << LSB_SIZE_BIT;

    reg [  LSB_SIZE_BIT - 1:0] head;
    reg [  LSB_SIZE_BIT - 1:0] tail;

    reg                        busy     [0 : LSB_SIZE - 1];
    reg [`ROB_WIDTH_BIT - 1:0] rob_id   [0 : LSB_SIZE - 1];
    reg [  `LS_TYPE_BIT - 1:0] work_type[0 : LSB_SIZE - 1];
    reg [                31:0] r1       [0 : LSB_SIZE - 1];
    reg [                31:0] r2       [0 : LSB_SIZE - 1];
    reg [`ROB_WIDTH_BIT - 1:0] dep1     [0 : LSB_SIZE - 1];
    reg [`ROB_WIDTH_BIT - 1:0] dep2     [0 : LSB_SIZE - 1];
    reg                        has_dep1 [0 : LSB_SIZE - 1];
    reg                        has_dep2 [0 : LSB_SIZE - 1];
    reg [                11:0] offset   [0 : LSB_SIZE - 1];


    wire full_real, pop_able;

    assign full_real = (head == tail) && busy[head];
    assign pop_able  = cache_ready;

    // is_working
    reg  work;
    // k : which slot to shot
    wire k = work ? head + 1 : head;
    wire shot_able = busy[k] && !has_dep1[k] && !has_dep2[k];
    wire shot_this_cycle = shot_able && (!work || cache_ready);

    assign cache_valid = work;

    always @(posedge clk_in) begin
        if (rst_in) begin
            head <= 0;
            tail <= 0;
            work <= 0;
            // TODO: init other registers
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else begin
            if (shot_this_cycle) begin
                work <= 1;
            end
            else if (work && cache_ready) begin
                work <= 0;
            end

            // push
            if (inst_valid) begin
                tail <= tail + 1;
                busy[tail] <= 1;
                rob_id[tail] <= inst_rob_id;
                work_type[tail] <= inst_type;
                r1[tail] <= inst_r1;
                r2[tail] <= inst_r2;
                dep1[tail] <= inst_dep1;
                dep2[tail] <= inst_dep2;
                has_dep1[tail] <= inst_has_dep1;
                has_dep2[tail] <= inst_has_dep2;
                offset[tail] <= inst_offset;
            end
            // pop
            if (pop_able) begin
                head <= head + 1;
                busy[head] <= 0;
            end

            for (integer i = 0; i < LSB_SIZE; i = i + 1) begin
                if (busy[i]) begin
                    if (rs_ready && has_dep1[i] && (rs_rob_id == dep1[i])) begin
                        r1[i] <= rs_value;
                        has_dep1[i] <= 0;
                    end
                    if (rs_ready && has_dep2[i] && (rs_rob_id == dep2[i])) begin
                        r2[i] <= rs_value;
                        has_dep2[i] <= 0;
                    end
                    if (lsb_ready && has_dep1[i] && (lsb_rob_id == dep1[i])) begin
                        r1[i] <= lsb_value;
                        has_dep1[i] <= 0;
                    end
                    if (lsb_ready && has_dep2[i] && (lsb_rob_id == dep2[i])) begin
                        r2[i] <= lsb_value;
                        has_dep2[i] <= 0;
                    end
                end
            end
        end
    end

    assign full = full_real && !shot_able;

    assign cache_wr = work_type[head][3];
    assign cache_addr = r1[head] + offset[head];
    assign cache_size = work_type[head][2:0];
    assign cache_value = r2[head];

    assign lsb_ready = cache_ready;
    assign lsb_rob_id = rob_id[head];
    assign lsb_value = cache_res;
endmodule
