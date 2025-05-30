;;;; functions of zealline.asm

        ; "zealline_init" sets up stuff
        ; Alters: A
	EXTERN zealline_init

        ; "zealline_set_prompt" sets the prompt
        ;   Stores the NULL-terminated string from HL as the next prompt
        ; Parameter:
        ;       HL - Pointer to the NULL-terminated string
        ; Alters: A
        ; Returns:
	EXTERN zealline_set_prompt

        ; "zline_get_line" reads a line/command from STDIN
        ;   This is the main function of this library. It will print your
        ;   prompt and read the line into your buffer.
        ;   While MAX_LINE_LENGTH is your line buffer size it still does only
        ;   return the first C bytes.
        ;   The string written to buffer will the null terminated. Keep in mind
        ;   that the null-byte consumeds one byte so there will only be C-1 characters
        ;   in DE. 
        ;   TODO:
        ;     - manage a history
        ;     - call tab completions functions
        ; Parameters:
        ;   DE - Buffer to store the bytes read from the opened device.
        ;   C - Size of the buffer passed, can not be longer then MAX_LINE_LENGTH
        ; Returns:
        ;   A  - ERR_SUCCESS on success, error value else
        ;   BC - Number of bytes filled in DE.
        ; Alters:
        ;   A, BC, DE
	EXTERN zealline_get_line

;;;; functions of zealline_scancode.asm

        ; "zealline_to_uppercase" reads a line/command from STDIN
        ;   Converts a Zeal Scancode in Register B to its uppercase
        ; Parameters:
        ;   B - the lowercase Zeal OS scancode
        ; Returns:
        ;   A  - In uppercase or Null if no uppercase is avaible
        ; Alters:
        ;   A
	EXTERN zealline_to_uppercase

;;;; functions of zealline_history.asm

        ; Resets the history serach iterator
        ; Alters: HL
	EXTERN zealline_reset_history_search

        ; Searches backward through the history, retrieving the previous line.
        ; Returns: HL - the pointer to the line
        ;          BC - length of the line
        ; Alters: IX, A, HL
	EXTERN zealline_history_search_backward

        ; Searches forward through the history, revriving the next line
        ; Returns: HL - the pointer to the line
        ;          BC - length of the line
        ; Alters: IX, A, HL
	EXTERN zealline_history_search_forward

        ; "zealline_add_history" stores a command to the history
        ;   Stores the NULL-terminated string from HL as into the ringbuffer.
        ;   In the case the ringbuffer is full old values will be removed from
        ;   in order to create space for the new line.
        ;
        ;   There is some kind of alignment for the history_entry struct that is
        ;   written to the ringbuffer which ensures that the "header" of the string
        ;   is never going across the end of the ringbuffer. This is achieved by
        ;   ensuring that the starting address of each entry is aligned to a 4-byte
        ;   boundary. Since the header is 3 bytes long (next pointer + length byte),
        ;   it will always fit within the remaining space before the boundary.
        ; Parameter:
        ;       HL - Pointer to the NULL-terminated string
        ; Alters: A, IX, IY
        ; Returns:
        ;   A  - ERR_SUCCESS on success, error value else
	EXTERN zealline_add_history

;;;; functions of zealline_configuration.asm

