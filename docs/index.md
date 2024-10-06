<p align="center">
    <img src="md_images/zeal8bitos.png" alt="Zeal 8-bit OS logo" />
</p>
<p align="center">
    <a href="https://opensource.org/licenses/Apache-2.0">
        <img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="Licence" />
    </a>
    <p align="center">A simple and portable Operating System for Z80-based computers, written entirely in Z80 assembly.</p>
    <p align="center"><a href="https://www.youtube.com/watch?v=5jTcWRN8IbA">Click here to have a look at the video presentation of the project on Youtube</a></p>
</p>

## What?

Zeal 8-bit OS is an operating system written entirely in Z80 assembly for Z80 computers. It has been designed around simplicity and portability. It is inspired by Linux and CP/M. It has the concept of drivers and disks while being ROM-able.

## Why?

As you may know, this project is in fact part of a bigger project called *Zeal 8-bit Computer*, which, as its name states, consists of an entirely newly designed 8-bit computer. It is based on a Z80 CPU.

When writing software, demos or drivers for it, I realized the code was tied to *Zeal 8-bit computer* hardware implementation, making them highly incompatible with any other Z80 computers, even if the required features were basic (only UART for example).

## Yet another OS?

Well, it's true that there are several (good) OS for the Z80 already such as SymbOS, Fuzix or even CP/M, but I wanted something less sophisticated:
not multithreaded, ROM-able, modular and configurable.
The goal is to have a small and concise ABI that lets us write software that can communicate with the hardware easily and with the least hardcoded behaviors.

While browsing the implementation details or this documentation, you will notice that some aspects are similar to Linux kernel, such as the syscall names or the way opened files and drivers are handled. Indeed, it was a great source of inspiration, but as it is a 32-bit only system, written in C, only the APIs/interfaces have been inspiring.

If you are familiar with Linux ABI/interface/system programming, then Zeal 8-bit OS will sound familiar!

## Overview

Currently, once compiled, the kernel itself takes less than 8KB of ROM (code), and less than 1KB of RAM (data).
Of course, this is highly dependent on the configuration. For example, increasing the maximum number of opened files, or the maximum length of paths will increase the size of the space used for data.

This size will increase as soon as more features will be implemented, for example when there will be more file systems. However, keep in mind that while writing the code, speed was more important than code size. In fact, nowadays, read-only memories are available in huge sizes and at a fair price.

Moreover, the OS can still be optimized in both speed and size. This is not the current priority but it means that we can still make it better! (as always)

To the kernel size, we have to add the drivers implementation size and the RAM used by them. Of course, this is highly dependent on the target machine itself, the features that are implemented and the amount of drivers we have.

The OS is designed to work with an MMU, thus, the target must have 4 swappable virtual pages of 16KB each. The pages must be interchangeable. More info about it in the [Memory Mapping](details/memory-mapping.md) section.
