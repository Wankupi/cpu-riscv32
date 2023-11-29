// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,   // data input bus
    output wire [ 7:0] mem_dout,  // data output bus
    output wire [31:0] mem_a,     // address bus (only 17:0 is used)
    output wire        mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    output wire [31:0] dbgreg_dout  // cpu register output (debugging demo)
);

    // implementation goes here

    // Specifications:
    // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
    // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
    // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
    // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
    // - 0x30000 read: read a byte from input
    // - 0x30000 write: write a byte to output (write 0x00 is ignored)
    // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
    // - 0x30004 write: indicates program stop (will output '\0' through uart tx)

    reg inst_valid;
    reg [31:0] PC;

    wire inst_ready;
    wire [31:0] inst;

    wire data_ready;
    wire [31:0] data_res;

    MemoryController mem_controller (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),

        .inst_valid(inst_valid),
        .inst_addr (PC),
        .inst_ready(inst_ready),
        .inst_res  (inst),

        .data_valid(1'b0),
        .data_addr(32'b0),
        .data_data(32'b0),
        .data_wr(1'b0),
        .data_ready(data_ready),
        .data_res(data_res)
    );

    reg  [ 4:0] reg_set_id;
    reg  [31:0] reg_set_val;
    reg  [ 4:0] reg_get_id1;
    reg  [ 4:0] reg_get_id2;
    wire [31:0] reg_get_val1;
    wire [31:0] reg_get_val2;

    RegisterFile regFile (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .set_reg_id(reg_set_id),
        .set_val(reg_set_val),

        .get_id1 (reg_get_id1),
        .get_id2 (reg_get_id2),
        .get_val1(reg_get_val1),
        .get_val2(reg_get_val2)
    );

    wire [6:0] opcode;
    assign opcode = inst[6:0];


    wire [  3:0] U_rd = inst[11:7];
    wire [31:12] U_imm = inst[31:12];
    wire [ 20:1] J_imm = {inst[31], inst[19:12], inst[20], inst[30:21]};

    always @(posedge clk_in) begin
        if (rst_in) begin
            inst_valid <= 1;
            PC <= 0;
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else if (!inst_ready) begin
            // do nothing
        end
        else begin
            case (opcode)
                7'b0110111: begin : LUI
                    reg_set_id <= U_rd;
                    reg_set_val <= {U_imm, 12'b0};
                    PC <= PC + 4;
                end
                7'b1101111: begin : JAL
                    reg_set_id <= U_rd;
                    reg_set_val <= PC + 4;
                    PC <= PC + {J_imm, 1'b0};
                end
                default: begin
                    $display("inst %h at %h not support not", inst, PC);
                    $finish();
                end
            endcase
        end
    end


endmodule
