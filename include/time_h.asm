        IFNDEF TIME_H
        DEFINE TIME_H

        EXTERN zos_time_msleep
        EXTERN zos_time_settime
        EXTERN zos_time_gettime

        ; Date structure definition.
        ; We can find this structure in file stats or even rawtable file system.
        ; NOTE:
        ;       All the values are in BCD format! In other words, one digit is held
        ;       inside a nibble.
        ;       For example, year 2022 will be encoded inside 16-bits/2 bytes/4 nibbles:
        ;       0010 0000 0010 0010
        ;         2    0    2    2 
        DEFVARS 0 {
                date_year_t     DS.B 2  ; Range [1970-2999]
                date_month_t    DS.B 1  ; Range [1-12]
                date_day_t      DS.B 1  ; Range [1-31]
                date_date_t     DS.B 1  ; Range [1-7] (Sunday, Monday, Tuesday, ...)
                date_hours_t    DS.B 1  ; Range [0-23]
                date_minutes_t  DS.B 1  ; Range [0-59]
                date_seconds_t  DS.B 1  ; Range [0-59]
                date_end_t      DS.B 1
        }

        DEFC DATE_STRUCT_SIZE = date_end_t

        ; Time structure definition.
        ; Used by settime and gettime syscalls. It represents elapsed time
        ; in milliseconds.
        ; The implementation may change to alter the number of bytes required:
        ;       - 16-bit allows maximum 65535 milliseconds (1 minute 5 seconds)
        ;       - 24-bit allows maximum 16777215 milliseconds (279 minutes)
        ;       - 32-bit allows maximum of 49 days
        ; For the moment, we'll stick to 16-bit timers for a simple reason:
        ; If one needs more than a second, it is possible to use the date instead.
        DEFVARS 0 {
                time_millis_t   DS.B 2
                time_end_t
        }

        DEFC TIME_STRUCT_SIZE = time_end_t

        ENDIF