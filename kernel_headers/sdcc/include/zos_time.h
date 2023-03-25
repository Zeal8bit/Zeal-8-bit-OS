/* SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <stdint.h>

/**
 * Define the calling convention for all the routines
 */
#if __SDCC_VERSION_MAJOR >= 4 && __SDCC_VERSION_MINOR >= 2
    #define CALL_CONV __sdcccall(1)
#else
    #error "Unsupported calling convention. Please upgrade your SDCC version."
#endif


/**
 * @brief Structure representing a time.
 */
typedef struct {
    uint16_t t_millis;
} zos_time_t;


/**
 * @brief Structure representing a date.
 *
 * @note All the values are expressed in BCD format.
 */
typedef struct {
    uint8_t d_year_h;  // High part of years (hundreds)
    uint8_t d_year_l;  // Low part of years
    uint8_t d_month;
    uint8_t d_day;
    uint8_t d_date; // Range [1,7] (Sunday, Monday, Tuesday...)
    uint8_t d_hours;
    uint8_t d_minutes;
    uint8_t d_seconds;
} zos_date_t;


/**
 * @brief Sleep for a specified duration.
 *
 * @param duration Number os milliseconds to sleep for.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t msleep(uint16_t duration) CALL_CONV;


/**
 * @brief Manually set/reset the time counter, in milliseconds.
 *
 * @param id ID of the clock (**not implemented yet**)
 * @param time Pointer to the structure containing the time to set.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t settime(uint8_t id, zos_time_t* time) CALL_CONV;


/**
 * @brief Get the time counter, in milliseconds.
 *
 * @param id ID of the clock (**not implemented yet**)
 * @param time Pointer to the time structure to fill.
 *
 * @returns ERR_SUCCESS on success, error code else.
 */
zos_err_t gettime(uint8_t id, zos_time_t* time) CALL_CONV;


/**
 * @brief Set the system date, on computers where RTC is available.
 *
 * @param date Pointer to the date structure to set.
 *
 * @returns ERR_SUCCESS on success, ERR_NOT_IMPLEMENTED if target doesn't
 *          implement this feature error code else.
 */
zos_err_t setdate(const zos_date_t* date) CALL_CONV;


/**
 * @brief Get the system date, on computers where RTC is available.
 *
 * @param date Pointer to the date structure to fill with the system date.
 *
 * @returns ERR_SUCCESS on success, ERR_NOT_IMPLEMENTED if target doesn't
 *          implement this feature error code else.
 */
zos_err_t getdate(zos_date_t* date) CALL_CONV;
