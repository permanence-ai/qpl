/*******************************************************************************
 * Copyright (C) 2022 Intel Corporation
 *
 * SPDX-License-Identifier: MIT
 ******************************************************************************/

#include "qpl_hw_get_size.h"

/**
 * @date 3/23/2020
 * @brief @ref hw_get_job_size API implementation
 */

#include "own_defs.h"
#include "hardware_state.h"

QPL_FUN(uint32_t, hw_get_job_size, ()) {
    uint32_t size = 0U;

    size = QPL_ALIGNED_SIZE(sizeof(qpl_hw_state), QPL_DEFAULT_ALIGNMENT);

    return size;
}
