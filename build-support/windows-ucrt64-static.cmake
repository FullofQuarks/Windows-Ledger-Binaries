include_guard(GLOBAL)

if(NOT MINGW)
    message(FATAL_ERROR
        "windows-ucrt64-static.cmake requires a MinGW build")
endif()
get_filename_component(
    UCRT_BIN_DIR
    "${CMAKE_CXX_COMPILER}"
    DIRECTORY
)

get_filename_component(
    UCRT_ROOT
    "${UCRT_BIN_DIR}"
    DIRECTORY
)

message(
    STATUS
    "Windows static build: UCRT64 prefix = ${UCRT_ROOT}"
)

get_filename_component(
    LEDGER_BUILD_SUPPORT_DIR
    "${CMAKE_CURRENT_LIST_FILE}"
    DIRECTORY
)

list(
    PREPEND
    CMAKE_MODULE_PATH
    "${LEDGER_BUILD_SUPPORT_DIR}/cmake"
)

list(
    PREPEND
    CMAKE_PREFIX_PATH
    "${UCRT_ROOT}"
)

# We only want to statically link here
set(
    CMAKE_FIND_LIBRARY_SUFFIXES
    ".a"
)

# sha512 expects endian definitions that aren't already defined
add_compile_definitions(
    LITTLE_ENDIAN=1234
    BYTE_ORDER=1234
)

# for static linking ICU
add_compile_definitions(
    U_STATIC_IMPLEMENTATION
)

list(
    APPEND
    CMAKE_REQUIRED_DEFINITIONS
    "-DU_STATIC_IMPLEMENTATION"
)

find_package(
    PkgConfig
    REQUIRED
)

# specify linking ordering
pkg_check_modules(
    LEDGER_STATIC_DEPS
    REQUIRED
    readline
    mpfr
    icu-i18n
    gpgme
)

add_compile_options(
    ${LEDGER_STATIC_DEPS_STATIC_CFLAGS_OTHER}
)

string(
    JOIN
    " "
    LEDGER_STATIC_LINK_TAIL
    ${LEDGER_STATIC_DEPS_STATIC_LDFLAGS}
)

set(
    CMAKE_CXX_STANDARD_LIBRARIES
    "${LEDGER_STATIC_LINK_TAIL} ${CMAKE_CXX_STANDARD_LIBRARIES}"
    CACHE STRING
    "C++ standard libraries plus Ledger static dependency closure"
    FORCE
)

message(
    STATUS
    "Static dependency tail: ${LEDGER_STATIC_LINK_TAIL}"
)
