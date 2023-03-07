; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .macro syscall number
        ld l, #number
        rst 8
    .endm

    ; Size of the buffers used for getchar and putchar
    .equ STD_BUFFER_SIZE, 80

    ; Put all the syscall glue from this file inside the _SYSTEM area/section
    .area _SYSTEM

    ; The following routines are written with SDCC new calling convention:
    ; __sdcccall(1).
    ; Thus, most parameters will be given in registers. Also, because the
    ; routines don't have variadic arguments and return a value less or equal
    ; to 16-bit, we will need to clean the stack.

    ; zos_err_t read(zos_dev_t dev, void* buf, uint16_t* size);
    ; Parameters:
    ;   A       - dev
    ;   DE      - buf
    ;   [Stack] - size*
    .globl _read
_read:
    ; We have to get the size from the pointer which is on the stack.
    ; Pop the return address and exchange with the pointer on the top.
    pop hl
    ex (sp), hl
    ; HL contains size*, top of the stack contains the return address.
    ; Dereference the size in BC
    ld c, (hl)
    inc hl
    ld b, (hl)
    ; Save back the address of size on the stack, we will use it to save
    ; the returned value (in BC)
    push hl
    ; Syscall parameters:
    ;   H - Opened dev
    ;   DE - Buffer source
    ;   BC - Buffer size
    ; Returns:
    ;   A - Error value
    ;   BC - Number of bytes read
    ld h, a
    syscall 0
    ; In any case, we have to clean the stack
    pop hl
    ; If error returned is not ERR_SUCCESS, do not alter the given size*
    or a
    ret nz
    ; No error so far, we can fill the pointer. Note, HL points to the MSB!
    ld (hl), b
    dec hl
    ld (hl), c
    ret


    ; zos_err_t write(zos_dev_t dev, const void* buf, uint16_t* size);
    .globl _write
_write:
    ; This routine is exactly the same as the one above
    pop hl
    ex (sp), hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    push hl
    ; Syscall parameters:
    ;   H - Opened dev
    ;   DE - Buffer source
    ;   BC - Buffer size
    ; Returns:
    ;   A - Error value
    ;   BC - Number of bytes written
    ld h, a
    syscall 1
    pop hl
    or a
    ret nz
    ld (hl), b
    dec hl
    ld (hl), c
    ret


    ; int8_t open(const char* name, uint8_t flags);
    ; Parameters:
    ;   HL      - name
    ;   [Stack] - flags
    .globl _open
_open:
    ; Copy name/path in BC, as required by the syscall.
    ld b, h
    ld c, l
    ; Get the flags, which are on the stack, behind the return address.
    ; We have to clean the stack.
    pop hl
    dec sp
    ex (sp), hl
    ; Syscall parameters:
    ;   BC - Name
    ;   H - Flags
    syscall 2
    ret


    ; zos_err_t close(zos_dev_t dev);
    ; Parameters:
    ;   A - dev
    .globl _close
_close:
    ld h, a
    ; Syscall parameters:
    ;   H - dev
    syscall 3
    ret


    ; zos_err_t dstat(zos_dev_t dev, zos_stat_t* stat);
    ; Parameters:
    ;   A  - dev
    ;   DE - *stat
    .globl _dstat
_dstat:
    ; Syscall parameters:
    ;   H  - Opened dev
    ;   DE - File stat structure address
    ld h, a
    syscall 4
    ret


    ; zos_err_t stat(const char* path, zos_stat_t* stat);
    ; Parameters:
    ;   HL - path
    ;   DE - stat
    .globl _stat
_stat:
    ; Syscall parameters:
    ;   BC - Path to file
    ;   DE - File stat structure address
    ld b, h
    ld c, l
    syscall 5
    ret


    ; zos_err_t seek(zos_dev_t dev, int32_t* offset, zos_whence_t whence);
    ; Parameters:
    ;   A  - dev
    ;   DE - *offset
    ;   [Stack] - whence
    .globl _seek
_seek:
    ; Pop return address in HL, and exchange with whence
    pop hl
    dec sp
    ex (sp), hl
    ; Put the whence in A and the dev in H
    ld l, a
    ld a, h
    ld h, l
    push hl
    ; Start by dereferencing offset from DE
    ex de, hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    ; Pop the parameter H back from the stack and save the offset
    ex (sp), hl
    ; Syscall parameters:
    ;   H - Dev number, must refer to an opened driver (not a file)
    ;   BCDE - 32-bit offset, signed if whence is SEEK_CUR/SEEK_END.
    ;          Unsigned if SEEK_SET.
    ;   A - Whence. Can be SEEK_CUR, SEEK_END, SEEK_SET.
    syscall 6
    ; Offset address in HL
    pop hl
    ; If an error occurred, return directly, without modifying offset* value.
    or a
    ret nz
    ; Update the value else
    ld (hl), b
    dec hl
    ld (hl), c
    dec hl
    ld (hl), d
    dec hl
    ld (hl), e
    ret


    ; zos_err_t ioctl(zos_dev_t dev, uint8_t cmd, void* arg);
    ; Parameters:
    ;   A - dev
    ;   L - cmd
    ;   [Stack] - arg
    .globl _ioctl
_ioctl:
    ; Put the command in C before we alter HL
    ld c, l
    ; Get "arg" parameter out of the stack
    pop hl
    ex (sp), hl
    ex de, hl
    ; Syscall parameters:
    ;   H - Dev number
    ;   C - Command number
    ;   DE - 16-bit parameter. Driver dependent.
    ld h, a
    syscall 7
    ret


    ; zos_err_t mkdir(const char* path);
    ; Parameter:
    ;   HL - path
    .globl _mkdir
_mkdir:
    ; Syscall parameter:
    ;   DE - Path
    ex de, hl
    syscall 8
    ret


    ; zos_err_t chdir(const char* path);
    ; Parameter:
    ;   HL - path
    .globl _chdir
_chdir:
    ; Syscall parameter:
    ;   DE - Path
    ex de, hl
    syscall 9
    ret


    ; zos_err_t curdir(char* path);
    ; Parameter:
    ;   HL - path
    .globl _curdir
_curdir:
    ; Syscall parameter:
    ;   DE - Path
    ex de, hl
    syscall 10
    ret


    ; zos_err_t opendir(const char* path);
    ; Parameter:
    ;   HL - path
    .globl _opendir
_opendir:
    ; Syscall parameter:
    ;   DE - Path
    ex de, hl
    syscall 11
    ret


    ; zos_err_t readdir(zos_dev_t dev, zos_dir_entry_t* dst);
    ; Parameters:
    ;   A - dev
    ;   DE - dst
    .globl _readdir
_readdir:
    ; Syscall parameter:
    ;   H - Opened dev number
    ;   DE - Directory entry address to fill
    ld h, a
    syscall 12
    ret


    ; zos_err_t rm(const char* path);
    ; Parameter:
    ;   HL - path
    .globl _rm
_rm:
    ; Syscall parameter:
    ;   DE - Path
    ex de, hl
    syscall 13
    ret


    ; zos_err_t mount(zos_dev_t dev, char letter, zos_fs_t fs);
    ; Parameters:
    ;   A - dev
    ;   L - letter
    ;   [Stack] - fs
    .globl _mount
_mount:
    ; Save letter in B, we will need HL
    ld b, l
    ; Pop fs number from the stack
    pop hl
    dec sp
    ex (sp), hl
    ; fs number in H
    ; Syscall parameters:
    ;   H - Dev number
    ;   D - Letter for the drive
    ;   E - File system
    ld e, h
    ld d, b
    ld h, a
    syscall 14
    ret

    ; void exit(void);
    .globl _exit
_exit:
    syscall 15
    ret

    ; zos_err_t exec(const char* name, char* argv[])
    ; Parameters:
    ;   HL - name
    ;   DE - argv
    .globl _exec
_exec:
    ; Syscall parameters:
    ;   BC - File to load and execute
    ;   DE - Parameter to give to the new program, only one parameter is supported
    ;        at the moment, so we need to dereference DE if it is not NULL.
    ld b, h
    ld c, l
    ld a, d
    or e
    jr z, _exec_syscall
    ; DE is not NULL, we have to dereference it
    ex de, hl
    ld e, (hl)
    inc hl
    ld d, (hl)
_exec_syscall:
    syscall 16
    ret


    ; zos_err_t dup(zos_dev_t dev, zos_dev_t ndev);
    ; Parameters:
    ;   A - dev
    ;   L - ndev
    .globl _dup
_dup:
    ; Syscall parameters:
    ;   H - Old dev number
    ;   E - New dev number
    ld h, a
    ld e, l
    syscall 17
    ret


    ; zos_err_t msleep(uint16_t duration);
    ; Parameters:
    ;   HL - duration
    .globl _msleep
_msleep:
    ; Syscall parameters:
    ;    DE - duration
    ex de, hl
    syscall 18
    ret


    ; zos_err_t settime(uint8_t id, zos_time_t* time);
    ; Parameters:
    ;   A - id
    ;   DE - time
    .globl _settime
_settime:
    ; Syscall parameters:
    ;   H - id
    ;   DE - time (v0.1.0 implementation of Zeal 8-bit OS requires
    ;        the milliseconds in DE directly, not an address)
    ex de, hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    ld h, a
    syscall 19
    ret


    ; zos_err_t gettime(uint8_t id, zos_time_t* time);
    ; Parameters:
    ;   A - id
    ;   DE - time
    .globl _gettime
_gettime:
    ; BC will be saved during the syscall
    ld b, d
    ld c, e
    ; Syscall parameters:
    ;   H - id
    ;   DE - time (v0.1.0 implementation of Zeal 8-bit OS requires
    ;        the milliseconds in DE directly, not an address)
    ld h, a
    syscall 20
    ; Syscall returns the time in DE on success.
    or a
    ret nz
    ; Success, we can fill the structure.
    ld l, c
    ld h, b
    ld (hl), e
    inc hl
    ld (hl), d
    ret


    ; zos_err_t setdate(const zos_date_t* date);
    ; Parameter:
    ;   HL - date
    .globl _setdate
_setdate:
    ; Syscall parameter:
    ;   DE - Date stucture
    ex de, hl
    syscall 21
    ret


    ; zos_err_t getdate(const zos_date_t* date);
    ; Parameter:
    ;   HL - date
    .globl _getdate
_getdate:
    ; Syscall parameter:
    ;   DE - Date stucture
    ex de, hl
    syscall 22
    ret


    ; zos_err_t map(void* vaddr, uint32_t paddr);
    ; Parameters:
    ;   HL - vaddr
    ;   [Stack] - paddr
    .globl _map
_map:
    ; Syscall parameters:
    ;   DE - Virtual adress
    ;   HBC - Upper 24-bit of physical address
    ex de, hl   ; virtual address in DE
    pop hl
    pop bc
    ex (sp), hl
    ld h, l
    syscall 23
    ret


    ; int getchar(void)
    ; Get next character from standard input. Input is buffered.
    ; Returns:
    ;   DE - Character received
    .globl _getchar
_getchar:
    ; Get the size of the buffer, if it's 0, we have to call the READ syscall
    ld a, (#_getchar_size)
    or a
    jp nz, _getchar_read_next
    ; Read a buffer from STDIN:
    ;   H - Opened dev
    ;   DE - Buffer source
    ;   BC - Buffer size
    ; Returns:
    ;   A - Error value
    ;   BC - Number of bytes written
    ld h, #1 ; DEV_STDIN
    ld de, #_getchar_buffer
    ld bc, #STD_BUFFER_SIZE
    syscall 0
    or a
    jr nz, _putchar_error
    ; Save the size in the static variable, we can ignore B, we know it's 0
    ; Put the size in A as required by the rest of the code
    ld a, c
    ld (#_getchar_size), a
_getchar_read_next:
    ; Before reading the character, check if we are going to reach the end of the buffer.
    ; In other words, check if Idx + 1 == A (size)
    ld hl, #_getchar_idx
    ld d, #0
    ld e, (hl)  ; Index of the buffer in DE
    inc (hl)
    cp (hl)
    ; If result is not 0 (likely), no need to reset the size and index
    jr nz, _getchar_read_next_no_reset
    ; Reset both index and size
    ld (hl), d  ; D is 0 already
    inc hl
    ld (hl), d
    dec hl
_getchar_read_next_no_reset:
    ; HL is pointing to the index in the buffer
    inc hl
    inc hl
    ; Offset of the next character to read: ADD HL, DE
    add hl, de
    ; Character to return in E, D is already 0
    ld e, (hl)
    ret



    ; int _putchar(int c)
    ; Print a character on the standard output. Output is buffered.
    ; Parameters:
    ;   HL - Character to print
    ; Returns:
    ;   DE - Character printed, EOF on error
    .globl _putchar
_putchar:
    ; Store the character to print in E, ignore high byte
    ld d, #0
    ld e, l
    ; Add the character to the buffer and increment the index
    ld a, (#_putchar_idx)
    ld c, a ; Backup A
    ld hl, #_putchar_buffer
    ; ADD HL, A
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ; Store the byte to print
    ld (hl), e
    ; We have to flush the buffer if ++A is 80 OR if A is '\n'
    inc c
    ld a, c
    ld (#_putchar_idx), a    ; In most cases, we won't flush
    ; BC = A
    ld b, #0
    sub #STD_BUFFER_SIZE
    jr z, _putchar_flush
    ; Check if the character is \n
    ld a, e
    sub #'\n'
    ; Return if we have nothing to flush
    ret nz
_putchar_flush:
    ; BC contains the current length of the buffer, update the index to 0 (A)
    ld (_putchar_idx), a
    ; Write the buffer to STDOUT:
    ;   H - Opened dev
    ;   DE - Buffer source
    ;   BC - Buffer size
    ; Returns:
    ;   A - Error value
    ;   BC - Number of bytes written
    ld h, a ; DEV_STDOUT = 0, A is 0 here
    push de ; Return value
    ld de, #_putchar_buffer
    syscall 1
    pop de
    ; Check if an error occurred
    or a
    ; Return directly on success
    ret z
_putchar_error:
    ; Error, set DE to EOF (-1)
    ld de, #0xffff
    ret


    .area _BSS
_getchar_idx:
    .ds 1
_getchar_size:
    .ds 1
_getchar_buffer:
    .ds STD_BUFFER_SIZE

_putchar_idx:
    .ds 1
_putchar_buffer:
    .ds STD_BUFFER_SIZE
