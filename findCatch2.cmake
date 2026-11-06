include(findOrFetch)

find_or_fetch(Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.16.1
    FIND_PACKAGE_VERSION 3
)

if(catch2_SOURCE_DIR)
    list(APPEND CMAKE_MODULE_PATH "${catch2_SOURCE_DIR}/extras")
endif()
include(Catch)

# add_catch2_tests(<target> [WORKING_DIRECTORY <dir>])
#
# Registers every TEST_CASE in <target> as its own ctest entry via Catch2's
# own catch_discover_tests(), instead of one entry for the whole binary.
function(add_catch2_tests TARGET)
    cmake_parse_arguments(ARGS "" "WORKING_DIRECTORY" "" ${ARGN})
    if(NOT ARGS_WORKING_DIRECTORY)
        set(ARGS_WORKING_DIRECTORY "$<TARGET_FILE_DIR:${TARGET}>")
    endif()
    catch_discover_tests(${TARGET} WORKING_DIRECTORY "${ARGS_WORKING_DIRECTORY}")
endfunction()

# discover_catch2_tests(
#     ROOT <dir>
#     OUTPUT_ROOT <dir>
#     KINDS <names...>
#     [SHARED <dirs...>]
#     [LINK_MATCH <regex>]
#     [LINK_DEFAULT <targets...>]
#     [OUT_TARGETS <var>]
# )
#
# Scans ROOT for directories whose name is one of KINDS (e.g. unit,
# integration), wherever they occur, at whatever depth. For each one found
# (first match along a given path wins, so a KINDS-named directory nested
# inside another is absorbed, not treated as its own boundary), builds one
# Catch2 executable from every .cpp recursively beneath it -- so sources
# mirroring C++ namespaces under that directory stay in one binary rather
# than each becoming its own.
#
# SHARED names directories, relative to ROOT, whose .cpp files (recursively)
# are compiled into every discovered kind's executable, not just one -- for
# test support code (a fixture type, say) more than one kind needs, which
# can't otherwise cross between kinds' separate executables. Every
# executable also gets ROOT itself as an include directory, so a test file
# can reach a shared header by its path relative to ROOT regardless of how
# deep the including file sits.
#
# The executable is named after its path relative to ROOT with '/' -> '_',
# linked against Catch2 plus (if LINK_MATCH matches that relative path)
# ${CMAKE_MATCH_1} from it, else LINK_DEFAULT if given. Its binary is placed
# under OUTPUT_ROOT at that same relative path, and it's registered with
# add_catch2_tests(). Matching target names are appended to OUT_TARGETS.
function(discover_catch2_tests)
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
        target_link_libraries(${TARGET_NAME} PRIVATE Catch2::Catch2WithMain)

        if(ARGS_LINK_MATCH AND "${KIND_REL_DIR}" MATCHES "${ARGS_LINK_MATCH}")
            target_link_libraries(${TARGET_NAME} PRIVATE ${CMAKE_MATCH_1})
        elseif(ARGS_LINK_DEFAULT)
            target_link_libraries(${TARGET_NAME} PRIVATE ${ARGS_LINK_DEFAULT})
        endif()

        set_target_properties(${TARGET_NAME} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY "${ARGS_OUTPUT_ROOT}/${KIND_REL_DIR}")

        add_catch2_tests(${TARGET_NAME})
        list(APPEND RESULT_TARGETS ${TARGET_NAME})
    endforeach()

    if(ARGS_OUT_TARGETS)
        set(${ARGS_OUT_TARGETS} ${RESULT_TARGETS} PARENT_SCOPE)
    endif()
endfunction()
