# Finds doxythings, which links test, coverage and benchmark results into
# Doxygen documentation (https://github.com/nebulaeworks/doxythings).
#
# Sets DOXYTHINGS_EXECUTABLE (cached) to the binary, or to
# DOXYTHINGS_EXECUTABLE-NOTFOUND. Looked for, in order:
#   1. DOXYTHINGS_EXECUTABLE, if already set (e.g. -D on the command line,
#      pointing at a local build);
#   2. `doxythings` on PATH.
#
#   3. a pinned release (DOXYTHINGS_VERSION) built with `go install` into
#      the build tree, when Go is available and DOXYTHINGS_AUTO_INSTALL is
#      ON (the default).
# Downloading prebuilt, checksummed release binaries instead is left until
# doxythings publishes them.
#
# doxythings_install_assets(<dir> <out-var>)
#   Runs `doxythings init`, writing the Doxyfile fragment that defines its
#   documentation tags and stylesheet into <dir>, and sets <out-var> to the
#   fragment's path, or to "" if doxythings wasn't found or failed.

set(DOXYTHINGS_VERSION "v0.1.0" CACHE STRING
    "doxythings release to build with `go install` when none is found")
option(DOXYTHINGS_AUTO_INSTALL
    "Build DOXYTHINGS_VERSION with `go install` when doxythings isn't found" ON)

find_program(DOXYTHINGS_EXECUTABLE doxythings
    DOC "doxythings binary, which links results into the Doxygen docs")

if(NOT DOXYTHINGS_EXECUTABLE AND DOXYTHINGS_AUTO_INSTALL)
    find_program(DOXYTHINGS_GO_EXECUTABLE go)
    if(DOXYTHINGS_GO_EXECUTABLE)
        set(_DT_BIN ${CMAKE_BINARY_DIR}/_deps/doxythings-${DOXYTHINGS_VERSION}/bin)
        message(STATUS "doxythings not found: building ${DOXYTHINGS_VERSION} with go install")
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E env GOBIN=${_DT_BIN}
                    ${DOXYTHINGS_GO_EXECUTABLE} install
                    github.com/nebulaeworks/doxythings/cmd/doxythings@${DOXYTHINGS_VERSION}
            RESULT_VARIABLE _DT_RESULT
            ERROR_VARIABLE _DT_ERROR)
        if(_DT_RESULT EQUAL 0)
            unset(DOXYTHINGS_EXECUTABLE CACHE)
            find_program(DOXYTHINGS_EXECUTABLE doxythings
                PATHS ${_DT_BIN} NO_DEFAULT_PATH
                DOC "doxythings binary, which links results into the Doxygen docs")
        else()
            message(WARNING "go install doxythings@${DOXYTHINGS_VERSION} failed: ${_DT_ERROR}")
        endif()
    endif()
endif()

function(doxythings_install_assets DIR OUT_VAR)
    set(${OUT_VAR} "" PARENT_SCOPE)
    if(NOT DOXYTHINGS_EXECUTABLE)
        return()
    endif()
    execute_process(
        COMMAND ${DOXYTHINGS_EXECUTABLE} init --dir ${DIR}
        RESULT_VARIABLE RESULT
        OUTPUT_QUIET
        ERROR_VARIABLE ERROR)
    if(NOT RESULT EQUAL 0)
        message(WARNING "doxythings init failed: ${ERROR}")
        return()
    endif()
    set(${OUT_VAR} ${DIR}/doxythings.doxyfile PARENT_SCOPE)
endfunction()
