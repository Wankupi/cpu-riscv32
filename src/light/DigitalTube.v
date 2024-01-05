module DigitalTube (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] value,
    input  wire        set,
    output wire [ 6:0] seg,
    output reg  [ 3:0] an,
    output wire        dp
);
    reg  [15:0] out;
    wire [ 3:0] display = an[0] ? out[3:0] : an[1] ? out[7:4] : an[2] ? out[11:8] : out[15:12];
    assign dp = 0;
    assign seg = display == 4'h0 ? 7'b0111111 :  // 0: abcdef
        display == 4'h1 ? 7'b0000110 :  // 1: bc
        display == 4'h2 ? 7'b1011011 :  // 2: abdeg
        display == 4'h3 ? 7'b1001111 :  // 3: abcdg
        display == 4'h4 ? 7'b1101100 :  // 4: cdfg
        display == 4'h5 ? 7'b1101101 :  // 5: acdfg
        display == 4'h6 ? 7'b1111101 :  // 6: acdefg
        display == 4'h7 ? 7'b0000111 :  // 7: abc
        display == 4'h8 ? 7'b1111111 :  // 8: abcdefg
        display == 4'h9 ? 7'b1101111 :  // 9: abcdfg
        display == 4'ha ? 7'b1110111 :  // a: abcefg
        display == 4'hb ? 7'b1111100 :  // b: cdefg
        display == 4'hc ? 7'b0111001 :  // c: adef
        display == 4'hd ? 7'b1011110 :  // d: bcdeg
        display == 4'he ? 7'b1111001 :  // e: adefg
        display == 4'hf ? 7'b1110001 :  // f: aefg
        7'b0;
    always @(posedge clk) begin
        if (rst) begin
            out <= 0;
            an  <= 1;
        end
        else begin
            if (set) begin
                out <= value;
            end
            an <= {an[2:0], an[3]};
        end
    end
endmodule
