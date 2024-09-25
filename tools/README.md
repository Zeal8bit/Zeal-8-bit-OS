## Transferring Files to and from the Zeal 8-bit Computer: `xfer`

To simplify file transfers between Zeal 8-bit Computer and any other computer, the `xfer` script was created.

Its purpose is to implement a custom file transfer protocol over serial (UART) with the following objectives:

* Simple enough to be implemented in Z80 assembly
* Does not need the receiver to implement hardware timeout: the number of bytes to receive at each iteration is known in advance
* Sender provides the file name, limited to 16 characters
* Block size of 16KB
* Handshake after each packet sent/received
* Modular: the first packet sent can be extended to have more fields (CRC, modification date, etc...)

### Protocol details

#### File Metadata Transmission (Header Packet)

The sender starts by sending metadata in a header packet, which currently has a size of 24 bytes. The metadata packet contains:

* The packet type identifier: `0x1C` (1 byte)
* A 16-byte ASCII file name, padded with null characters (`\x00`) if it's shorter.
* The number of 16KB blocks to be transferred (1 byte).
* The size of the last block (2 bytes), which is the remainder when the file size is divided by 16KB.
* The total file size in bytes (4 bytes), included for verification and redundancy.

After sending this header packet, the sender waits for an acknowledgment (`ACK`) from the receiver before proceeding. The `ACK` byte is `0x06`.

#### File Data Transmission

After receiving `ACK`, the sender can proceed and start sending the file:

* The file is transmitted in 16KB chunks. After sending each chunk, the sender waits for an `ACK` from the receiver before sending the next chunk.
* After transmitting all 16KB blocks, the sender transmits the remaining bytes **if any**. The number of bytes sent here is the same as the `size of the last block` sent in the header packet.


### Implementation on Linux, Mac OS and Windows

This directory contains an implementation of this protocol in the Python script `xfer.py`. This script implementation both receive and send features.

#### Receive a file

To receive a file, execute the following command:

```
python3 xfer.py -r -d SERIAL [-b BAUDRATE]
```

Where `-d` is the serial node, such as `/dev/ttyUSB0` for example on Linux.

By default, the baudrate is 57600, but it is possible to override this value by using `-b` option.

#### Sending a file

To send a file, execute the following command:

```
python3 xfer.py -s -f filename -d SERIAL -b BAUDRATE
```

Similarly to the receive command, the serial node must be passed with `-d` and the default baudrate can be overridden with `-b`.

Please note that when sending a file, it is mandatory to pass the `-f` option with the path to the file to send.

### Implementation on Zeal 8-bit OS

On Zeal 8-bit OS, the protocol has been implemented as part of the `init.bin` program as the command `xfer`.

#### Receive a file

To receive a file, execute the following command:

```
xfer -r
```

The sender will provide the name of the file to save. It is possible to override this name by providing the output file name as a parameter:

```
xfer -r output
```

Where `output` is the new file's name.

#### Send a file

Not been implemented yet, but the command option is already reserved:

```
xfer -s filename
```

