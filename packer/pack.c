/*
 * SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdint.h>
#include <fcntl.h>
#include <endian.h>
#include <unistd.h>
#include <libgen.h>
#include <string.h>
#include <time.h>

#define CHECK_ERR(ret) do { if ((ret) < 0) { perror("Error "); return 3; } } while(0)

typedef struct {
    char name[16];
    uint32_t size;
    uint32_t offset;
    uint8_t  year[2];
    uint8_t  month;
    uint8_t  day;
    uint8_t  date;
    uint8_t  hours;
    uint8_t  minutes;
    uint8_t  seconds;
} __attribute__((packed)) entry_t;

_Static_assert(sizeof(entry_t) == 32, "Structure size must be 32");

/* Buffer used for reading all the files */
static uint8_t buffer[1024];

/**
 * Convert a value between 0 and 99 into a BCD values
 */
static uint8_t toBCD(int value) {
    return (((value / 10) % 10) << 4) | (value % 10);
}

/**
 * Function to copy a file `in` into a file `out`.
 * Both are opened file descriptors.
 */
static void copyToOut(int out, int in) {
    int rd = 0;
    for (;;) {
        rd = read(in, buffer, sizeof(buffer));
        if (rd < 0) {
            perror("Couldn't read file");
        } else if (rd == 0){
            break;
        }
        write(out, buffer, rd);
    }
}

/* Only compatible with little-endian CPU at the moment */
int main(int argc, char* argv[]) {
    struct stat statbuf = { 0 };

    if (argc < 3) {
        printf("usage: %s <output> <input1> <input2> ...\n", argv[0]);
        return 1;
    }

    /* Create output file */
    const char* outfile = argv[1];
    int out = open(outfile, O_CREAT | O_WRONLY, 0644);
    if (out < 0) {
        perror("Cannot create output file");
        return 2;
    }
    
    /* Write the number of entries/files already */
    const uint16_t count = argc - 2;
    CHECK_ERR(write(out, &count, sizeof(count)));
    /* Start the offset at the end of the entries table */
    uint32_t offset = 2 + sizeof(entry_t) * count;

    /* Get info about each file */
    for (int i = 2; i < argc; i++) {
        entry_t entry = { 0 };
        char* filename = argv[i];
        CHECK_ERR(stat(filename, &statbuf));
        /* Copy the filename (basename) and truncate it to fit inside 16 byte */
        strncpy(entry.name, basename(filename), sizeof(entry.name));
        entry.size = (uint32_t) statbuf.st_size;
        entry.offset = offset;
        time_t lastmod = statbuf.st_mtime;
        struct tm* timest = localtime(&lastmod);
        /* Got the time, populate it in the structure */
        entry.year[0] = toBCD((1900 + timest->tm_year) / 100);   /* 20 first */
        entry.year[1] = toBCD(timest->tm_year);         /* 22 then */
        entry.month = toBCD(timest->tm_mon + 1);
        entry.day = toBCD(timest->tm_mday);
        entry.date = toBCD(timest->tm_wday);
        entry.hours = toBCD(timest->tm_hour);
        entry.minutes = toBCD(timest->tm_min);
        entry.seconds = toBCD(timest->tm_sec);
        /* Write this structure to the output file */
        CHECK_ERR(write(out, &entry, sizeof(entry)));
        /* Increment for the next entry */
        offset += entry.size;
    }

    /* Open each file and copy it to out file */
    for (int i = 2; i < argc; i++) {
        char* filename = argv[i];
        int f = open(filename, O_RDONLY);
        CHECK_ERR(f);
        copyToOut(out, f);
        close(f);
    }

    close(out);

    return 0;
}