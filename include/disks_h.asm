        IFNDEF DISKS_H
        DEFINE DISKS_H

        ; Default disk letter on bootup
        DEFC DISK_DEFAULT_LETTER = 'A'

        ; Maximum number of disks at a time
        DEFC DISKS_MAX_COUNT = 26

        ; Public routines
        EXTERN zos_disks_init


        ENDIF ; DISKS_H