/*******************************************************************************
 * Copyright (C) 2022 Intel Corporation
 *
 * SPDX-License-Identifier: MIT
 ******************************************************************************/

#include "hw_descriptor.h"

#include "hw_descriptors_api.h"
#include "own_analytic_descriptor.h"

#include "simple_memory_ops_c_bind.h"

HW_PATH_IAA_API(void, descriptor_reset, (hw_descriptor *const descriptor_ptr)) {
    call_c_set_zeros_uint8_t((uint8_t *) descriptor_ptr, sizeof(hw_descriptor));
}

HW_PATH_IAA_API(void, descriptor_set_completion_record, (hw_descriptor *const descriptor_ptr,
                                                         HW_PATH_VOLATILE hw_completion_record *const completion_record)) {
    const uint32_t FLAG_REQ_COMP   = 0x08U;
    const uint32_t FLAG_COMP_VALID = 0x04U;

    own_hw_analytic_descriptor *const this_ptr = (own_hw_analytic_descriptor *) descriptor_ptr;

    this_ptr->op_code_op_flags |= FLAG_REQ_COMP | FLAG_COMP_VALID;
    this_ptr->completion_record_ptr = (uint8_t *) completion_record;
}
