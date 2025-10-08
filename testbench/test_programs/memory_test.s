# Memory access test program
# Tests load and store operations with different data sizes
# Verifies cache functionality and memory interface

.text
.global _start

_start:
    # Initialize base address
    lui  x10, 0x1000    # x10 = 0x1000000 (base address)
    
    # Test word operations
    addi x1, x0, 0x12345678
    sw   x1, 0(x10)     # Store word at base
    lw   x2, 0(x10)     # Load word from base
    # x2 should equal x1
    
    # Test halfword operations
    addi x3, x0, 0x1234
    sh   x3, 4(x10)     # Store halfword at base+4
    lh   x4, 4(x10)     # Load halfword from base+4
    lhu  x5, 4(x10)     # Load halfword unsigned
    
    # Test byte operations
    addi x6, x0, 0x56
    sb   x6, 8(x10)     # Store byte at base+8
    lb   x7, 8(x10)     # Load byte from base+8
    lbu  x8, 8(x10)     # Load byte unsigned
    
    # Test negative values
    addi x9, x0, -1
    sb   x9, 9(x10)     # Store -1 as byte
    lb   x11, 9(x10)    # Load signed byte (-1)
    lbu  x12, 9(x10)    # Load unsigned byte (255)
    
    # Test unaligned access
    addi x13, x0, 0xAABBCCDD
    sw   x13, 10(x10)   # Store at unaligned address
    lw   x14, 10(x10)   # Load from unaligned address
    
    # Test sequential memory access
    addi x15, x0, 100   # Loop counter
    addi x16, x10, 100  # Start address for array
    
loop:
    sw   x15, 0(x16)    # Store counter value
    lw   x17, 0(x16)    # Load it back
    addi x16, x16, 4    # Next word
    addi x15, x15, -1   # Decrement counter
    bne  x15, x0, loop  # Continue if not zero
    
    # End test
    ebreak