include(findOrFetch)

find_or_fetch(GTest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.14.0
    FOUND_VAR GTEST_FOUND
    RESULT GTEST_RESULT
)

if(GTEST_RESULT STREQUAL "FETCHED")
    set(GTEST_ALIAS_TARGETS
        GTest::gtest
        GTest::gtest_main
        GTest::gmock
        GTest::gmock_main
    )

    foreach(alias IN LISTS GTEST_ALIAS_TARGETS)
        if (TARGET ${alias})
            # Resolve to actual target name
            get_target_property(real_target ${alias} NAME)
            if (NOT ${alias} STREQUAL ${real_target})
                set_target_properties(${real_target} PROPERTIES
                    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests"
                    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests"
                )
            endif()
        endif()
    endforeach()
endif()
