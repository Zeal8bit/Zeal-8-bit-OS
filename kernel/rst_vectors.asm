; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    ; Required for configuration struture
    INCLUDE "osconfig.asm"
    INCLUDE "disks_h.asm"
    INCLUDE "target_h.asm"

    ; If the kernel is compiled without MMU support, set the macro to 0
    ; so that it can still be placed in the configuration structure.
  IFNDEF CONFIG_KERNEL_TARGET_HAS_MMU
    DEFC CONFIG_KERNEL_TARGET_HAS_MMU = 0
  ENDIF

    ; Reference the OS entry point
    EXTERN zos_entry
    EXTERN zos_sys_perform_syscall
    EXTERN _zos_default_init

    ; Make the implemented vectors public
    PUBLIC zos_software_reset
    PUBLIC zos_mode1_isr_entry


    SECTION RST_VECTORS
    ; Vector 0 is also Software reset
rst_vector_0:
zos_software_reset:
    ; In theory, on reset the Z80 interrupt are disabled, let's be 100% sure
    ; and disable them again
    di
    jp zos_entry
    ; Address 0x0004 must contain a pointer to the kernel configuration structure
    DEFW kernel_config_t
    nop
    nop
    ; Syscall entry point
    ; Parameters:
    ;   L - Syscall operation number
    ;   Check documentation for the parameters of each operation
    ; Alters:
    ;   None - Registers are saved by the callee
zos_syscall:
rst_vector_8:
    jp zos_sys_perform_syscall
    nop
    nop
    nop
    nop
    nop
zop_call_hl:
rst_vector_10:
    jp (hl)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
zos_breakpoint:
rst_vector_18:
    nop
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


    ; For simplicity reasons, place the kernel configuration structure here for now
kernel_config_t:
    DEFB CONFIG_TARGET_NUMBER
    DEFB CONFIG_KERNEL_TARGET_HAS_MMU
    DEFB DISK_DEFAULT_LETTER
    DEFB CONFIG_KERNEL_MAX_LOADED_DRIVERS
    DEFB CONFIG_KERNEL_MAX_OPENED_DEVICES
    DEFB CONFIG_KERNEL_MAX_OPENED_FILES
    DEFW CONFIG_KERNEL_PATH_MAX
    DEFW CONFIG_KERNEL_INIT_EXECUTABLE_ADDR
    DEFW _zos_default_init
    ; Target specific pointer, check if any was provided
  IF CONFIG_TARGET_CUSTOM_CONFIG
    DEFW target_custom_area_addr
  ELSE
    DEFW 0
  ENDIF

    ; Assert that these reset vectors are at the right place
    IF 0
    ASSERT(rst_vector_0  = 0x00)
    ASSERT(rst_vector_8  = 0x08)
    ASSERT(rst_vector_10 = 0x10)
    ASSERT(rst_vector_18 = 0x18)
    ASSERT(rst_vector_20 = 0x20)
    ASSERT(rst_vector_28 = 0x28)
    ASSERT(rst_vector_30 = 0x30)
    ASSERT(rst_vector_38 = 0x38)
    ENDIF
