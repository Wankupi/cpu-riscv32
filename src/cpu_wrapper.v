module cpu_wrapper (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7 : 0] mem_din,   // data input bus
    output wire [ 7 : 0] mem_dout,  // data output bus
    output wire [31 : 0] mem_a,     // address bus (only 17 : 0 is used)
    output wire          mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    output wire [31 : 0] dbgreg_dout  // cpu register output (debugging demo)
);

    wire [  71:0] dbg_rob_info;
    wire          debug_output_en;
    wire [ 7 : 0] debug_output_data;
    wire [31 : 0] count_finished;

    wire [   7:0] umem_din;
    wire [   7:0] umem_dout;
    wire [  31:0] umem_a;
    wire          umem_wr;

    cpu real_cpu (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in & ~debug_output_en & ~new_commit),

        .mem_din(umem_din),
        .mem_dout(umem_dout),
        .mem_a(umem_a),
        .mem_wr(umem_wr),

        .io_buffer_full(io_buffer_full),

        .dbgreg_dout(dbgreg_dout),
        .count_finished(count_finished),
        .dbg_rob_info(dbg_rob_info)
    );
    reg [31:0] last_rob_count;
    wire new_commit = last_rob_count != count_finished;

    always @(posedge clk_in) begin
        if (rst_in) begin
            last_rob_count <= 0;
        end
        else if (rdy_in) begin
            last_rob_count <= count_finished;
        end
    end
    wire stall;

    debug_info debug (
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),
        .enable(new_commit),
        .count_finished(count_finished),
        .rob_info(dbg_rob_info),
        .uart_en(debug_output_en),
        .uart_data(debug_output_data),
        .stall(stall)
    );

    reg [8:0] saved_data;
    reg       last_dbg_en;
    always @(posedge clk_in) begin
        if (rdy_in) begin
            last_dbg_en <= debug_output_en;
            if (new_commit) begin
                saved_data <= mem_din;
            end
        end
    end

    wire restore = last_dbg_en & ~debug_output_en;
    assign umem_din = restore ? saved_data : mem_din;

    assign mem_dout = debug_output_en ? debug_output_data : umem_dout;
    assign mem_a = debug_output_en ? (stall ? 32'b0 : 32'h00030000) : umem_a;
    assign mem_wr = debug_output_en ? (~stall) : umem_wr;
endmodule
