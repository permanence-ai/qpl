/*******************************************************************************
 * Copyright (C) 2024 Intel Corporation
 *
 * SPDX-License-Identifier: MIT
 ******************************************************************************/

#ifndef IGZIP_INFLATE_H
#define IGZIP_INFLATE_H

// includes extracted from /home/permai/workspace/qpl-working/sources/isal/igzip/igzip_inflate.c
#include <stdint.h>
#include "igzip_lib.h"
#include "crc.h"
#include "huff_codes.h"
#include "igzip_checksums.h"
#include "igzip_wrapper.h"
#include "unaligned.h"
#ifndef NO_STATIC_INFLATE_H
#include "static_inflate.h"
#endif
#ifdef __FreeBSD__
#include <sys/types.h>
#include <sys/endian.h>
# define bswap_32(x) bswap32(x)
#elif defined (__APPLE__)
#include <libkern/OSByteOrder.h>
# define bswap_32(x) OSSwapInt32(x)
#elif defined (__GNUC__) && !defined (__MINGW32__)
# include <byteswap.h>
#elif defined _WIN64
# define bswap_32(x) _byteswap_ulong(x)
#endif


#endif
