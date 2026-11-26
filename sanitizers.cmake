# add_sanitized_build_type(
#     [NAME <build-type-name>]
#     [SANITIZERS <names...>]
#     [OPTIMIZATION <level>]
#     [RECOVER]
# )
#   NAME         the build type's name (default: Sanitized)
#   SANITIZERS   the -fsanitize= names to combine, e.g. address, undefined,
#                thread, memory, leak (default: address;undefined -- not
#                every combination is linkable together, e.g. thread and
#                address)
#   OPTIMIZATION the -O level: some optimization keeps it fast enough to
#                run routinely, but too much can inline away the stack
#                frames a sanitizer needs to report accurately (default: 1)
#   RECOVER      keep UBSan's default of printing a violation and
#                continuing, instead of aborting on the first one. Only
#                affects UBSan; ASan and TSan always abort. Omit this
#                unless something downstream of the first violation also
#                needs to be observed.
#
# Defines a build type that is otherwise like Debug (debug info, light
# optimization) but instrumented with the given sanitizers, as a global
# CMAKE_CXX_FLAGS_<NAME>/CMAKE_*_LINKER_FLAGS_<NAME> so every target --
# including fetched dependencies -- is built and linked the same way.
# Kept separate from Debug, rather than always-on in it, because the
# runtime and build-time cost (2-3x or more, depending on SANITIZERS)
# isn't something every Debug build or test run should pay. Opt in with
# -DCMAKE_BUILD_TYPE=<NAME>.
function(add_sanitized_build_type)
    cmake_parse_arguments(SANITIZE "RECOVER" "NAME;OPTIMIZATION" "SANITIZERS" ${ARGN})

    if(NOT SANITIZE_NAME)
        set(SANITIZE_NAME Sanitized)
    endif()
    if(NOT SANITIZE_SANITIZERS)
        set(SANITIZE_SANITIZERS address undefined)
    endif()
    if(NOT DEFINED SANITIZE_OPTIMIZATION)
        set(SANITIZE_OPTIMIZATION 1)
    endif()
    list(JOIN SANITIZE_SANITIZERS "," SANITIZE_JOINED)

    set(SANITIZE_CXX_FLAGS
        "-g -O${SANITIZE_OPTIMIZATION} -fno-omit-frame-pointer -fsanitize=${SANITIZE_JOINED}")
    if(NOT SANITIZE_RECOVER)
        string(APPEND SANITIZE_CXX_FLAGS " -fno-sanitize-recover=all")
    endif()

    string(TOUPPER "${SANITIZE_NAME}" SANITIZE_NAME_UPPER)

    set(CMAKE_CXX_FLAGS_${SANITIZE_NAME_UPPER} "${SANITIZE_CXX_FLAGS}"
        CACHE STRING "Flags used by the C++ compiler during ${SANITIZE_NAME} builds")
    set(CMAKE_EXE_LINKER_FLAGS_${SANITIZE_NAME_UPPER} "-fsanitize=${SANITIZE_JOINED}"
        CACHE STRING "Flags used by the linker during ${SANITIZE_NAME} builds")
    set(CMAKE_SHARED_LINKER_FLAGS_${SANITIZE_NAME_UPPER} "-fsanitize=${SANITIZE_JOINED}"
        CACHE STRING "Flags used by the linker for shared libraries during ${SANITIZE_NAME} builds")
    mark_as_advanced(CMAKE_CXX_FLAGS_${SANITIZE_NAME_UPPER}
                     CMAKE_EXE_LINKER_FLAGS_${SANITIZE_NAME_UPPER}
                     CMAKE_SHARED_LINKER_FLAGS_${SANITIZE_NAME_UPPER})

    get_property(_SANITIZE_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(_SANITIZE_IS_MULTI_CONFIG)
        if(NOT "${SANITIZE_NAME}" IN_LIST CMAKE_CONFIGURATION_TYPES)
            set(CMAKE_CONFIGURATION_TYPES "${CMAKE_CONFIGURATION_TYPES};${SANITIZE_NAME}"
                CACHE STRING "" FORCE)
        endif()
    else()
        get_property(_SANITIZE_BUILD_TYPES CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS)
        if(NOT _SANITIZE_BUILD_TYPES)
            set(_SANITIZE_BUILD_TYPES Debug Release RelWithDebInfo MinSizeRel)
        endif()
        if(NOT "${SANITIZE_NAME}" IN_LIST _SANITIZE_BUILD_TYPES)
            list(APPEND _SANITIZE_BUILD_TYPES "${SANITIZE_NAME}")
        endif()
        set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "${_SANITIZE_BUILD_TYPES}")
    endif()
endfunction()
