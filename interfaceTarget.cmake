# wrap_interface_target(<target> INCLUDE_DIRS <dirs...>)
#
# Defines an INTERFACE IMPORTED target over the given include directories,
# for a header-only dependency that doesn't export a usable target of its
# own (bare variables like <Name>_INCLUDE_DIRS instead of something you can
# target_link_libraries() against).
#
# A no-op if <target> already exists -- e.g. the dependency's own build
# already provides it, a system package was found instead of a fetched
# copy, or a future version of it starts exporting one.
function(wrap_interface_target TARGET)
    if(TARGET ${TARGET})
        return()
    endif()

    cmake_parse_arguments(ARGS "" "" "INCLUDE_DIRS" ${ARGN})

    add_library(${TARGET} INTERFACE IMPORTED)
    target_include_directories(${TARGET} INTERFACE ${ARGS_INCLUDE_DIRS})
endfunction()
