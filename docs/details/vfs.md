As the communication between applications and hardware is all done through the syscalls described above, we need a layer between the user application and the kernel that will determine whether we need to call a driver or a file system. Before showing the hierarchy of such architecture, let's talk about disks and drivers.

## Architecture of the VFS

The different layers can be seen like this:

```mermaid
flowchart TD;
        app(User program)
        vfs(Virtual File System)
        dsk(Disk module)
        drv(Driver implementation: video, keyboard, serial, etc...)
        fs(File System)
        sysdis(Syscall dispatcher)
        hw(Hardware)
        time(Time & Date module)
        mem(Memory module)
        loader(Loader module)
        app -- syscall/rst 8 --> sysdis;
        sysdis --getdate/time--> time;
        sysdis --mount--> dsk;
        sysdis --> vfs;
        sysdis --map--> mem;
        sysdis -- exec/exit --> loader;
        vfs --> dsk & drv;
        dsk <--> fs;
        fs --> drv;
        drv --> hw;
```
