        ; File regrouping all the time-related routines, it includes
        ; timers, clocks, dates and sleep
        INCLUDE "errors_h.asm"
        INCLUDE "time_h.asm"

        PUBLIC zos_time_msleep
zos_time_msleep:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        PUBLIC zos_time_settime
zos_time_settime:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        PUBLIC zos_time_gettime
zos_time_gettime:
        ld a, ERR_NOT_IMPLEMENTED
        ret

