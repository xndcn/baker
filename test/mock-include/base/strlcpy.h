#pragma once

// glibc 2.38 has including strlcpy
#if !defined(__GLIBC__) || (__GLIBC__ == 2 && __GLIBC_MINOR__ < 38)
#  include_next "base/strlcpy.h"
#endif
