FIND_PACKAGE(GTest)
IF (${GTEST_FOUND})
    MESSAGE(STATUS "GTest: Available")
ELSE (${GTEST_FOUND})
    MESSAGE(STATUS "Fetching GTest")
    FETCHCONTENT_DECLARE(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.14.0
        DOWNLOAD_EXTRACT_TIMESTAMP true
        FIND_PACKAGE_ARGS NAMES GTest
    )

    FETCHCONTENT_MAKEAVAILABLE(googletest)
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
ENDIF (${GTEST_FOUND})
