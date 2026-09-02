/* SPDX-FileCopyrightText: 2023-2026 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: CC0-1.0
 */

#include <stdio.h>
#include <stdint.h>
#include "zos_errors.h"
#include "zos_vfs.h"
#include "zos_sys.h"

/**
 * List all the files and directories of the host filesystem disk (H:).
 * The emulator roots H: on a host directory (see pytest_dir_listing.py), so
 * the test can check that the expected entries are listed.
 * print_string is not from a library, it is defined in `str.c`.
 */
int main(void) {
    zos_dir_entry_t entry;
    zos_err_t ret;

    /* Open the current directory */
    zos_dev_t dev = opendir("h:/");

    /* Check if it was a success, abort else */
    if (dev < 0) {
        ret = -dev;
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
         * with a final / in case of a directory */
        printf("%s%c\n", entry.d_name, D_ISDIR(entry.d_flags) ? '/' : ' ');
    }

    puts("Program finished");

    /* Close the opened directory */
    close(dev);
    return 0;

error:
    printf("error %d occurred\n", ret);
    return 1;
}
