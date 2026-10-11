find_program(CLANG_FORMAT_EXECUTABLE clang-format REQUIRED)

# Prefer the including project's own .clang-format; fall back to the one
# bundled here (plain BasedOnStyle: LLVM) if the project doesn't have one.
if(EXISTS "${CMAKE_SOURCE_DIR}/.clang-format")
    set(_ENFORCE_STYLE_FILE "${CMAKE_SOURCE_DIR}/.clang-format")
else()
    set(_ENFORCE_STYLE_FILE "${CMAKE_CURRENT_LIST_DIR}/.clang-format")
endif()

# ENFORCE_STYLE(<dirs...>)
#
# Registers `format` (rewrites in place) and `format-check` (reports only,
# non-zero exit on a diff) over every .cpp/.cc/.cxx/.h/.hpp file under each
# given, project-relative directory, formatted against _ENFORCE_STYLE_FILE.
function(ENFORCE_STYLE)
    set(TO_FORMAT)
    foreach(DIR IN LISTS ARGN)
        file(GLOB_RECURSE DIR_FILES CONFIGURE_DEPENDS
             "${CMAKE_SOURCE_DIR}/${DIR}/*.cpp"
             "${CMAKE_SOURCE_DIR}/${DIR}/*.cc"
             "${CMAKE_SOURCE_DIR}/${DIR}/*.cxx"
             "${CMAKE_SOURCE_DIR}/${DIR}/*.h"
             "${CMAKE_SOURCE_DIR}/${DIR}/*.hpp")
        list(APPEND TO_FORMAT ${DIR_FILES})
    endforeach()

    add_custom_target(format
        COMMAND ${CLANG_FORMAT_EXECUTABLE} -style=file:${_ENFORCE_STYLE_FILE} -i ${TO_FORMAT}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Formatting sources with clang-format (${_ENFORCE_STYLE_FILE})"
        VERBATIM)

    add_custom_target(format-check
        COMMAND ${CLANG_FORMAT_EXECUTABLE} -style=file:${_ENFORCE_STYLE_FILE} --dry-run -Werror ${TO_FORMAT}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Checking source formatting with clang-format (${_ENFORCE_STYLE_FILE})"
        VERBATIM)
endfunction()
