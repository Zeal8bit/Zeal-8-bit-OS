; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"
        INCLUDE "zos_video.asm"
        INCLUDE "zos_keyboard.asm"
	INCLUDE "strutils_h.asm"
        INCLUDE "zealline.asm"


        DEFC BG_COLOR     = TEXT_COLOR_BLACK
        DEFC CURDIR_COLOR = TEXT_COLOR_LIGHT_GRAY
        DEFC TEXT_COLOR   = TEXT_COLOR_WHITE

        ; Designate the order of the sections before starting the code
        ; We can name the sections whatever we want, but it has to match
        ; across all the files

        ; ---------------- START ----------------;
        SECTION TEXT
        ORG 0x4000
        SECTION DATA
        SECTION BSS
        ; Give a hardcoded address to the BSS section so that it is not put inside the TEXT
        ; binary (and init.bin file is then smaller)
        ; This value should be adapted if the TEXT section grows bigger.
        ORG 0x6000
        ; ----------------  END  ----------------;

        ; Start the actual code
        SECTION TEXT
        DEFC PROMPT_CHAR = '>'
        DEFC ESCAPE_CHAR = 0x1B

        EXTERN error_print
        EXTERN parse_exec_cmd
        EXTERN zealline_init
        EXTERN zealline_get_line
        EXTERN zealline_set_prompt
        EXTERN zealline_add_history

        MACRO ERR_CHECK goto_label
                or a
                jr nz, goto_label
        ENDM

        ; copies the prompt_prefix into the prompt
        ; Parameters:
        ;       None
        ; Returns:
        ; Alters: HL, A
        MACRO SETUP_PROMPT_PREFIX _
                ld hl, prompt
                REPTI char, ESCAPE_CHAR, 'c', TEXT_COLOR_BLACK, TEXT_COLOR_LIGHT_GRAY
                        ld (hl), char
                        inc hl
                ENDR
        ENDM


main:
        call zealline_init
        SETUP_PROMPT_PREFIX()
next_command:
        call setup_prompt
        ERR_CHECK(error_current_dir)

        ld hl, prompt
        call zealline_set_prompt     ; HL - ptr to prompt

        ; Read from the stdin
        ld de, bigbuffer
        ld bc, bigbuffer_end - bigbuffer        ; B should be 0, C should be the max length
        call zealline_get_line

        push af
        push bc
        S_WRITE3(DEV_STDOUT, newline_char, 1)
        pop bc
        pop af

        ERR_CHECK(error_reading_stdin)
        ; The command line size has been put in BC, BC can also be 0,
        ld a, b
        or c
        jp z, next_command

        ; parse_exec_cmd modfied the data in bigbuffer
        ; that is why we add the history here. If we would do that after exec() we could only
        ; add it if the exit code is 0, for example.
        ld hl, bigbuffer
        call zealline_add_history

        ; We can now parse the command line
        ld de, bigbuffer
        call parse_exec_cmd

        jp next_command


error_current_dir:
        ld de, str_curdir_err
        ld bc, str_curdir_err_end - str_curdir_err
        jr call_err_loop
str_curdir_err:
        DEFM "error getting curdir: "
str_curdir_err_end:

error_reading_stdin:
        ld de, str_rdstdin_err
        ld bc, str_rdstdin_err_end - str_rdstdin_err
call_err_loop:
        call error_print
        jr err_loop
str_rdstdin_err:
        DEFM "error reading input: "
str_rdstdin_err_end:

err_loop:
        halt
        jr $


        ; Get the current directory from the kernel, retrieve its size,
        ; append the PROMPT_CHAR and prompt_suffix and save the new length in curdir_len
        ; Parameters:
        ;       None
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, DE, HL
setup_prompt:
        ; Get the current directory
        ld de, curdir
        CURDIR()
        or a
        ret nz
        ex de, hl
_setup_prompt_loop:
        cp (hl)
        jp z, _setup_prompt_loop_end
        inc hl
        jp _setup_prompt_loop
_setup_prompt_loop_end:
        ; copy prompt_char and the prompt_prefix and a null-byte
        REPTI char, PROMPT_CHAR, ESCAPE_CHAR, 'c', TEXT_COLOR_BLACK, TEXT_COLOR_WHITE, 0x0
                ld (hl), char
                inc hl
        ENDR
        xor a   ; Success
        ret

        SECTION DATA
newline_char: DEFM "\n"
prompt: DEFM ESCAPE_CHAR, 'c', TEXT_COLOR_BLACK, TEXT_COLOR_LIGHT_GRAY ; == prompt_prefix
curdir: DEFS PATH_MAX + 1 + 4   ; ... + sizeof(nullbyte) + sizeof(prompt_suffix)


        SECTION BSS
bigbuffer: DEFS 81
bigbuffer_end:
        ; Allocate a few more bytes so that we can append some characters
        DEFS 2

        PUBLIC init_static_buffer
        PUBLIC init_static_buffer_end
init_static_buffer: DEFS 1024
init_static_buffer_end:
