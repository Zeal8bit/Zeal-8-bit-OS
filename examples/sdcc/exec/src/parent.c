/* SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: CC0-1.0
 */

#include <stdio.h>
#include <stdint.h>

#include "zos_errors.h"
#include "zos_sys.h"

/* Parent program of the exec example: it runs the `child` program with
 * EXEC_PRESERVE_PROGRAM, so it stays in memory and resumes once child exits.
 * The child binary is loaded from the host filesystem (H:), which the test
 * roots on the directory holding the built binaries, hence "H:/child.bin". */
int main(void) {
    uint8_t retval = 0;

    printf("I am the parent\n");

    /* Run the child, keeping this program in memory (EXEC_PRESERVE_PROGRAM).
     * argv can be NULL here, it is only passed to show the calling convention. */
    const char* argv[] = { NULL };
    zos_err_t err = exec(EXEC_PRESERVE_PROGRAM, "H:/child.bin", argv, &retval);
    if (err != ERR_SUCCESS) {
        printf("exec error: %d\n", err);
        return 1;
    }

    printf("Child returned: %u\n", retval);
    printf("I am still the parent\n");
    return 0;
}
