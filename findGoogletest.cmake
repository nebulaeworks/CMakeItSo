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
ENDIF (${GTEST_FOUND})
