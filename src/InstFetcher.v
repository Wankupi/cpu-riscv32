module InstFetcher (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    output reg [31:0] PC,
    input wire inst_ready_in,
    input wire [31:0] inst_in,

    // lines between decoder
    input wire stall,
    output reg inst_ready_out,
    output reg [31:0] inst_addr,
    output reg [31:0] inst_out
);
    always @(posedge clk_in) begin
        if (rst_in) begin
            PC <= 0;
            inst_ready_out <= 0;
            inst_addr <= 0;
            inst_out <= 0;
        end
        else if (!rdy_in || stall || !inst_ready_in) begin
            // do nothing
        end
        else begin
            PC <= PC + 4;
            inst_ready_out <= 1;
            inst_addr <= PC;
            inst_out <= inst_in;
        end
    end
endmodule
