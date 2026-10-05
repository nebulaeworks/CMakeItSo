FIND_PACKAGE(Catch2 3 QUIET)
IF (Catch2_FOUND)
    MESSAGE(STATUS "Catch2: Available")
ELSE (Catch2_FOUND)
    MESSAGE(STATUS "Fetching Catch2")
    FETCHCONTENT_DECLARE(
        Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG v3.4.0
        DOWNLOAD_EXTRACT_TIMESTAMP true
        FIND_PACKAGE_ARGS 3 NAMES Catch2
    )

    FETCHCONTENT_MAKEAVAILABLE(Catch2)
ENDIF (Catch2_FOUND)
