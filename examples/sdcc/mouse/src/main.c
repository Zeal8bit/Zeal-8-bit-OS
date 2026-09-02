/* SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: CC0-1.0
 */

#include <stdio.h>
#include <stdint.h>
#include "zos_errors.h"
#include "zos_sys.h"
#include "zos_vfs.h"
#include "zos_mouse.h"

/**
 * Mouse example: open the mouse driver and print the accumulated movement
 * and button state for a while.
 *
 * The mouse driver provides the accumulated state through the `read` syscall:
 * X and Y contain the movement since the last read, and are reset afterwards.
 * The device is opened by its name "#MOUS". See zos_mouse.h for details.
 */
int main(void) {
    zos_dev_t dev;
    zos_mouse_state_t state;
    uint16_t size;
    zos_err_t err;
    int i;

    /* Open the mouse driver */
    dev = open(MOUSE_DEVICE_NAME, O_RDONLY);
    if (dev < 0) {
        printf("Cannot open mouse driver: %d\n", -dev);
        return 1;
    }

    /* Read and display the accumulated mouse movement a few times */
    for (i = 0; i < 20; i++) {
        size = sizeof(state);
        err = read(dev, &state, &size);
        if (err != ERR_SUCCESS) {
            printf("Failed to read mouse state: %d\n", err);
            break;
        }
        printf("dx=%d dy=%d buttons=%d\n",
               state.x_axis, state.y_axis, state.buttons.raw);
    }

    close(dev);
    return 0;
}
