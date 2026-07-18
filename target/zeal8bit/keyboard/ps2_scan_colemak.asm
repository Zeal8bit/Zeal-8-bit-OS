; The tables MUST be defined in this order:
;   - base_scan
;   - extascii_scan (optional, depends on CONFIG_LAYOUT_USE_EXTENDED_ASCII)
;   - upper_scan
;   - alt_scan
base_scan:
        DEFB 0, KB_F9, 0, KB_F5, KB_F3, KB_F1, KB_F2, KB_F12, 0, KB_F10, KB_F8, KB_F6, KB_F4, '\t', '`', 0
        DEFB 0, KB_LEFT_ALT, KB_LEFT_SHIFT, 0, KB_LEFT_CTRL, 'q', '1', 0, 0, 0, 'z', 'r', 'a', 'w', '2', 0
        DEFB 0, 'c', 'x', 's', 'f', '4', '3', 0, 0, ' ', 'v', 't', 'g', 'p', '5', 0
        DEFB 0, 'm', 'b', 'h', 'd', 'j', '6', 0, 0, 0, ',', 'n', 'l', '7', '8', 0
        DEFB 0, 'k', 'e', 'u', 'y', '0', '9', 0, 0, '.', '/', 'i', 'o', ';', '-', 0
        DEFB 0, 0, '\'', 0, '[', '=', 0, 0, KB_CAPS_LOCK, KB_RIGHT_SHIFT, '\n', ']', 0, '\\'
upper_scan:
        DEFB 0, KB_F9, 0, KB_F5, KB_F3, KB_F1, KB_F2, KB_F12, 0, KB_F10, KB_F8, KB_F6, KB_F4, '\t', '~', 0
        DEFB 0, KB_LEFT_ALT, KB_LEFT_SHIFT, 0, KB_LEFT_CTRL, 'Q', '!', 0, 0, 0, 'Z', 'R', 'A', 'W', '@', 0
        DEFB 0, 'C', 'X', 'S', 'F', '$', '#', 0, 0, ' ', 'V', 'T', 'G', 'P', '%', 0
        DEFB 0, 'M', 'B', 'H', 'D', 'J', '^', 0, 0, 0, '<', 'N', 'L', '&', '*', 0
        DEFB 0, 'K', 'E', 'U', 'Y', ')', '(', 0, 0, '>', '?', 'I', 'O', ':', '_', 0
        DEFB 0, 0, '"', 0, '{', '+', 0, 0, KB_CAPS_LOCK, KB_RIGHT_SHIFT, '\n', '}', 0, '|'
alt_scan:
