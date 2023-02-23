; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0


    ; This file not only acts as a crt0 file, which prepares the C-context by initializing globals and
    ; static variables, but also as a linker script file. We have to specify the order of the sections.
    ; This file MUST be the first one when compiling any C file for Zeal 8-bit OS.
    .module crt0
    .globl _main
    .globl _exit
    .globl l__DATA
    .globl s__DATA
    .globl l__BSS
    .globl s__BSS
    .globl l__INITIALIZER
    .globl s__INITIALIZER
    .globl s__INITIALIZED

    ; First section of the final binary, we don't need to give an absolute address here.
    ; Indeed, the linker will do this. As such, all the sections below will follow this one.
    ; No gap is indeed in-between, not even between data and source code.
    ; Indeed, Zeal 8-bit OS loads all the programs in RAM before executing them, so all the
    ; program space is accessible in Read/Write/Execute.
    .area _HEADER
init:
    call init_globals
    call _main
    jp _exit

    ; GSINIT section contains code generated by SDCC that initialized the global and static variables.
    ; Thus, we have to execute this code before invoking user's main function.
    .area _GSINIT
    ; Parameters:
    ;   BC - Length of the section
    ;   HL - Source address of the section to clean (set to 0)
clean_section:
    ld a, b
    or c
    ret z
    ld (hl), #0
    dec bc
    ld a, b
    or c
    ret z
    ld d, h
    ld e, l
    inc de
    ldir
    ret

init_globals:
    ; Initialize the DATA section to 0. For some reasons, SDCC puts static variables initialized to 0
    ; in DATA section, and not BSS. Thus, we must erase it.
    ld bc, #l__DATA  ; Length of DATA section
    ld hl, #s__DATA  ; Start address of DATA section
    call clean_section
    ; Do the same thing for BSS section.
    ld bc, #l__BSS  ; Length of BSS section
    ld hl, #s__BSS  ; Start of BSS section
    call clean_section
    ; Initialize the INITIALIZED section.
    ld bc, #l__INITIALIZER ; Length of initializer section
    ld a, b
    or c
    jr z, _init_end
    ld hl, #s__INITIALIZER
    ld de, #s__INITIALIZED
    ldir
_init_end:

    ; Final instruction fo the GS section.
    .area _GSFINAL
    ret

    ; The following section contains the data to copy to the _INITIALIZED section.
    .area _INITIALIZER


    ; =========== START OF CODE =========== ;
    .area _HOME

    ; TEXT section contains the actual user's code. We MUST use this section to store the code
    ; intead of the default _CODE one because the SDCC assembler/linker will always put _CODE
    ; as the first section. We don't want this behavior, we cannot override it, so let's work
    ; around it.
    .area _TEXT

    ; SYSTEM section contains the system library code that acts as a glue between C and OS assembly.
    .area _SYSTEM
    ; ============ END OF CODE ============ ;


    ; =========== START OF DATA =========== ;
    ; The following sections contain data, group them.
    .area _INITIALIZED
    .area _BSEG
    .area _BSS
    .area _DATA
    .area _HEAP
    ; ============ END OF DATA ============ ;