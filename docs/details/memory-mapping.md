## Kernel configured with MMU

Zeal 8-bit OS can separate kernel RAM and user programs thanks to virtual pages. Indeed, as it is currently implemented, the kernel is aware of 4 virtual pages of 16KB.

The first page, page 0, shall not be switched as it contains the kernel code. This means that the OS binary is limited to 16KB, it must never exceed this size. When a user's program is being executed, any `syscall` will result in jumping in the first bank where the OS code resides. So if this page is switched for another purpose, no syscall, no interrupt nor communication with the kernel must happen, else, undefined behavior will occur.

The second page, page 1, is where user programs are copied and executed. Thus, all the programs for Zeal 8-bit OS shall be linked from address `0x4000` (16KB). When loading a program, the second and third pages are also mapped to usable RAM from the user program. Thus, a user program can have a maximum size of 48KB.

The fourth page, page 3, is used to store the OS data for both the kernel and the drivers. When loading a user program, this page is switched to RAM, so that it's usable by the program, when a syscall occurs, it's switched back to the kernel RAM. Upon loading a user program, the SP (Stack Pointer) is set to `0xFFFF`. However, this may change in the near future.

To sum up, here is a diagram to show the usage of the memory:
<img src="../../md_images/mapping.svg" alt="Memory mapping diagram"/>

*If the user program's parameters are pointing to a portion of memory in page 3 (last page), there is a conflict as the kernel will always map its RAM page inside this exact same page during a syscall. Thus, it will remap user's page 3 into page 2 (third page) to access the program's parameters. Of course, in case the parameters are pointers, they will be modified to let them point to the new virtual address (in other words, a pointer will be subtracted by 16KB to let it point to page 2).

## Kernel configured as no-MMU

To be able to port Zeal 8-bit OS to Z80-based computers that don't have an MMU/Memory mapper organized as shown above, the kernel has a new mode that can be chosen through the `menuconfig`: no-MMU.

In this mode, the OS code is still expected to be mapped in the first 16KB of the memory, from `0x0000` to `0x3FFF` and the rest is expected to be RAM.

Ideally, 48KB of RAM should be mapped starting at `0x4000` and would go up to `0xFFFF`, but in practice, it is possible to configure the kernel to expect less than that. To do so, two entries in the `menuconfig` must be configured appropriately:

* `KERNEL_STACK_ADDR`: this marks the end of the kernel RAM area, and, as its name states, will be the bottom of the kernel stack.
* `KERNEL_RAM_START`: this marks the start address of the kernel RAM where the stack, all the variables used by the kernel AND drivers will be stored. Of course, it must be big enough to store all of these data. For information, the current kernel `BSS` section size is around 1KB. The stack depth depends on the target drivers' implementation. Allocating 1KB for the stack should be more than enough as long as no (big) buffers are stored on it. Overall allocating at least 3KB for the kernel RAM should be safe and future-proof.

To sum up, here is a diagram to show the usage of the memory:
<img src="../../md_images/mapping_nommu.svg" alt="Memory mapping diagram"/>

Regarding the user programs, the stack address will always be set to `KERNEL_RAM_START - 1` by the kernel before execution. It also corresponds to the address of its last byte available in its usable address space. This means that a program can determine the size of the available RAM by performing `SP - 0x4000`, which gives, in assembly:

```asm
ld hl, 0
add hl, sp
ld bc, -0x4000
add hl, bc
; HL contains the size of the available RAM for the program, which includes the program's code and its stack.
```
