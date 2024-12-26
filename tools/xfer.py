#!/usr/bin/env python3

#
# SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
#
# SPDX-License-Identifier: Apache-2.0

import argparse
import serial
import sys
import struct
import os
import time

DEFAULT_BAUDRATE = 57600
PACKET_SIZE      = 24
METADATA_PACKET  = 0x1C
ACK_BYTE         = b'\x06'
BLOCK_SIZE       = 16*1024

def receive_ack(ser):
    # Wait for ACK from the device, if it refuses the transaction, we have to exit
    ack = ser.read(1)  # Wait for 1 byte
    if ack != ACK_BYTE:  # ACK is ASCII character 0x06
        print(f"Error: Device doesn't respond or refused the transaction ({ack})")
        sys.exit(1)
    # Give some time to the device
    time.sleep(0.005)   # 5ms


def xfer_send():
    # Let's have a timeout of around one second
    ser = serial.Serial(args.ttynode, args.baudrate, timeout=args.baudrate)

    print(f"Sending file {args.file} to {args.ttynode}...")

    # Get the file name and size
    file_name = os.path.basename(args.file)
    # Truncate the file name to 16 characters if too long
    if len(file_name) > 16:
        print(f"Warning: File name '{file_name}' is too long, truncating to 16 characters.")
        file_name = file_name[:16]

    # Calculate file size in terms of 16KB blocks and remainder
    file_size = os.path.getsize(args.file)
    num_blocks = file_size // BLOCK_SIZE
    remainder = file_size % BLOCK_SIZE

    if args.verbose:
        print("Sending header packet")

    # Create the first packet packet that contains metadata
    packet = bytearray()
    packet.append(METADATA_PACKET)
    # 16-byte file name
    packet.extend(file_name.encode('ascii').ljust(16, b'\x00'))
    # 8-bit number of 16KB blocks
    packet.append(num_blocks)
    # 16-bit remainder
    packet.extend(struct.pack('<H', remainder))
    # 32-bit file size
    packet.extend(struct.pack('<I', file_size))

    # Send the packet
    ser.write(packet)

    if args.verbose:
        print("Waiting for ACK from the receiver")

    receive_ack(ser)

    if args.verbose:
        print("ACK received!")

    # Create the destination file
    with open(args.file, "rb") as file:
        # Send the file in 16KB chunks
        chunk_num = 0
        while True:
            chunk = file.read(BLOCK_SIZE)
            if not chunk:
                break  # End of file

            if args.verbose:
                print(f"Sending chunk {chunk_num}...", end="", flush=True)

            # Send the chunk
            ser.write(chunk)
            chunk_num += 1

            # Wait for the reply from the target
            receive_ack(ser)

            # Print the chunk number if verbose is set
            if args.verbose:
                print(f"success")

    print(f"{file_name} was sent successfully!")
    return 0


def xfer_receive():
    # Blocking reads here, no timeout
    ser = serial.Serial(args.ttynode, args.baudrate)

    print(f"Receiving file from {args.ttynode}...")

    packet = ser.read(PACKET_SIZE)
    if not packet:
        print("Error: No data received.")
        sys.exit(1)

    # Check if it matches the expected metadata packet type
    if packet[0] != METADATA_PACKET:
        print(f"Error: Expected metadata packet but received {packet[0]}.")
        sys.exit(1)

    # Read the next 16 bytes for the file name
    file_name_bytes = packet[1:17]
    file_name = file_name_bytes.decode('ascii').rstrip('\x00')
    print(f"Received file name: {file_name}")

    # If file is provided, override the file name received from the device
    if args.file:
        file_name = args.file
        print(f"Overriding filename to {file_name}")

    # Read the number of 16KB blocks (1 byte)
    num_blocks = packet[17]
    print(f"Number of 16KB blocks: {num_blocks}")

    # Read the 16-bit remainder (2 bytes)
    remainder = struct.unpack('<H', packet[18:20])[0]
    print(f"Remainder: {remainder} bytes")

    # Read the 32-bit file size (4 bytes)
    file_size = struct.unpack('<I', packet[20:24])[0]
    print(f"File size: {file_size} bytes")

    # Create the destination file
    with open(file_name, "wb") as file:
        # Notify the device we are ready
        ser.write(ACK_BYTE)
        total_bytes_received = 0

        # Read the file in 16KB chunks
        for block_num in range(num_blocks):
            print(f"Receiving block {block_num + 1} of {num_blocks}...")
            chunk = ser.read(BLOCK_SIZE)

            # Write the received chunk to the output file
            file.write(chunk)
            total_bytes_received += len(chunk)

            # Acknowledge receipt of the chunk (optional)
            ser.write(ACK_BYTE)

        if remainder > 0:
            print(f"Receiving last block of {remainder} bytes...")
            chunk = ser.read(remainder)  # Read the remaining bytes
            file.write(chunk)
            total_bytes_received += len(chunk)

        print(f"Total bytes received: {total_bytes_received} of {file_size} bytes")


if __name__ == "__main__":
    global args
    # Define the parameters for the program
    parser = argparse.ArgumentParser(
                    prog='xfer.py',
                    description='Send or receive a file to and from Zeal 8-bit Computer'
                )
    # We are either sending or receiving
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('-r', '--receive', dest='receive', action='store_true', help="Receive a file")
    group.add_argument('-s', '--send', dest='send', action='store_true', help="Send a file")

    parser.add_argument('-f', '--file', dest='file', help='Input or output file name. Only required when sending a file', required=False)
    parser.add_argument('-d', '--device', dest='ttynode', help='UART device node, e.g. /dev/ttyUSB0', required=True)
    parser.add_argument('-v', '--verbose', dest='verbose', help='Enable verbose mode', required=False, action='store_true')
    parser.add_argument('-b', '--baudrate', dest='baudrate', type=int, help='Baudrate to use with the serial node', default=DEFAULT_BAUDRATE, required=False)
    args = parser.parse_args()

    if args.verbose:
        print("Connecting to " + args.ttynode + " with baudrate " + str(args.baudrate))

    if args.receive:
        xfer_receive()
    else:
        xfer_send()
