        ORG 0x4000

        DEFC DEV_STDOUT = 0

        MACRO SYSCALL _
                rst 0x8
        ENDM
main:
        ; Try to print a message on the screen
        ld hl, DEV_STDOUT << 8 | 1
        ld de, welcome
        ld bc, welcome_end - welcome
        SYSCALL()
loop:   jp loop

welcome:
        DEFM "Success: init progam loaded!\n", 0
welcome_end: