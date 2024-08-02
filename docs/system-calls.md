## Syscall numbers
| Number | Name    |
| ------ | ------- |
| 0      | `read`  |
| 1      | `write` |
| 2      | `open`  |
| 3      | `close` |

## `read`
Read a given descriptor

Clobbers `A`, `BC`

### Parameters
- `H` - The descriptor to read from
- `DE` - The buffer to read into
- `BC` - The number of bytes to read

### Returns
- `A` - 0 if successful, otherwise an error code
- `BC` - The number of bytes read

## `write`
Write to a given descriptor

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
