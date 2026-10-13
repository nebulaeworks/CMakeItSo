include(FetchContent)

# _fetch_dependency_impl(<Name>
#     GIT_REPOSITORY <url>
#     GIT_TAG <tag>
#     [PRE_FETCH_OPTIONS <NAME=VALUE...>]
#     [EXTRA_DECLARE_ARGS <args...>]
# )
#
# Shared by find_or_fetch() and fetchDependency(): applies PRE_FETCH_OPTIONS,
# then FetchContent_Declare()/FetchContent_MakeAvailable(). EXTRA_DECLARE_ARGS
# is appended to the Declare() call verbatim -- find_or_fetch() uses it to
# pass FIND_PACKAGE_ARGS so a system package appearing later still wins;
# fetchDependency() leaves it empty, since it never wants that fallback.
#
# A macro, not a function: FetchContent_MakeAvailable()'s output variables
# (<name>_SOURCE_DIR etc.) must land directly in the calling function's own
# scope, not get trapped one level deeper, so each caller's existing
# PARENT_SCOPE re-export (the single hop up to *its* caller) is enough.
macro(_fetch_dependency_impl NAME)
    cmake_parse_arguments(_FDI "" "GIT_REPOSITORY;GIT_TAG" "PRE_FETCH_OPTIONS;EXTRA_DECLARE_ARGS" ${ARGN})

    foreach(_FDI_OPTION ${_FDI_PRE_FETCH_OPTIONS})
        string(REPLACE "=" ";" _FDI_OPTION_PARTS "${_FDI_OPTION}")
        list(GET _FDI_OPTION_PARTS 0 _FDI_OPTION_NAME)
        list(GET _FDI_OPTION_PARTS 1 _FDI_OPTION_VALUE)
        set(${_FDI_OPTION_NAME} ${_FDI_OPTION_VALUE} CACHE STRING "" FORCE)
    endforeach()
    unset(_FDI_OPTION_PARTS)
    unset(_FDI_OPTION_NAME)
    unset(_FDI_OPTION_VALUE)

    set(CMAKE_EXPORT_NO_PACKAGE_REGISTRY ON)
    message(STATUS "Fetching ${NAME}")
    FetchContent_Declare(
        ${NAME}
        GIT_REPOSITORY ${_FDI_GIT_REPOSITORY}
        GIT_TAG ${_FDI_GIT_TAG}
        DOWNLOAD_EXTRACT_TIMESTAMP true
        ${_FDI_EXTRA_DECLARE_ARGS}
    )
    FetchContent_MakeAvailable(${NAME})
endmacro()

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
# Use this when a system install is an acceptable, preferred substitute for
# a fetched one. When it isn't -- you need build repeatability (always this
# exact pinned version, never whatever's on the build machine) or reliable
# control over how it's built (e.g. forcing a static-only build, which a
# found system package could otherwise silently not honor) -- use
# fetchDependency() instead.
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

    # Deliberately excludes CMake's user/system package registries
    # (~/.cmake/packages and the system equivalent). A fetched dependency
    # that calls export(PACKAGE ...) in its own CMakeLists.txt (RapidJSON
    # does) registers its *build tree* there -- so a later, unrelated
    # configure (even of a different project) can "find" a stale pointer
    # into a previous fetch's build directory instead of either a real
    # system install or a clean new fetch. CMAKE_EXPORT_NO_PACKAGE_REGISTRY
    # inside _fetch_dependency_impl stops that from happening for whatever
    # this call fetches.
    find_package(${NAME} ${ARGS_FIND_PACKAGE_VERSION} QUIET
        NO_CMAKE_PACKAGE_REGISTRY NO_CMAKE_SYSTEM_PACKAGE_REGISTRY)
    if(${ARGS_FOUND_VAR})
        message(STATUS "${NAME}: Available")
        set(_FIND_OR_FETCH_RESULT FOUND)
    else()
        _fetch_dependency_impl(${NAME}
            GIT_REPOSITORY ${ARGS_GIT_REPOSITORY}
            GIT_TAG ${ARGS_GIT_TAG}
            PRE_FETCH_OPTIONS ${ARGS_PRE_FETCH_OPTIONS}
            EXTRA_DECLARE_ARGS
                FIND_PACKAGE_ARGS ${ARGS_FIND_PACKAGE_VERSION} NAMES ${ARGS_FIND_PACKAGE_NAMES}
                    NO_CMAKE_PACKAGE_REGISTRY NO_CMAKE_SYSTEM_PACKAGE_REGISTRY
        )
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

# fetchDependency(<Name>
#     GIT_REPOSITORY <url>
#     GIT_TAG <tag>
#     [PRE_FETCH_OPTIONS <NAME=VALUE...>]
# )
#
# Always fetches the pinned GIT_TAG -- no find_package() fallback, so no
# system install can be silently substituted. Use this instead of
# find_or_fetch() when you need build repeatability (always this exact
# version, regardless of what's installed on the build machine) or
# reliable control over how the dependency is built (e.g. forcing a
# static-only build via PRE_FETCH_OPTIONS; a found system package could
# otherwise have been built with different settings and bypass that
# entirely).
function(fetchDependency NAME)
    cmake_parse_arguments(ARGS "" "GIT_REPOSITORY;GIT_TAG" "PRE_FETCH_OPTIONS" ${ARGN})

    _fetch_dependency_impl(${NAME}
        GIT_REPOSITORY ${ARGS_GIT_REPOSITORY}
        GIT_TAG ${ARGS_GIT_TAG}
        PRE_FETCH_OPTIONS ${ARGS_PRE_FETCH_OPTIONS}
    )

    string(TOLOWER ${NAME} _FETCH_DEPENDENCY_NAME_LOWER)
    foreach(_FETCH_DEPENDENCY_SUFFIX SOURCE_DIR BINARY_DIR POPULATED)
        set(_FETCH_DEPENDENCY_VAR ${_FETCH_DEPENDENCY_NAME_LOWER}_${_FETCH_DEPENDENCY_SUFFIX})
        if(DEFINED ${_FETCH_DEPENDENCY_VAR})
            set(${_FETCH_DEPENDENCY_VAR} ${${_FETCH_DEPENDENCY_VAR}} PARENT_SCOPE)
        endif()
    endforeach()
endfunction()
