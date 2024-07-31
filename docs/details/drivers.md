A driver consists of a structure containing:

* Name of the driver, maximum 4 characters (filled with NULL char if shorter). For example, `SER0`, `SER1`, `I2C0`, etc. Non-ASCII characters are allowed but not advised.
* The address of an `init` routine, called when the kernel boots.
* The address of `read` routine, where parameters and return address are the same as in the syscall table.
* The address of `write` routine, same as above.
* The address of `open` routine, same as above.
* The address of `close` routine, same as above.
* The address of `seek` routine, same as above.
* The address of `ioctl` routine, same as above.
* The address of `deinit` routine, called when unloading the driver.

Here is the example of a simple driver registration:
```asm
my_driver0_init:
        ; Register itself to the VFS
        ; Do something
        xor a ; Success
        ret
my_driver0_read:
        ; Do something
        ret
my_driver0_write:
        ; Do something
        ret
my_driver0_open:
        ; Do something
        ret
my_driver0_close:
        ; Do something
        ret
my_driver0_seek:
        ; Do something
        ret
my_driver0_ioctl:
        ; Do something
        ret
my_driver0_deinit:
        ; Do something
        ret

SECTION DRV_VECTORS
DEFB "DRV0"
DEFW my_driver0_init
DEFW my_driver0_read
DEFW my_driver0_write
DEFW my_driver0_open
DEFW my_driver0_close
DEFW my_driver0_seek
DEFW my_driver0_ioctl
DEFW my_driver0_deinit
```

Registering a driver consists in putting this information (structure) inside a section called `DRV_VECTORS`. The order is very important as any driver dependency shall be resolved at compile-time. For example, if driver `A` depends on driver `B`, then `B`'s structure must be put before `A` in the section `DRV_VECTORS`.

At boot, the `driver` component will browse the whole `DRV_VECTORS` section and initialize the drivers one by one by calling their `init` routine. If this routine returns `ERR_SUCCESS`, the driver will be registered and user programs can open it, read, write, ioctl, etc...

A driver can be hidden to the programs, this is handy for disk drivers that must only be accessed by the kernel's file system layer. To do so, the `init` routine should return `ERR_DRIVER_HIDDEN`.
