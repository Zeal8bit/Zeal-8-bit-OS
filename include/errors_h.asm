; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF ERRORS_H
        DEFINE ERRORS_H

        DEFGROUP
        {
                ERR_SUCCESS = 0,
                ERR_FAILURE,
                ERR_NOT_IMPLEMENTED,
                ERR_NOT_SUPPORTED,
                ERR_NO_SUCH_ENTRY,
                ERR_INVALID_SYSCALL,
                ERR_INVALID_PARAMETER,
                ERR_INVALID_VIRT_PAGE,
                ERR_INVALID_PHYS_ADDRESS,
                ERR_INVALID_OFFSET,
                ERR_INVALID_NAME,
                ERR_INVALID_PATH,
                ERR_INVALID_FILESYSTEM,
                ERR_INVALID_FILEDEV,
                ERR_PATH_TOO_LONG,
                ERR_ALREADY_EXIST,
                ERR_ALREADY_OPENED,
                ERR_ALREADY_MOUNTED,
                ERR_READ_ONLY,
                ERR_BAD_MODE,
                ERR_CANNOT_REGISTER_MORE,
                ERR_NO_MORE_ENTRIES,
                ERR_NO_MORE_MEMORY,
                ERR_NOT_A_DIR,
                ERR_NOT_A_FILE,
                ERR_ENTRY_CORRUPTED,
                ERR_DIR_NOT_EMPTY,
                ERR_SPECIAL_STATE,  ; Used when a special key is received on the keyboard
                ERR_TIMEOUT,
                ; This error code is a special value that can only be used
                ; by the drivers. It can be returned by the driver's init
                ; routine in order to tell the kernel to NOT register the
                ; driver in the accessible list. Thus, the users won't be
                ; able to retrieve its program. (useful for block drivers
                ; for example or target's routines needed to be executed at
                ; boot)
                ERR_DRIVER_HIDDEN = 255
        }

        ENDIF