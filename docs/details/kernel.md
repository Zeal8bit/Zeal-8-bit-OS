## Used registers

Z80 presents multiple general-purpose registers, not all of them are used in the kernel, here is the scope of each of them:

| Register           | Scope                          |
| ------------------ | ------------------------------ |
| AF, BC, DE, HL     | System & application           |
| AF', BC', DE', HL' | Interrupt handlers             |
| IX, IY             | Application (unused in the OS) |

This means that the OS won't alter IX and IY registers, so they can be used freely in the application.

The alternate registers (names followed by `'`) may only be used in the interrupt handlers[^1]. An application should not use these registers. If for some reason, you still have to use them, please consider disabling the interrupts during the time they are used:

```asm
my_routine:
                di              ; disable interrupt
                ex af, af'      ; exchange af with alternate af' registers
                [...]           ; use af'
                ex af, af'      ; exchange them back
                ei              ; re-enable interrupts
```

Keep in mind that disabling the interrupts for too long can be harmful as the system won't receive any signal from hardware (timers, keyboard, GPIOs...)

[^1]: They shall **not** be considered as non-volatile nonetheless. In other words, an interrupt handler shall not make the assumption that the data it wrote inside any alternate register will be kept until the next time it is called.

## Reset vectors

The Z80 provides 8 distinct reset vectors, as the system is meant to always be stored in the first virtual page of memory, these are all reserved for the OS:

| Vector | Usage                                                              |
| ------ | ------------------------------------------------------------------ |
| $00    | Software reset                                                     |
| $08    | Syscall                                                            |
| $10    | Jumps to the address in HL (can be used for calling HL)            |
| $18    | _Unused_                                                           |
| $20    | _Unused_                                                           |
| $28    | _Unused_                                                           |
| $30    | _Unused_                                                           |
| $38    | Reserved for Interrupt Mode 1, usable by the target implementation |
