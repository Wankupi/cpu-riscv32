`include "const.v"

module Decoder (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire        valid,
    input wire [31:0] inst_addr,
    input wire [31:0] inst,

    output wire [                   4:0] get_reg_id1,
    input  wire [                  31:0] rs1_val_in,
    input  wire                          has_dep1,
    input  wire [`ROB_WIDTH_BIT - 1 : 0] dep1,

    output wire [                   4:0] get_reg_id2,
    input  wire [                  31:0] rs2_val_in,
    input  wire                          has_dep2,
    input  wire [`ROB_WIDTH_BIT - 1 : 0] dep2,

    // from ReorderBuffer
    input  wire                          rob_full,
    input  wire [`ROB_WIDTH_BIT - 1 : 0] rob_free_id,
    // to ReorderBuffer // TODO:
    output wire                          rob_valid,
    output wire [ `ROB_TYPE_BIT - 1 : 0] rob_type,
    output wire [                   4:0] rob_reg_id,
    output wire [                  31:0] rob_value,
    output wire [                  31:0] rob_inst_addr,
    output wire [                  31:0] rob_jump_addr,
    output wire                          rob_ready,

    // from ReservationStation
    input  wire                        rs_full,
    // to ReservationStation
    output wire                        rs_valid,     // TODO:
    output wire [`RS_TYPE_BIT - 1 : 0] rs_type,      // TODO:
    output wire [                31:0] rs_r1,
    output wire [                31:0] rs_r2,
    output wire [`ROB_WIDTH_BIT - 1:0] rs_dep1,
    output wire [`ROB_WIDTH_BIT - 1:0] rs_dep2,
    output wire                        rs_has_dep1,
    output wire                        rs_has_dep2,
    output wire [`ROB_WIDTH_BIT - 1:0] rs_rob_id,

    // from LoadStoreBuffer
    input  wire                        lsb_full,
    // to LoadStoreBuffer
    output wire                        lsb_valid,     // TODO:
    output wire [`LS_TYPE_BIT - 1 : 0] lsb_type,      // TODO:
    output wire [                31:0] lsb_r1,
    output wire [                31:0] lsb_r2,
    output wire [`ROB_WIDTH_BIT - 1:0] lsb_dep1,
    output wire [`ROB_WIDTH_BIT - 1:0] lsb_dep2,
    output wire                        lsb_has_dep1,
    output wire                        lsb_has_dep2,
    output wire [                11:0] lsb_offset,
    output wire [`ROB_WIDTH_BIT - 1:0] lsb_rob_id,

    // to vector extension
    // TODO:

    // to InstFetcher
    output wire        if_stall,    // TODO:
    output wire [31:0] if_set_addr  // TODO:
);

    wire [  6:0] opcode = inst[6:0];
    wire [  2:0] func = inst[14:12];
    wire [  7:0] ex_func = inst[31:25];

    wire [  4:0] rd = inst[11:7];
    wire [  4:0] rs1 = inst[19:15];
    wire [  4:0] rs2 = inst[24:20];
    wire [31:12] immU = inst[31:12];
    wire [ 20:1] immJ = {inst[31], inst[19:12], inst[20], inst[30:21]};
    wire [ 11:0] immI = inst[31:20];
    wire [ 12:1] immB = {inst[31], inst[7], inst[30:25], inst[11:8]};
    wire [ 11:0] immS = {inst[31:25], inst[11:7]};
    wire [  4:0] shamt = inst[24:20];



    wire         is_branch = (inst[6:0] == 7'b1100011);
    wire         is_jalr = (inst[6:0] == 7'b1100111);
    wire         is_jal = (inst[6:0] == 7'b1101111);

    wire         need_work = valid && (last_inst_addr != inst_addr);


    assign get_reg_id1 = rs1;
    assign get_reg_id2 = rs2;

    reg [31:0] rs1_val, rs2_val;
    reg is_dep1, is_dep2;
    reg [`ROB_WIDTH_BIT - 1 : 0] dep1_val, dep2_val;

    reg [31:0] last_inst_addr;
    always @(posedge clk_in) begin
        if (rst_in) begin
            last_inst_addr <= 32'hffffffff;
            is_dep1 <= 0;
            is_dep2 <= 0;
            dep1_val <= 0;
            dep2_val <= 0;
            // TODO
        end
        else if (!rdy_in || !need_work) begin
            // do nothing
        end
        else begin
            last_inst_addr <= inst_addr;
            is_dep1 <= has_dep1;
            is_dep2 <= has_dep2;
            dep1_val <= dep1;
            dep2_val <= dep2;
            rs1_val <= rs1_val_in;
            rs2_val <= rs2_val_in;
        end
    end

    assign rs_r1 = rs1_val;
    assign rs_r2 = rs2_val;
    assign rs_dep1 = dep1_val;
    assign rs_dep2 = dep2_val;
    assign rs_has_dep1 = is_dep1;
    assign rs_has_dep2 = is_dep2;
    assign rs_rob_id = rob_free_id;

    assign lsb_r1 = rs1_val;
    assign lsb_r2 = rs2_val;
    assign lsb_dep1 = dep1_val;
    assign lsb_dep2 = dep2_val;
    assign lsb_has_dep1 = is_dep1;
    assign lsb_has_dep2 = is_dep2;
    assign lsb_rob_id = rob_free_id;
    assign lsb_offset = (opcode == 7'b0000011) ? immI : immS;
endmodule
