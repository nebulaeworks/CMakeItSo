# Reports why coverage is unavailable and exits non-zero.
function(add_coverage_stub REASON)
    add_custom_target(coverage
        COMMAND ${CMAKE_COMMAND} -E echo "${REASON}"
        COMMAND ${CMAKE_COMMAND} -E false
        VERBATIM)
endfunction()

# add_coverage_target(TESTS <exe> TARGETS <targets...> SOURCE_DIRS <dirs...>
#                     [DEFAULT_ON_BUILD_TYPES <types...>])
#   TESTS                  test executable, run to produce coverage data
#   TARGETS                targets to instrument (libraries, executables, tests)
#   SOURCE_DIRS            project-relative directories to include in the report
#   DEFAULT_ON_BUILD_TYPES build types for which ENABLE_COVERAGE defaults to ON
#
# Always defines a `coverage` target. It produces a gcovr report into
# <binary>/test/coverage/ when instrumentation is enabled, and otherwise
# reports why not and exits non-zero.
function(add_coverage_target)
    cmake_parse_arguments(COV "" "TESTS" "TARGETS;SOURCE_DIRS;DEFAULT_ON_BUILD_TYPES" ${ARGN})

    list(FIND COV_DEFAULT_ON_BUILD_TYPES "${CMAKE_BUILD_TYPE}" DEFAULT_ON_INDEX)
    if(DEFAULT_ON_INDEX EQUAL -1)
        set(COVERAGE_DEFAULT OFF)
    else()
        set(COVERAGE_DEFAULT ON)
    endif()
    option(ENABLE_COVERAGE "Instrument targets for gcov coverage reporting" ${COVERAGE_DEFAULT})

    if(NOT ENABLE_COVERAGE)
        add_coverage_stub("Coverage is disabled for '${CMAKE_BUILD_TYPE}' builds. Reconfigure with -DENABLE_COVERAGE=ON or use a build type listed in DEFAULT_ON_BUILD_TYPES.")
        return()
    endif()

    find_program(GCOVR_EXECUTABLE gcovr)
    if(NOT GCOVR_EXECUTABLE)
        message(WARNING "ENABLE_COVERAGE is ON but gcovr was not found; coverage is disabled")
        add_coverage_stub("gcovr was not found. Install it (e.g. 'pacman -S gcovr' or 'pip install gcovr') and reconfigure.")
        return()
    endif()

    set(GCOVR_TOOL_ARGS)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        set(GCOVR_TOOL_ARGS --gcov-executable "llvm-cov gcov")
    endif()

    foreach(COVERED_TARGET ${COV_TARGETS})
        target_compile_options(${COVERED_TARGET} PRIVATE --coverage)
        target_link_options(${COVERED_TARGET} PRIVATE --coverage)
    endforeach()

    set(COVERAGE_DIR ${PROJECT_BINARY_DIR}/test/coverage)
    set(GCOVR_FILTERS)
    foreach(SOURCE_DIR ${COV_SOURCE_DIRS})
        list(APPEND GCOVR_FILTERS --filter ${PROJECT_SOURCE_DIR}/${SOURCE_DIR}/)
    endforeach()

    add_custom_target(coverage
        COMMAND ${CMAKE_COMMAND} -E make_directory ${COVERAGE_DIR}
        COMMAND $<TARGET_FILE:${COV_TESTS}>
        COMMAND ${GCOVR_EXECUTABLE}
                --root ${PROJECT_SOURCE_DIR}
                --object-directory ${PROJECT_BINARY_DIR}
                ${GCOVR_FILTERS}
                ${GCOVR_TOOL_ARGS}
                --html-details ${COVERAGE_DIR}/index.html
                --print-summary
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        COMMENT "Generating coverage report"
        VERBATIM)
    add_dependencies(coverage ${COV_TESTS})
endfunction()
