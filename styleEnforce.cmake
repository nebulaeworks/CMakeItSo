FUNCTION(ENFORCE_STYLE PATHS)
    FOREACH(PATH "${PATHS}")
        FILE(GLOB_RECURSE 
             TO_FORMAT 
             "${CMAKE_SOURCE_DIR}/${PATH}/*.cpp"
             "${CMAKE_SOURCE_DIR}/${PATH}/*.h")
    ENDFOREACH()
    message(STATUS "${TO_FORMAT}")
    add_custom_target(
            format
            COMMAND clang-format
            -style=LLVM
            --dry-run
            -i
            --verbose
            ${TO_FORMAT}
    )
ENDFUNCTION()
