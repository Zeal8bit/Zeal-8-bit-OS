## Syscall numbers
| Number | Name                  |
| ------ | --------------------- |
| 0      | [`read`](#read)       |
| 1      | [`write`](#write)     |
| 2      | [`open`](#open)       |
| 3      | [`close`](#close)     |
| 4      | [`dstat`](#dstat)     |
| 5      | [`stat`](#stat)       |
| 6      | [`seek`](#seek)       |
| 7      | [`ioctl`](#ioctl)     |
| 8      | [`mkdir`](#mkdir)     |
| 9      | [`chdir`](#chdir)     |
| 10     | [`curdir`](#curdir)   |
| 11     | [`opendir`](#opendir) |
| 12     | [`readdir`](#readdir) |
| 13     | [`rm`](#rm)           |
| 14     | [`mount`](#mount)     |
| 15     | [`exit`](#exit)       |
| 16     | [`exec`](#exec)       |
| 17     | [`dup`](#dup)         |
| 18     | [`msleep`](#msleep)   |
| 19     | [`settime`](#settime) |
| 20     | [`gettime`](#gettime) |
| 21     | [`setdate`](#setdate) |
| 22     | [`getdate`](#getdate) |
| 23     | [`map`](#map)         |
| 24     | [`swap`](#swap)       |

## `read`
Read a given descriptor.

Clobbers `A`, `BC`

### Parameters
- `H` - The descriptor to read from
- `DE` - The buffer to read into
- `BC` - The number of bytes to read

### Returns
- `A` - 0 if successful, otherwise an error code
- `BC` - The number of bytes read

## `write`
Write to a given descriptor.

Clobbers `A`, `HL`, `BC`

### Parameters
- `H` - The descriptor to write to
- `DE` - The buffer to write from
- `BC` - The number of bytes to write

### Returns
- `A` - 0 if successful, otherwise an error code
- `BC` - The number of bytes written

## `open`
Open a file or driver

Driver names shall not exceed 4 characters and must be preceeded by `VFS_DRIVER_INDICATOR` (`#`) (5 characters total). Names not starting with `#` are considered file names.

Clobbers `A`

### Parameters
- `BC` - The name of the file or driver
- `H` - Flags. Can be `O_RDWR`, `O_RDONLY`, `O_WRONLY`, `O_NONBLOCK`, `O_CREAT`, `O_APPEND`, etc.

### Returns
- `A` - The descriptor if successful, otherwise a negated error code

## `close`
Close a descriptor

This should be done as soon as a dev is not required anymore, else, this could prevent any other `open` to succeed.

!!! note
    When a program terminates, all its opened devs are closed and `STDIN`/`STDOUT` are reset.

Clobbers `A`, `HL`

### Parameters
- `H` - The descriptor to close

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code

## `dstat`
Get the stats of a given descriptor

### Parameters
- `H` - The descriptor to get the stats of
- `DE` - File info structure to write to

### Returns
- `A` - 0 if successful. <!-- "error else"? -->

## `stat`
Get the stats of a given file.

### Parameters
- `BC` - The path to the file
- `DE` - File info structure to write to

### Returns
- `A` - 0 if successful. <!-- "error else"? -->

## `seek`
Move the cursor of a given file or driver descriptor. In case of a driver, behavior depends on the driver. In case of a file, the cursor is moved relatively to the `whence` parameter.

If the given whence is `SEEK_SET`, and the given offset is larger than the file size, the cursor is moved to the end of the file. Similarly, if the given whence is `SEEK_END`, and the given offset is positive, the cursor is moved to the end of the file.

### Parameters
- `H` - The descriptor to seek.
- `BCDE` - The 32-bit offset to seek to. Signed if `whence` is `SEEK_CUR` or `SEEK_END`, unsigned if `whence` is `SEEK_SET`.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.
- `BCDE` - The new cursor position, unsigned.

## `ioctl`
Perform an I/O control operation on a given descriptor. The behavior of this syscall depends on the driver.

### Parameters
- `H` - The descriptor to perform the operation on. Must be a driver and not a file.
- `C` - The command to perform.
- `DE` - 16-bit parameter to pass to the driver.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.
- `DE` - Driver-specific return value.

## `mkdir`
Create a directory. If any of the directories in the path do not exist, this will fail.

Clobbers `A`, `HL`

### Parameters
- `DE` - The path to the directory to create.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.

## `chdir`
Change the current working directory.

Clobbers `A`, `HL`

### Parameters
- `DE` - The path to the directory to change to.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.

## `curdir`
Get the current working directory.

Clobbers `A`

### Parameters
- `DE` - Buffer to write the current working directory to. Must be at least `CONFIG_KERNEL_PATH_MAX` bytes long.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.

## `opendir`
Open a directory. The path can be relative to the current working directory, absolute to the current disk, or absolute to the system (includes disk letter).

Clobbers `A`, potentially `HL`

### Parameters
- `DE` - The path to the directory to open.

### Returns
- `A` - The descriptor if successful, otherwise a negated error code.

## `readdir`
Read the next entry in an opened directory.

Clobbers `A`

### Parameters
- `H` - The descriptor to read from.
- `DE` - Buffer to write the entry to. Must not cross page boundaries, and must be at least the size of an `opendir` entry.

### Returns
- `A` - `ERR_SUCCESS` if successful, `ERR_NO_MORE_ENTRIES` if there are no more entries, otherwise an error code.

## `rm`
Remove a file or an empty directory.

Clobbers `A`, `HL`

### Parameters
- `DE` - The path to the file or directory to remove.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.

## `mount`
Mount a disk to a given driver, letter, and filesystem.

### Parameters
- `H` - The driver descriptor to mount the disk to.
- `D` - The ASCII letter to assign to the disk, can be upper or lower case.
- `E` - The filesystem to use, as defined in `vfs_h.asm`.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.

## `exit`
Exit the current process and load back `init.bin`.

### Parameters
- `H` - The exit code.

### Returns
- `D` - The exit code, for the parent process.

## `exec`
Load ane execute a program from a file. The program will run in place of the current one.

### Parameters
- `BC` - The path to the program to execute.
- `DE` - String parameter. Can be null.
- `H` - Whether to save the current process or not. If 0, the current process will be replaced by the new one. If 1, the current process will be saved and the new one will run in place of it.

### Returns
- `A` - Nothing on success, `ERR_FAILURE` on failure.

## `dup`
Duplicate a descriptor. This is handy for overridding `STDIN`/`STDOUT`.

!!! note
    The new descriptor must be empty or closed before calling this syscall.

### Parameters
- `H` - The descriptor to duplicate.
- `E` - The new descriptor.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.

## `msleep`
Sleep for a given duration, in milliseconds.

Clobbers `A`, `HL`

### Parameters
- `DE` - The duration to sleep for, in milliseconds (max 65 seconds).

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.

## `settime`
Set/reset the time counter, in milliseconds.

Clobbers `A`, `HL`

### Parameters
- `H` - The ID of the clock to set/reset. Currently unused.
- `DE` - The `time_millis_t` to set the counter to. This currently contains the value used directly, but may be changed to a pointer in the future.

### Returns
- `A` - `ERR_SUCCESS` if successful, `ERR_NOT_IMPLEMENTED` if the target time counter doesn't implement this syscall, otherwise an error code.

## `gettime`
Get the current value of a time counter, in milliseconds. The granularity of this counter is dependent on the implementation and could be 1ms, 16ms, or more.

Clobbers `A`, `HL`

### Parameters
- `H` - The ID of the clock to get the value of. Currently unused.

### Returns
- `A` - `ERR_SUCCESS` if successful, `ERR_NOT_IMPLEMENTED` if the target time counter doesn't implement this syscall, otherwise an error code.
- `DE` - The current `time_millis_t` value of the counter.

## `setdate`
Set the current system date.

Clobbers `A`

### Parameters
- `DE` - Pointer to the date structure as defined in `time_h.asm`. Must not be null.

### Returns
- `A` - `ERR_SUCCESS` if successful, `ERR_NOT_IMPLEMENTED` if the target date counter doesn't implement this syscall, otherwise an error code.

## `getdate`
Get the current system date.

Clobbers `A`

### Parameters
- `DE` - Pointer to the date structure as defined in `time_h.asm`. Must not be null.

### Returns
- `A` - `ERR_SUCCESS` if successful, `ERR_NOT_IMPLEMENTED` if the target date counter doesn't implement this syscall, otherwise an error code.

## `map`
Map a physical address to a virtual one.

### Prerequisites
- `[SP]` - A backup of HL.

### Parameters
- `DE` - The virtual address to map to. This will be rounded down to the nearest page boundary.
- `HBC` - The physical address to map. This will be rounded down to the nearest page boundary.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.

## `swap`
Swap two descriptors. This is handy for overridding `STDIN`/`STDOUT` temporarily.

!!! note
    The new descriptors must not be empty or closed before calling this syscall.

### Parameters
- `H` - The first descriptor to swap.
- `E` - The second descriptor to swap.

### Returns
- `A` - `ERR_SUCCESS` if successful, otherwise an error code.
