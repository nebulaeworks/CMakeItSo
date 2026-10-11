find_package(Doxygen)
option(BUILD_DOCUMENTATION "Create and install the HTML based API documentation (requires Doxygen)" ${DOXYGEN_FOUND})

if(NOT DEFINED DOXYGEN_OUTPUT_DIR)
    set(DOXYGEN_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
endif()
if(NOT DEFINED DOXYGEN_HTML_OUTPUT)
    set(DOXYGEN_HTML_OUTPUT html)
endif()

if(BUILD_DOCUMENTATION)
    if(NOT DOXYGEN_FOUND)
        message(FATAL_ERROR "Doxygen is needed to build the documentation.")
    endif()

    set(doxyfile_in ${CMAKE_CURRENT_SOURCE_DIR}/conf/Doxyfile.in)
    set(doxyfile ${CMAKE_CURRENT_BINARY_DIR}/conf/Doxyfile)

    configure_file(${doxyfile_in} ${doxyfile} @ONLY)

    add_custom_target(docs
        COMMAND ${DOXYGEN_EXECUTABLE} ${doxyfile}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Generating API documentation with Doxygen"
        VERBATIM)

    #install(DIRECTORY ${DOXYGEN_OUTPUT_DIR}/${DOXYGEN_HTML_OUTPUT} DESTINATION share/doc)

    add_custom_target(
        docserver
        COMMAND python3 -m http.server
                        -d ${DOXYGEN_OUTPUT_DIR}/${DOXYGEN_HTML_OUTPUT}
        COMMENT "Serving Doxygen docs"
        VERBATIM
    )

endif()
