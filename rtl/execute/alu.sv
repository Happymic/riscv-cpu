// Arithmetic Logic Unit (ALU)
// Author: Auto-generated
// Date: 2025-09-03
// -----------------------------------------------------------------------------
// Purpose:
// - Implements integer arithmetic/logic/shift/compare operations for RV64.
// - Provides result along with simple flags (zero, overflow, carry).
//
// Operation selection:
// - alu_op encoding matches the simplified control unit mapping.
// - Shifts use lower 6 bits of b as shift amount for 64-bit operands.
//
// Flags:
// - zero: result==0
// - overflow: set for add/sub when signed overflow occurs
// - carry: MSB of add/sub extended result (unsigned carry/borrow)
// -----------------------------------------------------------------------------

module alu #(
    parameter XLEN = 64
) (
    // Operands
    input  logic [XLEN-1:0]    a,
    input  logic [XLEN-1:0]    b,
    input  logic [3:0]         alu_op,
    
    // Result
    output logic [XLEN-1:0]    result,
    output logic               zero,
    output logic               overflow,
    output logic               carry
);

    // ALU operations
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b1000;
    localparam ALU_SLL  = 4'b0001;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b1101;
    localparam ALU_OR   = 4'b0110;
    localparam ALU_AND  = 4'b0111;

    // Internal signals
    logic [XLEN:0] add_result;
    logic [XLEN:0] sub_result;
    logic [XLEN-1:0] and_result;
    logic [XLEN-1:0] or_result;
    logic [XLEN-1:0] xor_result;
    logic [XLEN-1:0] sll_result;
    logic [XLEN-1:0] srl_result;
    logic [XLEN-1:0] sra_result;
    logic [XLEN-1:0] slt_result;
    logic [XLEN-1:0] sltu_result;

    // Shift amount (lower 6 bits for 64-bit, 5 bits for 32-bit)
    logic [5:0] shamt;
    assign shamt = b[5:0];

    // Arithmetic operations
    assign add_result = {1'b0, a} + {1'b0, b};
    assign sub_result = {1'b0, a} - {1'b0, b};

    // Logical operations
    assign and_result = a & b;
    assign or_result = a | b;
    assign xor_result = a ^ b;

    // Shift operations
    assign sll_result = a << shamt;
    assign srl_result = a >> shamt;
    assign sra_result = $signed(a) >>> shamt;

    // Comparison operations
    assign slt_result = ($signed(a) < $signed(b)) ? {{(XLEN-1){1'b0}}, 1'b1} : '0;
    assign sltu_result = (a < b) ? {{(XLEN-1){1'b0}}, 1'b1} : '0;

    // Result multiplexer
    always_comb begin
        case (alu_op)
            ALU_ADD:  result = add_result[XLEN-1:0];
            ALU_SUB:  result = sub_result[XLEN-1:0];
            ALU_SLL:  result = sll_result;
            ALU_SLT:  result = slt_result;
            ALU_SLTU: result = sltu_result;
            ALU_XOR:  result = xor_result;
            ALU_SRL:  result = srl_result;
            ALU_SRA:  result = sra_result;
            ALU_OR:   result = or_result;
            ALU_AND:  result = and_result;
            default:  result = '0;
        endcase
    end

    // Flag generation
    assign zero = (result == '0);
    
    // Overflow detection for add/subtract
    logic add_overflow, sub_overflow;
    assign add_overflow = (a[XLEN-1] == b[XLEN-1]) && (result[XLEN-1] != a[XLEN-1]);
    assign sub_overflow = (a[XLEN-1] != b[XLEN-1]) && (result[XLEN-1] != a[XLEN-1]);
    
    always_comb begin
        case (alu_op)
            ALU_ADD:  overflow = add_overflow;
            ALU_SUB:  overflow = sub_overflow;
            default:  overflow = 1'b0;
        endcase
    end

    // Carry generation
    always_comb begin
        case (alu_op)
            ALU_ADD:  carry = add_result[XLEN];
            ALU_SUB:  carry = sub_result[XLEN];
            default:  carry = 1'b0;
        endcase
    end

endmodule
