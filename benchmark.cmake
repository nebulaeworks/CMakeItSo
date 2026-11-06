include(findOrFetch)

fetchDependency(benchmark
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG v1.9.5
    PRE_FETCH_OPTIONS "BENCHMARK_ENABLE_TESTING=OFF;BENCHMARK_ENABLE_GTEST_TESTS=OFF;BENCHMARK_ENABLE_INSTALL=OFF;BENCHMARK_DOWNLOAD_DEPENDENCIES=OFF"
)

# discover_benchmarks(
#     ROOT <dir>
#     OUTPUT_ROOT <dir>
#     KINDS <names...>
#     [SHARED <dirs...>]
#     [LINK_MATCH <regex>]
#     [LINK_DEFAULT <targets...>]
#     [OUT_TARGETS <var>]
# )
#
# Mirrors discover_catch2_tests()'s directory-scanning shape (see
# findCatch2.cmake) but for Google Benchmark instead of Catch2:
# benchmarking is profiling, not correctness testing, so it gets its own
# scan and its own executables (linked against benchmark::benchmark_main,
# not Catch2::Catch2WithMain), and is never registered with ctest.
#
# See discover_catch2_tests() for what ROOT, OUTPUT_ROOT, KINDS, SHARED,
# LINK_MATCH, LINK_DEFAULT and OUT_TARGETS mean; the semantics are
# identical here.
function(discover_benchmarks)
    cmake_parse_arguments(ARGS "" "ROOT;OUTPUT_ROOT;LINK_MATCH;OUT_TARGETS" "KINDS;SHARED;LINK_DEFAULT" ${ARGN})

    get_filename_component(ABS_ROOT "${ARGS_ROOT}" ABSOLUTE)

    set(SHARED_SOURCES)
    foreach(SHARED_DIR ${ARGS_SHARED})
        file(GLOB_RECURSE DIR_SHARED_SOURCES CONFIGURE_DEPENDS "${ABS_ROOT}/${SHARED_DIR}/*.cpp")
        list(APPEND SHARED_SOURCES ${DIR_SHARED_SOURCES})
    endforeach()

    file(GLOB_RECURSE ALL_SOURCES CONFIGURE_DEPENDS "${ABS_ROOT}/*.cpp")

    set(KIND_ROOT_DIRS)
    foreach(SRC ${ALL_SOURCES})
        file(RELATIVE_PATH REL_SRC "${ABS_ROOT}" "${SRC}")
        string(REPLACE "/" ";" REL_PARTS "${REL_SRC}")
        set(PREFIX_PARTS)
        foreach(PART ${REL_PARTS})
            list(APPEND PREFIX_PARTS "${PART}")
            if(PART IN_LIST ARGS_KINDS)
                list(JOIN PREFIX_PARTS "/" KIND_REL_DIR)
                list(APPEND KIND_ROOT_DIRS "${KIND_REL_DIR}")
                break()
            endif()
        endforeach()
    endforeach()
    list(REMOVE_DUPLICATES KIND_ROOT_DIRS)

    set(RESULT_TARGETS)
    foreach(KIND_REL_DIR ${KIND_ROOT_DIRS})
        string(REPLACE "/" "_" TARGET_NAME "${KIND_REL_DIR}")

        file(GLOB_RECURSE DIR_SOURCES CONFIGURE_DEPENDS "${ABS_ROOT}/${KIND_REL_DIR}/*.cpp")

        add_executable(${TARGET_NAME} ${DIR_SOURCES} ${SHARED_SOURCES})
        target_include_directories(${TARGET_NAME} PRIVATE ${ABS_ROOT})
        target_link_libraries(${TARGET_NAME} PRIVATE benchmark::benchmark_main)

        if(ARGS_LINK_MATCH AND "${KIND_REL_DIR}" MATCHES "${ARGS_LINK_MATCH}")
            target_link_libraries(${TARGET_NAME} PRIVATE ${CMAKE_MATCH_1})
        elseif(ARGS_LINK_DEFAULT)
            target_link_libraries(${TARGET_NAME} PRIVATE ${ARGS_LINK_DEFAULT})
        endif()

        set_target_properties(${TARGET_NAME} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY "${ARGS_OUTPUT_ROOT}/${KIND_REL_DIR}")

        list(APPEND RESULT_TARGETS ${TARGET_NAME})
    endforeach()

    if(ARGS_OUT_TARGETS)
        set(${ARGS_OUT_TARGETS} ${RESULT_TARGETS} PARENT_SCOPE)
    endif()
endfunction()

# add_benchmark_target(
#     BENCHMARKS <exes...>
#     [OUTPUT_DIR <dir>]
#     [DOCS_DIR <dir>]
#     [REPORT_TOOL <path>]
#     [REPETITIONS <n>]
# )
#   BENCHMARKS  benchmark executables, run (in order) to produce results
#   OUTPUT_DIR  where each executable's --benchmark_out JSON is written
#               (default: <binary>/Testing/benchmarks)
#   DOCS_DIR    where the generated Doxygen page is written
#               (default: <binary>/docs-generated)
#   REPORT_TOOL path to benchmark_report.py (default: the in-repo copy at
#               benchmark-report-to-extract/ -- see that directory's
#               README; once it's its own repo, callers would instead pass
#               wherever they've fetched it to)
#   REPETITIONS how many times each benchmark is run end-to-end (default:
#               30) -- without this, a benchmark produces exactly one
#               sample, so there's no way to tell a real number from noise;
#               repeating it is what lets the report show spread (mean,
#               p50, p99) instead of one untrusted data point. Each
#               repetition re-runs the whole auto-tuned measurement
#               window, so total `bench` runtime scales with this value.
#
# Defines a `bench` target that runs each BENCHMARKS executable with
# --benchmark_repetitions=<n> --benchmark_out=<name>.json
# --benchmark_out_format=json, then renders the combined results plus a
# snapshot of the host's hardware (CPU model, cores/threads, memory speed
# where available, active tuned profile) into a Doxygen page at
# DOCS_DIR/benchmarks.dox. That page is picked up the next time the `docs`
# target runs -- there's no hard dependency between them, since re-running
# benchmarks on every docs build would be unwanted, the same way
# `coverage`'s HTML report rides along under the docs output directory
# without being wired into Doxygen's own build graph.
#
# DOCS_DIR is created immediately (at configure time, not just when `bench`
# runs), since it's also one of Doxygen's own INPUT directories (see
# conf/Doxyfile.in) -- without it existing up front, a `docs` build taken
# before `bench` has ever run would warn about a missing input directory.
function(add_benchmark_target)
    cmake_parse_arguments(BENCH "" "OUTPUT_DIR;DOCS_DIR;REPORT_TOOL;REPETITIONS" "BENCHMARKS" ${ARGN})

    if(NOT BENCH_OUTPUT_DIR)
        set(BENCH_OUTPUT_DIR ${PROJECT_BINARY_DIR}/Testing/benchmarks)
    endif()
    if(NOT BENCH_DOCS_DIR)
        set(BENCH_DOCS_DIR ${PROJECT_BINARY_DIR}/docs-generated)
    endif()
    if(NOT BENCH_REPORT_TOOL)
        set(BENCH_REPORT_TOOL ${PROJECT_SOURCE_DIR}/benchmark-report-to-extract/benchmark_report.py)
    endif()
    if(NOT BENCH_REPETITIONS)
        set(BENCH_REPETITIONS 30)
    endif()
    file(MAKE_DIRECTORY ${BENCH_DOCS_DIR})

    set(RUN_BENCHMARK_COMMANDS)
    set(RESULT_JSON_FILES)
    foreach(BENCH_EXE ${BENCH_BENCHMARKS})
        set(RESULT_JSON "${BENCH_OUTPUT_DIR}/${BENCH_EXE}.json")
        list(APPEND RESULT_JSON_FILES "${RESULT_JSON}")
        list(APPEND RUN_BENCHMARK_COMMANDS
            COMMAND "$<TARGET_FILE:${BENCH_EXE}>"
                    --benchmark_repetitions=${BENCH_REPETITIONS}
                    --benchmark_out=${RESULT_JSON}
                    --benchmark_out_format=json)
    endforeach()

    add_custom_target(bench
        COMMAND ${CMAKE_COMMAND} -E make_directory ${BENCH_OUTPUT_DIR}
        ${RUN_BENCHMARK_COMMANDS}
        COMMAND python3 ${BENCH_REPORT_TOOL}
                --format dox
                --page-name benchmarks
                --title "Benchmark Results"
                --output ${BENCH_DOCS_DIR}/benchmarks.dox
                ${RESULT_JSON_FILES}
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        COMMENT "Running benchmarks and generating the docs page"
        VERBATIM)
    if(BENCH_BENCHMARKS)
        add_dependencies(bench ${BENCH_BENCHMARKS})
    endif()
endfunction()
