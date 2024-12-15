base_scan:
        DEFB 0, KB_F9, 0, KB_F5, KB_F3, KB_F1, KB_F2, KB_F12, 0, KB_F10, KB_F8, KB_F6, KB_F4, '\t', '`', 0
        DEFB 0, KB_LEFT_ALT, KB_LEFT_SHIFT, 0, KB_LEFT_CTRL, '\'', '1', 0, 0, 0, ';', 'o', 'a', ',', '2', 0
        DEFB 0, 'j', 'q', 'e', '.', '4', '3', 0, 0, ' ', 'k', 'u', 'y', 'p', '5', 0
        DEFB 0, 'b', 'x', 'd', 'i', 'f', '6', 0, 0, 0, 'm', 'h', 'g', '7', '8', 0
        DEFB 0, 'w', 't', 'c', 'r', '0', '9', 0, 0, 'v', 'z', 'n', 's', 'l', '[', 0
        DEFB 0, 0, '-', 0, '/', ']', 0, 0, KB_CAPS_LOCK, KB_RIGHT_SHIFT, '\n', '=', 0, '\\'
upper_scan:
        DEFB 0, KB_F9, 0, KB_F5, KB_F3, KB_F1, KB_F2, KB_F12, 0, KB_F10, KB_F8, KB_F6, KB_F4, '\t', '~', 0
        DEFB 0, KB_LEFT_ALT, KB_LEFT_SHIFT, 0, KB_LEFT_CTRL, '"', '!', 0, 0, 0, ':', 'O', 'A', '<', '@', 0
        DEFB 0, 'J', 'Q', 'E', '>', '$', '#', 0, 0, ' ', 'K', 'U', 'Y', 'P', '%', 0
        DEFB 0, 'B', 'X', 'D', 'I', 'F', '^', 0, 0, 0, 'M', 'H', 'G', '&', '*', 0
        DEFB 0, 'W', 'T', 'C', 'R', ')', '(', 0, 0, 'V', 'Z', 'N', 'S', 'L', '{', 0
        DEFB 0, 0, '_', 0, '?', '}', 0, 0, KB_CAPS_LOCK, KB_RIGHT_SHIFT, '\n', '+', 0, '|'
