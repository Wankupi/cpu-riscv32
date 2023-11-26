module MemoryController (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,   // data input bus
    output wire [ 7:0] mem_dout,  // data output bus
    output wire [31:0] mem_a,     // address bus (only 17:0 is used)
    output wire        mem_wr,    // write/read signal (1 for write)

    input  wire        inst_valid,
    input  wire [31:0] inst_addr,
    output wire        inst_ready,
    output wire [31:0] inst_res,

    input  wire        data_valid,
    input  wire [31:0] data_addr,
    input  wire [31:0] data_data,
    input  wire        data_wr,
    output wire        data_ready,
    output wire [31:0] data_res
);

    localparam Inst = 0;
    localparam Data = 1;

    reg working;
    reg work_type;
    reg [2:0] work_cycle;

    reg rw;
    reg [31:0] addr;
    reg [7:0] toMem;

    reg [31:0] result;
    reg [1:0] ready;

    wire need_work = inst_valid || data_valid;
    wire inst_or_data = data_valid;

    assign mem_wr = rw;
    assign mem_a = addr;
    assign data_res = result;
    assign inst_res = {mem_din, result[23:0]};
    assign mem_dout = toMem;
    assign inst_ready = ready[Inst], data_ready = ready[Data];

    always @(posedge clk_in) begin
        if (rst_in) begin
            working <= 0;
            work_type <= 0;
            work_cycle <= 0;
            rw <= 0;
            addr <= 0;
            toMem <= 0;
            result <= 0;
            ready <= 0;
            // TODO
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else begin
            if (!working) begin
                if (need_work) begin
                    working <= 1;
                    work_cycle <= 0;
                    work_type <= inst_or_data == Inst ? Inst : Data;
                    rw = inst_or_data == Inst ? 0 : data_wr;
                    addr   <= inst_or_data == Inst ? inst_addr : data_addr;
                    result <= data_data;
                    toMem  <= data_data[7:0];
                    ready  <= 0;
                end
            end
            else begin  // working
                work_cycle <= work_cycle + 1;
                if (work_cycle < 3) begin
                    addr <= addr + 1;
                end
                case (work_cycle)
                    0: begin
                        toMem <= result[15:8];
                    end
                    1: begin
                        toMem <= result[23:16];
                        result[7:0] <= mem_din;
                    end
                    2: begin
                        toMem <= result[31:24];
                        result[15:8] <= mem_din;
                    end
                    3: begin
                        result[23:16] <= mem_din;
                        ready[work_type] <= 1;
                        working <= 0;
                    end
                    // 4: begin
                    //     result[31:24] <= mem_din;
                    // end
                endcase
            end
        end
    end
endmodule
