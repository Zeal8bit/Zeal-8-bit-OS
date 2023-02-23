/* SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: CC0-1.0
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "zos_errors.h"
#include "zos_vfs.h"
#include "zos_sys.h"

/* Forward declaration of print_string defined in `str.c` */
zos_err_t print_string(const char* s);

/**
 * This example will list all the files and directories in the current directory.
 * print_string is not from a library, it is defined in `str.c`.
 */
void main(void) {
    zos_dir_entry_t entry;
    zos_err_t ret;

    /* Open the current directory */
    zos_dev_t dev = opendir(".");

    /* Check if it was a success, abort else */
    if (dev < 0) {
        goto error;
    }

    /* Iterate over the opened directory while reading each entry */
    for (;;) {
        ret = readdir(dev, &entry);

        /* If we've browsed all the entries, we can break the loop */
        if (ret == ERR_NO_MORE_ENTRIES) {
            break;
        } else if (ret != ERR_SUCCESS) {
            goto error;
        }

        /* Success, the structure has been filled, we can read the name and print it,
         * with a final / in case of a directory.
         * Let's use stdio's printf this time! */
        printf("%s%c\n", entry.d_name, D_ISDIR(entry.d_flags) ? '/' : '\0');
    }

    print_string("Program finished\n");

    /* Close the opened directory */
    close(dev);
    return;
error:
    print_string("An error occurred\n");
}
