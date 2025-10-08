# Basic RISC-V test program
# Tests basic arithmetic and logical operations
# Expected to verify ALU functionality and register file

.text
.global _start

_start:
    # Test basic arithmetic
    addi x1, x0, 5      # x1 = 5
    addi x2, x0, 10     # x2 = 10
    add  x3, x1, x2     # x3 = x1 + x2 = 15
    sub  x4, x2, x1     # x4 = x2 - x1 = 5
    
    # Test logical operations
    addi x5, x0, 0xFF   # x5 = 255
    addi x6, x0, 0x0F   # x6 = 15
    and  x7, x5, x6     # x7 = x5 & x6 = 15
    or   x8, x5, x6     # x8 = x5 | x6 = 255
    xor  x9, x5, x6     # x9 = x5 ^ x6 = 240
    
    # Test shift operations
    addi x10, x0, 8     # x10 = 8
    addi x11, x0, 2     # x11 = 2
    sll  x12, x10, x11  # x12 = x10 << x11 = 32
    srl  x13, x10, x11  # x13 = x10 >> x11 = 2
    
    # Test immediate operations
    addi x14, x0, -5    # x14 = -5
    slti x15, x14, 0    # x15 = (x14 < 0) = 1
    sltiu x16, x14, 5   # x16 = (x14 < 5 unsigned) = 1
    
    # End test
    ebreak