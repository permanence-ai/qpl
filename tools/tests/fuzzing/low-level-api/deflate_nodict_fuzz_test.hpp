/*******************************************************************************
 * Copyright (C) 2022 Intel Corporation
 *
 * SPDX-License-Identifier: MIT
 ******************************************************************************/

#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "qpl/qpl.h"

struct deflate_properties {
    size_t destination_size;
};

static inline int deflate_nodict_fuzz(const uint8_t* Data, size_t Size, uint32_t compression_mode,
                                      qpl_compression_levels compression_level) {
    const uint8_t* source_data_ptr  = Data;
    size_t         source_size      = Size;
    size_t         destination_size = Size;

    if (0 == Size) { return 0; }
    if (Size > sizeof(deflate_properties)) {
        deflate_properties* properties = (deflate_properties*)Data;
        source_data_ptr += sizeof(deflate_properties);
        source_size -= sizeof(deflate_properties);
        destination_size = properties->destination_size;
        if (0 == destination_size) { destination_size = 1; }
        destination_size %= (source_size + source_size);
        if (0 == destination_size) { destination_size = source_size + source_size; }
    }

    std::vector<uint8_t> source(source_data_ptr, source_data_ptr + source_size);
    std::vector<uint8_t> destination(destination_size, 0xaa);

    {
        // Get size of the job
        uint32_t job_size = 0;

        qpl_status status = qpl_get_job_size(qpl_path_software, &job_size);
        if (status != QPL_STS_OK) { return 0; }

        // Initialize the job
        auto job_buffer = std::make_unique<uint8_t[]>(job_size);
        auto job_ptr    = reinterpret_cast<qpl_job*>(job_buffer.get());

        status = qpl_init_job(qpl_path_software, job_ptr);
        if (status != QPL_STS_OK) { return 0; }

        job_ptr->next_in_ptr   = source.data();
        job_ptr->available_in  = source.size();
        job_ptr->next_out_ptr  = destination.data();
        job_ptr->available_out = static_cast<uint32_t>(destination.size());
        job_ptr->total_out     = 0;

        job_ptr->op    = qpl_op_compress;
        job_ptr->level = compression_level;
        job_ptr->flags = compression_mode | QPL_FLAG_FIRST | QPL_FLAG_LAST | QPL_FLAG_OMIT_VERIFY;

        status = qpl_execute_job(job_ptr);
    }

    return 0;
}
