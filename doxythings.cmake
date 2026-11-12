# Finds doxythings, which links test, coverage and benchmark results into
# Doxygen documentation (https://github.com/nebulaeworks/doxythings).
#
# Sets DOXYTHINGS_EXECUTABLE (cached) to the binary, or to
# DOXYTHINGS_EXECUTABLE-NOTFOUND. Looked for, in order:
#   1. DOXYTHINGS_EXECUTABLE, if already set (e.g. -D on the command line,
#      pointing at a local build);
#   2. `doxythings` on PATH.
#
# Once doxythings publishes releases, this is also where a pinned release
# (version + SHA-256) gets downloaded into the build tree, falling back to
# `go install` when Go is available.
#
# doxythings_install_assets(<dir> <out-var>)
#   Runs `doxythings init`, writing the Doxyfile fragment that defines its
#   documentation tags and stylesheet into <dir>, and sets <out-var> to the
#   fragment's path, or to "" if doxythings wasn't found or failed.

find_program(DOXYTHINGS_EXECUTABLE doxythings
    DOC "doxythings binary, which links results into the Doxygen docs")

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
