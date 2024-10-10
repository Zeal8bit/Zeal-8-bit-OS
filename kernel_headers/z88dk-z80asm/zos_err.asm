; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF ZOS_ERR_HEADER
    DEFINE ZOS_ERR_HEADER

    DEFGROUP
    {
        ERR_SUCCESS                = 0,
        ERR_FAILURE                = 1,
        ERR_NOT_IMPLEMENTED        = 2,
        ERR_NOT_SUPPORTED          = 3,
        ERR_NO_SUCH_ENTRY          = 4,
        ERR_INVALID_SYSCALL        = 5,
        ERR_INVALID_PARAMETER      = 6,
        ERR_INVALID_VIRT_PAGE      = 7,
        ERR_INVALID_PHYS_ADDRESS   = 8,
        ERR_INVALID_OFFSET         = 9,
        ERR_INVALID_NAME           = 10,
        ERR_INVALID_PATH           = 11,
        ERR_INVALID_FILESYSTEM     = 12,
        ERR_INVALID_FILEDEV        = 13,
        ERR_PATH_TOO_LONG          = 14,
        ERR_ALREADY_EXIST          = 15,
        ERR_ALREADY_OPENED         = 16,
        ERR_ALREADY_MOUNTED        = 17,
        ERR_READ_ONLY              = 18,
        ERR_BAD_MODE               = 19,
        ERR_CANNOT_REGISTER_MORE   = 20,
        ERR_NO_MORE_ENTRIES        = 21,
        ERR_NO_MORE_MEMORY         = 22,
        ERR_NOT_A_DIR              = 23,
        ERR_NOT_A_FILE             = 24,
        ERR_ENTRY_CORRUPTED        = 25,
        ERR_DIR_NOT_EMPTY          = 26,
    }

    ENDIF ; ZOS_ERR_HEADER
