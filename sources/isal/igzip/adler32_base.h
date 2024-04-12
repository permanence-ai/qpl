/*******************************************************************************
 * Copyright (C) 2024 Intel Corporation
 *
 * SPDX-License-Identifier: MIT
 ******************************************************************************/

#ifndef ADLER32_BASE_H
#define ADLER32_BASE_H
#ifdef __cplusplus
extern "C" {
#endif
    uint32_t qpl_adler32_base(uint32_t adler32, uint8_t *start, uint32_t length);
#ifdef __cplusplus
} // extern "C"
#endif

#endif
