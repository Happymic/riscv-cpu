# Branch and jump test program
# Tests all branch instructions and jump operations
# Verifies branch predictor and control flow

.text
.global _start

_start:
    # Test unconditional jump
    jal  x1, test_beq   # Jump to test_beq, save return address
    
    # Should not reach here
    addi x31, x0, 0xDEAD
    ebreak
    
test_beq:
    # Test branch equal
    addi x2, x0, 5      # x2 = 5
    addi x3, x0, 5      # x3 = 5
    beq  x2, x3, test_bne # Branch if x2 == x3 (should branch)
    
    # Should not reach here
    addi x31, x0, 0xDEAD
    ebreak

test_bne:
    # Test branch not equal
    addi x4, x0, 5      # x4 = 5
    addi x5, x0, 10     # x5 = 10
    bne  x4, x5, test_blt # Branch if x4 != x5 (should branch)
    
    # Should not reach here
    addi x31, x0, 0xDEAD
    ebreak

test_blt:
    # Test branch less than (signed)
    addi x6, x0, 5      # x6 = 5
    addi x7, x0, 10     # x7 = 10
    blt  x6, x7, test_bge # Branch if x6 < x7 (should branch)
    
    # Should not reach here
    addi x31, x0, 0xDEAD
    ebreak

test_bge:
    # Test branch greater or equal (signed)
    addi x8, x0, 10     # x8 = 10
    addi x9, x0, 5      # x9 = 5
    bge  x8, x9, test_bltu # Branch if x8 >= x9 (should branch)
    
    # Should not reach here
    addi x31, x0, 0xDEAD
    ebreak

test_bltu:
    # Test branch less than unsigned
    addi x10, x0, 5     # x10 = 5
    addi x11, x0, 10    # x11 = 10
    bltu x10, x11, test_bgeu # Branch if x10 < x11 unsigned (should branch)
    
    # Should not reach here
    addi x31, x0, 0xDEAD
    ebreak

test_bgeu:
    # Test branch greater or equal unsigned
    addi x12, x0, 10    # x12 = 10
    addi x13, x0, 5     # x13 = 5
    bgeu x12, x13, test_jalr # Branch if x12 >= x13 unsigned (should branch)
    
    # Should not reach here
    addi x31, x0, 0xDEAD
    ebreak

test_jalr:
    # Test jump and link register
    addi x14, x0, test_loop # Load address of test_loop
    jalr x15, x14, 0    # Jump to test_loop, save return in x15
    
    # Should not reach here immediately
    addi x31, x0, 0xDEAD
    j    test_end

test_loop:
    # Test loop with branches
    addi x16, x0, 10    # Loop counter
    addi x17, x0, 0     # Sum accumulator
    
loop:
    add  x17, x17, x16  # Add counter to sum
    addi x16, x16, -1   # Decrement counter
    bne  x16, x0, loop  # Continue if counter != 0
    
    # x17 should now contain sum of 1+2+...+10 = 55
    # Jump back using saved return address
    jalr x0, x15, 0

test_end:
    # Test completed successfully
    addi x30, x0, 0x600D # Good result marker
    ebreak