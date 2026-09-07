/* SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: CC0-1.0
 */

#include <stdio.h>
#include <stdint.h>
#include "zos_errors.h"
#include "zos_sys.h"
#include "zos_vfs.h"
#include "zos_keyboard.h"

/**
 * Raw keyboard example: switch the keyboard to raw mode, echo every pressed
 * key and quit when Enter is pressed.
 *
 * In raw mode, both key presses and key releases are sent to the program.
 * Values >= 0x80 mark special keys or key release events, they are ignored
 * here. See zos_keyboard.h for all the key codes and modes.
 */
int main(void) {
    char key;
    uint16_t size;
    zos_err_t err;

    /* Put the keyboard in raw mode so every key event is sent to us */
    err = ioctl(DEV_STDIN, KB_CMD_SET_MODE, (void*)KB_MODE_RAW);
    if (err != ERR_SUCCESS) {
        printf("Failed to set keyboard raw mode: %d\n", err);
        return 1;
    }

    printf("Raw keyboard mode: press a key to echo it, Enter to quit.\n");

    for (;;) {
        /* Read a single key, blocking until a key is pressed */
        size = 1;
        err = read(DEV_STDIN, &key, &size);
        if (err != ERR_SUCCESS) {
            break;
        }

        /* Ignore special keys and key release events */
        if ((uint8_t)key >= 0x80) {
            continue;
        }

        /* Enter quits */
        if (key == '\n') {
            break;
        }

        /* Echo the pressed character back on the standard output */
        size = 1;
        write(DEV_STDOUT, &key, &size);
    }

    return 0;
}
