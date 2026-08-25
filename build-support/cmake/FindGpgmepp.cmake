include(
    FindPackageHandleStandardArgs
)

find_package(
    PkgConfig
    REQUIRED
)

#
# GPGME and GPGME++ are distributed together. Use the gpgme pkg-config
# metadata to obtain the installed version and search hints.
#
pkg_check_modules(
    PC_GPGME
    QUIET
    gpgme
)

find_path(
    Gpgmepp_INCLUDE_DIR
    NAMES
        gpgme++/context.h
    HINTS
        ${PC_GPGME_INCLUDE_DIRS}
)

# getlibgpgmepp.a not libgpgmepp.dll.a
find_library(
    Gpgmepp_LIBRARY
    NAMES
        gpgmepp
    HINTS
        ${PC_GPGME_LIBRARY_DIRS}
)

set(
    Gpgmepp_VERSION
    "${PC_GPGME_VERSION}"
)

find_package_handle_standard_args(
    Gpgmepp
    REQUIRED_VARS
        Gpgmepp_LIBRARY
        Gpgmepp_INCLUDE_DIR
    VERSION_VAR
        Gpgmepp_VERSION
)

if(Gpgmepp_FOUND)
    if(Gpgmepp_LIBRARY MATCHES "\\.dll\\.a$")
        message(
            FATAL_ERROR
            "Gpgmepp resolved to a DLL import library: ${Gpgmepp_LIBRARY}"
        )
    endif()

    if(NOT TARGET Gpgmepp)

        add_library(
            Gpgmepp
            STATIC
            IMPORTED
        )

        set_target_properties(
            Gpgmepp
            PROPERTIES
                IMPORTED_LOCATION
                    "${Gpgmepp_LIBRARY}"

                INTERFACE_INCLUDE_DIRECTORIES
                    "${Gpgmepp_INCLUDE_DIR};${Gpgmepp_INCLUDE_DIR}/gpgme++"

                INTERFACE_COMPILE_DEFINITIONS
                    "GPGMEPP_STATIC_DEFINE"
        )

    endif()

endif()

set(
    Gpgmepp_INCLUDE_DIRS
    "${Gpgmepp_INCLUDE_DIR};${Gpgmepp_INCLUDE_DIR}/gpgme++"
)

get_filename_component(
    Gpgmepp_LIBRARY_DIRS
    "${Gpgmepp_LIBRARY}"
    DIRECTORY
)

mark_as_advanced(
    Gpgmepp_INCLUDE_DIR
    Gpgmepp_LIBRARY
)
