include(FetchContent)

# find_or_fetch(<Name>
#     GIT_REPOSITORY <url>
#     GIT_TAG <tag>
#     [FIND_PACKAGE_VERSION <v>]
#     [FIND_PACKAGE_NAMES <names...>]
#     [FOUND_VAR <var>]
#     [RESULT <var>]
#     [PRE_FETCH_OPTIONS <NAME=VALUE...>]
# )
#
# find_package(<Name> [<FIND_PACKAGE_VERSION>] QUIET) first; if that
# doesn't find it, FetchContent_Declare() + FetchContent_MakeAvailable()
# with FIND_PACKAGE_ARGS, so a system package that appears later (e.g. one
# installed between configure runs) still wins over the fetched copy.
#
# FOUND_VAR names the variable find_package() sets on success, since
# packages aren't consistent about casing (Catch2_FOUND vs GTEST_FOUND).
# Defaults to <Name>_FOUND. FIND_PACKAGE_NAMES defaults to <Name>; set it
# when the package's find_package() name differs from <Name>.
#
# RESULT, if given, is set to FOUND or FETCHED, for callers that need to
# do something only on one path (e.g. relocating a fetched dependency's
# own build outputs, which shouldn't happen to a system-found one).
#
# PRE_FETCH_OPTIONS sets each NAME=VALUE as a forced cache entry before
# fetching, only when actually fetching (never against a found system
# package) -- for the common case of a fetched project gating its own
# tests/docs/examples behind option()s that must be set before its
# CMakeLists.txt runs. Values are cached as STRING; CMake's if() treats
# ON/OFF/TRUE/FALSE the same regardless of a cache entry's declared type,
# so this works for boolean options too.
function(find_or_fetch NAME)
    cmake_parse_arguments(ARGS "" "GIT_REPOSITORY;GIT_TAG;FIND_PACKAGE_VERSION;FOUND_VAR;RESULT" "FIND_PACKAGE_NAMES;PRE_FETCH_OPTIONS" ${ARGN})

    if(NOT ARGS_FIND_PACKAGE_NAMES)
        set(ARGS_FIND_PACKAGE_NAMES ${NAME})
    endif()
    if(NOT ARGS_FOUND_VAR)
        set(ARGS_FOUND_VAR ${NAME}_FOUND)
    endif()

    find_package(${NAME} ${ARGS_FIND_PACKAGE_VERSION} QUIET)
    if(${ARGS_FOUND_VAR})
        message(STATUS "${NAME}: Available")
        set(_FIND_OR_FETCH_RESULT FOUND)
    else()
        foreach(_FIND_OR_FETCH_OPTION ${ARGS_PRE_FETCH_OPTIONS})
            string(REPLACE "=" ";" _FIND_OR_FETCH_OPTION_PARTS "${_FIND_OR_FETCH_OPTION}")
            list(GET _FIND_OR_FETCH_OPTION_PARTS 0 _FIND_OR_FETCH_OPTION_NAME)
            list(GET _FIND_OR_FETCH_OPTION_PARTS 1 _FIND_OR_FETCH_OPTION_VALUE)
            set(${_FIND_OR_FETCH_OPTION_NAME} ${_FIND_OR_FETCH_OPTION_VALUE} CACHE STRING "" FORCE)
        endforeach()

        message(STATUS "Fetching ${NAME}")
        FetchContent_Declare(
            ${NAME}
            GIT_REPOSITORY ${ARGS_GIT_REPOSITORY}
            GIT_TAG ${ARGS_GIT_TAG}
            DOWNLOAD_EXTRACT_TIMESTAMP true
            FIND_PACKAGE_ARGS ${ARGS_FIND_PACKAGE_VERSION} NAMES ${ARGS_FIND_PACKAGE_NAMES}
        )
        FetchContent_MakeAvailable(${NAME})
        set(_FIND_OR_FETCH_RESULT FETCHED)
    endif()

    # find_package()/FetchContent_MakeAvailable() set these as plain
    # variables in whatever scope they're called from. Since that's this
    # function's own scope, not the caller's, they're re-exported here
    # explicitly -- otherwise a caller needing e.g. <name>_SOURCE_DIR (as
    # findCatch2.cmake does, to locate Catch2's extras/ directory) would
    # always find it undefined.
    if(ARGS_FOUND_VAR)
        set(${ARGS_FOUND_VAR} ${${ARGS_FOUND_VAR}} PARENT_SCOPE)
    endif()
    string(TOLOWER ${NAME} _FIND_OR_FETCH_NAME_LOWER)
    foreach(_FIND_OR_FETCH_SUFFIX SOURCE_DIR BINARY_DIR POPULATED)
        set(_FIND_OR_FETCH_VAR ${_FIND_OR_FETCH_NAME_LOWER}_${_FIND_OR_FETCH_SUFFIX})
        if(DEFINED ${_FIND_OR_FETCH_VAR})
            set(${_FIND_OR_FETCH_VAR} ${${_FIND_OR_FETCH_VAR}} PARENT_SCOPE)
        endif()
    endforeach()

    if(ARGS_RESULT)
        set(${ARGS_RESULT} ${_FIND_OR_FETCH_RESULT} PARENT_SCOPE)
    endif()
endfunction()
