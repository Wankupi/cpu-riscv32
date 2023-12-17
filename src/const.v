`define VectorSize 32

`define DEBUG

`define RED "\033[31m"
`define GREEN "\033[32m"
`define YELLOW "\033[33m"
`define BLUE "\033[34m"
`define PURPLE "\033[35m"
`define RESET "\033[0m"

`define ROB_WIDTH_BIT 5
`define ROB_WIDTH (1 << `ROB_WIDTH_BIT)

`define ROB_TYPE_BIT 3

`define RS_TYPE_BIT 3


// LS_TYPE: 4 bit
// [3] { 0: r, 1: w }
// [2:0] { 000: b, 001: h, 010: w, 011: d, 100: b, 101: h, 110: w, 111: d  }
// dword may not support
`define LS_TYPE_BIT 4
