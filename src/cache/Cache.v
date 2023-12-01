
module Cache (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,   // data input bus
    output wire [ 7:0] mem_dout,  // data output bus
    output wire [31:0] mem_a,     // address bus (only 17:0 is used)
    output wire        mem_wr,    // write/read signal (1 for write)

    input wire inst_valid,
    input wire [31:0] PC,
    output wire inst_ready,
    output wire [31:0] inst_res,

    input wire data_valid,
    input wire data_wr,
    input wire [1:0] data_size,  // 0: byte, 1: halfword, 2: word
    input wire [31:0] data_addr,
    input wire [31:0] data_value,
    output wire data_ready,
    output wire [31:0] data_res
);
    // mx: MemoryCtrl
    reg         mc_enable;
    wire        mc_wr;
    wire [31:0] mc_addr;
    wire [ 1:0] mc_len;
    wire [31:0] mc_data;
    wire        mc_ready;
    wire [31:0] mc_res;
    wire        i_hit;
    wire [31:0] i_res;
    wire        i_we;  // i cache write enable
    InstuctionCache iCache (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .addr(PC),
        .hit (i_hit),
        .res (i_res),
        .we  (i_we),
        .data(mc_res)
    );

    MemoryController memCtrl (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),

        .valid(mc_enable),
        .wr(mc_wr),
        .addr(mc_addr),
        .len(mc_len),
        .data(mc_data),
        .ready(mc_ready),
        .res(mc_res)
    );


    reg working;
    reg work_type;

    // work on data and data is write
    assign mc_wr = work_type && data_wr;
    assign mc_addr = work_type ? data_addr : PC;
    assign mc_len = work_type ? data_size : 2'b10;
    assign mc_data = data_value;

    assign data_ready = working && work_type && mc_ready;
    assign data_res = mc_res;
    assign inst_ready = i_hit || (working && !work_type && mc_ready);
    assign inst_res = i_hit ? i_res : mc_res;
    assign i_we = working && !work_type && mc_ready;

    always @(posedge clk_in) begin
        if (rst_in) begin
            working   <= 0;
            work_type <= 0;
            mc_enable <= 0;
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else if (!working) begin
            if (data_valid) begin
                working   <= 1;
                work_type <= 1;
                mc_enable <= 1;
            end
            else if (inst_valid && !inst_ready) begin
                working   <= 1;
                work_type <= 0;
                mc_enable <= 1;
            end
        end
        else if (mc_ready) begin
            working   <= 0;
            mc_enable <= 0;
        end
    end

endmodule
