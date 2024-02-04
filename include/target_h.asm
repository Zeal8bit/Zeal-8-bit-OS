; SPDX-FileCopyrightText: 2023-2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF TARGET_H
        DEFINE TARGET_H

        ; Function called as soon as the MMU and the stack are set up
        EXTERN target_coldboot

        ; Function called after program exit
        EXTERN target_exit

        ; Function called after the drivers are all initialized
        EXTERN target_drivers_hook

        ENDIF