/* SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: CC0-1.0
 */

#include <stdio.h>

/**
 * Child program of the exec example, executed by `parent` through exec().
 *
 * Its exit code (42) is propagated back to the parent via exec()'s retval.
 */
int main(void) {
    printf("I am the child\n");
    return 42;
}
