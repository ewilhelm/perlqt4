include_directories( ${CMAKE_SOURCE_DIR}/smoke ${PERL_INCLUDE_PATH} )
include_directories( ${QT_INCLUDES} )

# Run doxsubpp.pl to run xsubpp on Qt.xs
add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/Qt.c
                   COMMAND ${PERL_EXECUTABLE} ARGS ${CMAKE_CURRENT_SOURCE_DIR}/doxsubpp.pl ${PERL_EXECUTABLE}
                   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/Qt.xs
                   WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
# Make sure we build Qt.c as c++ code
set(CMAKE_C_COMPILER ${CMAKE_CXX_COMPILER})

set(CMAKE_C_FLAGS ${PERL_CXX_FLAGS})

set(perlqt_LIB_SRCS
    binding.cpp
    handlers.cpp
    marshall_types.cpp
    util.cpp
    Qt.c
)

set(LIBRARY_OUTPUT_PATH ${CMAKE_BINARY_DIR}/perl/blib/arch/auto/Qt)
add_library(perlqt4 SHARED ${perlqt_LIB_SRCS})

target_link_libraries(perlqt4 ${QT_QTCORE_LIBRARY} ${PERL_LIBRARY} ${QT_QTNETWORK_LIBRARY} smokeqt)
set_target_properties(perlqt4 PROPERTIES OUTPUT_NAME "Qt")
set_target_properties(perlqt4 PROPERTIES PREFIX "")

install( TARGETS perlqt4 DESTINATION ${CUSTOM_PERL_SITE_ARCH_DIR}/auto/Qt )
