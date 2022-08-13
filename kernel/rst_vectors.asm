    ; Reference the OS entry point
    EXTERN zos_entry
    
    ; Make the implemented vectors public  
    PUBLIC zos_software_reset
    PUBLIC zos_syscall
    PUBLIC zos_mode1_isr_entry

    SECTION RST_VECTORS
    ; Vector 0 is also Software reset
rst_vector_0:
zos_software_reset:
    ; In theory, on reset the Z80 interrupt are disabled, let's be 100% sure
    ; and disable them again
    di
	jp zos_entry
    nop
    nop
    nop
    nop
    ; Syscall entry point
    ; Parameters:
    ;   L - Syscall operation number
    ;   Check documentation for the parameters of each operation
    ; Alters:
    ;   None - Registers are saved y the callee 
zos_syscall:
rst_vector_8:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
zos_breakpoint:
rst_vector_10:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
zop_call_hl:
rst_vector_18:
    jp (hl)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
rst_vector_20:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
rst_vector_28:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
rst_vector_30:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
zos_mode1_isr_entry:
rst_vector_38:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    ; Assert that these reset vectors are at the right place
    ASSERT(rst_vector_0  = 0x00)
    ASSERT(rst_vector_8  = 0x08)
    ASSERT(rst_vector_10 = 0x10)
    ASSERT(rst_vector_18 = 0x18)
    ASSERT(rst_vector_20 = 0x20)
    ASSERT(rst_vector_28 = 0x28)
    ASSERT(rst_vector_30 = 0x30)
    ASSERT(rst_vector_38 = 0x38)
