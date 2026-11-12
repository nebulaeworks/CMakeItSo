include(findOrFetch)
include(doxythings)

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
#     [DOXYFILE <file>]
#     [REPETITIONS <n>]
# )
#   BENCHMARKS    benchmark executables, run (in order) to produce results
#   OUTPUT_DIR    where each executable's --benchmark_out JSON is written,
#                 plus doxythings' working files
#                 (default: <binary>/Testing/benchmarks)
#   DOCS_DIR      where the generated benchmarks.dox is written; must be one
#                 of Doxygen's INPUT directories
#                 (default: <binary>/docs-generated)
#   DOXYFILE      the project's configured Doxyfile, used for the XML pass
#                 below (default: <binary>/conf/Doxyfile, from doxyTarget)
#   REPETITIONS   how many times each benchmark is run end-to-end (default:
#                 30) -- without this, a benchmark produces exactly one
#                 sample, so there's no way to tell a real number from noise;
#                 repeating it is what lets the report show spread instead of
#                 one untrusted data point. Each repetition re-runs the whole
#                 auto-tuned measurement window, so total `bench` runtime
#                 scales with this value.
#
# Defines a `bench` target that runs each BENCHMARKS executable with
# --benchmark_repetitions=<n> --benchmark_out=<name>.json
# --benchmark_out_format=json, then:
#
#   1. runs Doxygen over the project with XML output only, which tells
#      doxythings where every benchmark (@benchmark_run) and the entity it
#      measures (@benchmarks) is documented;
#   2. runs doxythings, which writes DOCS_DIR/benchmarks.dox: an overview
#      page, a Results section on each benchmark, and a Performance section
#      on each measured entity, all linked to each other.
#
# Those are picked up the next time the `docs` target runs -- there's no
# hard dependency between them, since re-running benchmarks on every docs
# build would be unwanted, the same way `coverage`'s HTML report rides
# along under the docs output directory without being wired into Doxygen's
# own build graph.
#
# The docs need doxythings (see doxythings.cmake for where it's looked for);
# without it, `bench` still runs the benchmarks but writes no docs.
#
# The project's Doxyfile must end with
#     @INCLUDE = <binary>/conf/doxythings.doxyfile
# which this function writes at configure time. It defines doxythings'
# documentation tags and stylesheet and adds its HTML fragments to
# EXAMPLE_PATH, so a `docs` build taken before `bench` has ever run (or
# without doxythings) still succeeds without warnings. DOCS_DIR and the
# fragments directory are created up front for the same reason.
function(add_benchmark_target)
    cmake_parse_arguments(BENCH "" "OUTPUT_DIR;DOCS_DIR;DOXYFILE;REPETITIONS" "BENCHMARKS" ${ARGN})

    if(NOT BENCH_OUTPUT_DIR)
        set(BENCH_OUTPUT_DIR ${PROJECT_BINARY_DIR}/Testing/benchmarks)
    endif()
    if(NOT BENCH_DOCS_DIR)
        set(BENCH_DOCS_DIR ${PROJECT_BINARY_DIR}/docs-generated)
    endif()
    if(NOT BENCH_DOXYFILE)
        set(BENCH_DOXYFILE ${PROJECT_BINARY_DIR}/conf/Doxyfile)
    endif()
    if(NOT BENCH_REPETITIONS)
        set(BENCH_REPETITIONS 30)
    endif()

    set(FRAGMENTS_DIR ${BENCH_OUTPUT_DIR}/fragments)
    set(XML_PASS_DIR ${BENCH_OUTPUT_DIR}/doxygen)
    file(MAKE_DIRECTORY ${BENCH_DOCS_DIR} ${FRAGMENTS_DIR})
    # Stands in until the first `bench` run, so `@ref benchmarks` resolves.
    if(NOT EXISTS ${BENCH_DOCS_DIR}/benchmarks.dox)
        file(WRITE ${BENCH_DOCS_DIR}/benchmarks.dox
            "/**\n * @page benchmarks Benchmark Results\n *\n"
            " * No results yet: build the `bench` target, then `docs` again.\n */\n")
    endif()

    doxythings_install_assets(${PROJECT_BINARY_DIR}/conf/doxythings DOXYTHINGS_DOXYFILE)
    if(DOXYTHINGS_DOXYFILE)
        set(DOXYTHINGS_CONFIG
            "@INCLUDE = ${DOXYTHINGS_DOXYFILE}\n"
            "EXAMPLE_PATH += ${FRAGMENTS_DIR}\n")
    else()
        message(WARNING "add_benchmark_target: doxythings not found (set DOXYTHINGS_EXECUTABLE), so `bench` won't add results to the docs.")
        # Same tags, rendering nothing, so tagged sources still document cleanly.
        set(DOXYTHINGS_CONFIG
            "ALIASES += benchmark_run{1}=\"\"\n"
            "ALIASES += benchmarks{1}=\"\"\n")
    endif()
    file(WRITE ${PROJECT_BINARY_DIR}/conf/doxythings.doxyfile ${DOXYTHINGS_CONFIG})

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

    set(DOCS_COMMANDS)
    if(DOXYTHINGS_DOXYFILE)
        set(XML_ARGS)
        if(DOXYGEN_EXECUTABLE AND EXISTS ${BENCH_DOXYFILE})
            set(XML_PASS_CONFIG ${PROJECT_BINARY_DIR}/conf/Doxyfile.doxythings-xml)
            # Later assignments override the project's own; warnings are
            # left to the real `docs` run, which is the one that counts.
            file(WRITE ${XML_PASS_CONFIG}
                "@INCLUDE = ${BENCH_DOXYFILE}\n"
                "OUTPUT_DIRECTORY = ${XML_PASS_DIR}\n"
                "GENERATE_HTML = NO\n"
                "GENERATE_LATEX = NO\n"
                "GENERATE_XML = YES\n"
                "XML_OUTPUT = xml\n"
                "GENERATE_TAGFILE =\n"
                "HAVE_DOT = NO\n"
                "QUIET = YES\n"
                "WARN_AS_ERROR = NO\n"
                "WARN_LOGFILE = ${XML_PASS_DIR}/warnings.log\n"
                "EXCLUDE += ${BENCH_DOCS_DIR}/benchmarks.dox\n")
            list(APPEND DOCS_COMMANDS
                COMMAND ${CMAKE_COMMAND} -E rm -rf ${XML_PASS_DIR}
                COMMAND ${CMAKE_COMMAND} -E make_directory ${XML_PASS_DIR}
                COMMAND ${DOXYGEN_EXECUTABLE} ${XML_PASS_CONFIG})
            set(XML_ARGS --xml-dir ${XML_PASS_DIR}/xml)
        else()
            message(STATUS "add_benchmark_target: no Doxygen, so benchmark results won't link to the code")
        endif()
        list(APPEND DOCS_COMMANDS
            COMMAND ${DOXYTHINGS_EXECUTABLE} doxygen
                    --output ${BENCH_DOCS_DIR}/benchmarks.dox
                    --fragments-dir ${FRAGMENTS_DIR}
                    ${XML_ARGS}
                    --page-name benchmarks
                    --title "Benchmark Results"
                    --build-type "$<CONFIG>"
                    ${RESULT_JSON_FILES})
    endif()

    add_custom_target(bench
        COMMAND ${CMAKE_COMMAND} -E make_directory ${BENCH_OUTPUT_DIR}
        ${RUN_BENCHMARK_COMMANDS}
        ${DOCS_COMMANDS}
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        COMMENT "Running benchmarks and generating their docs"
        VERBATIM)
    if(BENCH_BENCHMARKS)
        add_dependencies(bench ${BENCH_BENCHMARKS})
    endif()
endfunction()
