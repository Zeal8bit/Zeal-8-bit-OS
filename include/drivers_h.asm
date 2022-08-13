        IFNDEF DRIVERS_H
        DEFINE DRIVERS_H

        ; The drivers structure is like this:
        DEFVARS 0 {
                driver_name_t   DS.B 4
                driver_init_t   DS.W 1
                driver_read_t   DS.W 1
                driver_write_t  DS.W 1
                driver_open_t   DS.W 1
                driver_close_t  DS.W 1
                driver_seek_t   DS.W 1
                driver_ioctl_t  DS.W 1
                driver_deinit_t DS.W 1
                driver_end      DS.B 1
        }

        ; Provide a macro for defining a driver structure
        MACRO NEW_DRIVER_STRUCT name, init, read, write, open, close, seek, ioctl, deinit
            DEFS 4, name
            DEFW init
            DEFW read
            DEFW write
            DEFW open
            DEFW close
            DEFW seek
            DEFW ioctl
            DEFW deinit
        ENDM

        ; Maximum length of a driver name
        DEFC DRIVER_NAME_LENGTH = 4

        ; Number of functions in the driver structure
        DEFC DRIVER_STRUCT_FUNCTIONS = 8

        ; Size of the driver structure in bytes
        DEFC DRIVER_STRUCT_SIZE = (DRIVER_NAME_LENGTH + DRIVER_STRUCT_FUNCTIONS * 2)

        ENDIF