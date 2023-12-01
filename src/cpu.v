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

    reg data_valid;
    reg data_wr;
    reg [2:0] data_size;
    reg [31:0] data_addr;
    reg [31:0] data_value;
    wire data_ready;
    wire [31:0] data_res;

    Cache cache (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),

        .inst_valid(inst_valid),
        .PC(PC),
        .inst_ready(inst_ready),
        .inst_res(inst),

        .data_valid(data_valid),
        .data_wr(data_wr),
        .data_size(data_size),
        .data_addr(data_addr),
        .data_value(data_value),
        .data_ready(data_ready),
        .data_res(data_res)
    );

    reg  [ 4:0] reg_set_id;
    reg  [31:0] reg_set_val;
    wire [ 4:0] reg_get_id1;
    wire [ 4:0] reg_get_id2;
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

    assign reg_get_id1 = rs1;
    assign reg_get_id2 = rs2;

    always @(posedge clk_in) begin
        if (rst_in) begin
            inst_valid <= 1;
            PC <= 0;
            data_valid <= 0;
            data_wr <= 0;
            data_size <= 0;
            data_value <= 0;
            data_addr <= 0;
            reg_set_id <= 0;
            reg_set_val <= 0;
            Store.store_status <= 0;
            Load.load_status <= 0;
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else if (!inst_ready) begin
            // do nothing
        end
        else begin
            // $display("inst %h at %h", inst, PC);
            case (opcode)
                7'b0110111: begin : LUI
                    reg_set_id <= rd;
                    reg_set_val <= {immU, 12'b0};
                    PC <= PC + 4;
                end
                7'b1101111: begin : JAL
                    reg_set_id <= rd;
                    reg_set_val <= PC + 4;
                    PC <= PC + {immJ, 1'b0};
                end
                7'b0010011: begin : Itype
                    case (func)
                        3'b000: begin : addi
                            reg_set_id <= rd;
                            reg_set_val <= reg_get_val1 + immI;
                            PC <= PC + 4;
                        end
                        default: begin
                            $display("Itype %h at %h not support", inst, PC);
                        end
                    endcase
                end
                7'b0100011: begin : Store
                    reg store_status;
                    if (!store_status) begin
                        data_valid <= 1;
                        data_wr <= 1;
                        data_size <= func;
                        data_addr <= reg_get_val1 + immS;
                        data_value <= reg_get_val2;
                        store_status <= 1;
                    end
                    else if (data_ready) begin
                        PC <= PC + 4;
                        data_valid <= 0;
                        store_status <= 0;
                    end
                end
                7'b0000011: begin : Load
                    reg load_status;
                    if (!load_status) begin
                        data_valid <= 1;
                        data_wr <= 0;
                        data_size <= func;
                        data_addr <= reg_get_val1 + immI;
                        load_status <= 1;
                    end
                    else if (data_ready) begin
                        reg_set_id <= rd;
                        reg_set_val <= data_res;
                        PC <= PC + 4;
                        data_valid <= 0;
                        load_status <= 0;
                    end
                end
                7'b1100011: begin : Branch
                    if (get_branch_result(reg_get_val1, reg_get_val2, func)) begin
                        PC <= PC + $signed({immB, 1'b0});
                    end
                    else begin
                        PC <= PC + 4;
                    end
                end
                default: begin
                    $display("inst %h at %h not support", inst, PC);
                    $finish();
                end
            endcase
        end
    end


    function get_branch_result;
        input [31:0] val1;
        input [31:0] val2;
        input [2:0] func;
        case (func)
            3'b000:  get_branch_result = val1 == val2;
            3'b001:  get_branch_result = val1 != val2;
            3'b100:  get_branch_result = $signed(val1) < $signed(val2);
            3'b101:  get_branch_result = $signed(val1) >= $signed(val2);
            3'b110:  get_branch_result = $unsigned(val1) < $unsigned(val2);
            3'b111:  get_branch_result = $unsigned(val1) >= $unsigned(val2);
            default: get_branch_result = 0;
        endcase
    endfunction
endmodule
