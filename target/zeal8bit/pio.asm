        INCLUDE "errors_h.asm"  
        INCLUDE "drivers_h.asm"      
        
        SECTION KERNEL_DRV_TEXT
pio_init:
        ld b, message_end - message
        ld c, 0x1
        ld hl, message
        otir
        ; Return success
        ld a, ERR_SUCCESS
        ret

pio_read:
pio_write:
pio_open:
pio_close:
pio_seek:
pio_ioctl:
pio_deinit:
        ret


message: DEFM "Hello from PIO driver", 0
message_end:

        SECTION KERNEL_DRV_VECTORS
NEW_DRIVER_STRUCT("GPIO", \
                  pio_init, \
                  pio_read, pio_write, \
                  pio_open, pio_close, \
                  pio_seek, pio_ioctl, \
                  pio_deinit)