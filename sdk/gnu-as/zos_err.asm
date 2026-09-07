; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .equiv ZOS_ERR_HEADER, 1

    .equ ERR_SUCCESS,               0
    .equ ERR_FAILURE,               1
    .equ ERR_NOT_IMPLEMENTED,       2
    .equ ERR_NOT_SUPPORTED,         3
    .equ ERR_NO_SUCH_ENTRY,         4
    .equ ERR_INVALID_SYSCALL,       5
    .equ ERR_INVALID_PARAMETER,     6
    .equ ERR_INVALID_VIRT_PAGE,     7
    .equ ERR_INVALID_PHYS_ADDRESS,  8
    .equ ERR_INVALID_OFFSET,        9
    .equ ERR_INVALID_NAME,          10
    .equ ERR_INVALID_PATH,          11
    .equ ERR_INVALID_FILESYSTEM,    12
    .equ ERR_INVALID_FILEDEV,       13
    .equ ERR_PATH_TOO_LONG,         14
    .equ ERR_ALREADY_EXIST,         15
    .equ ERR_ALREADY_OPENED,        16
    .equ ERR_ALREADY_MOUNTED,       17
    .equ ERR_READ_ONLY,             18
    .equ ERR_BAD_MODE,              19
    .equ ERR_CANNOT_REGISTER_MORE,  20
    .equ ERR_NO_MORE_ENTRIES,       21
    .equ ERR_NO_MORE_MEMORY,        22
    .equ ERR_NOT_A_DIR,             23
    .equ ERR_NOT_A_FILE,            24
    .equ ERR_ENTRY_CORRUPTED,       25
    .equ ERR_DIR_NOT_EMPTY,         26
