# Match FlexLexer.h to FLEX_EXECUTABLE so the header matches the flex binary
# generating verilog_lexer.cc (including keg-only or symlinked installs when
# YOSYS_ENABLE_HOMEBREW=OFF). Stage only FlexLexer.h into the build tree so
# unrelated host headers (e.g. /usr/include when cross-compiling) are not added
# to the include search path.
get_filename_component(_flex_bin_dir "${FLEX_EXECUTABLE}" DIRECTORY)
get_filename_component(_flex_prefix "${_flex_bin_dir}" DIRECTORY)
get_filename_component(_flex_real "${FLEX_EXECUTABLE}" REALPATH)
get_filename_component(_flex_real_bin_dir "${_flex_real}" DIRECTORY)
get_filename_component(_flex_real_prefix "${_flex_real_bin_dir}" DIRECTORY)
set(_flex_lexer_h "")
foreach (_flex_inc_dir
	"${_flex_prefix}/include"
	"${_flex_bin_dir}"
	"${_flex_real_prefix}/include"
	"${_flex_real_bin_dir}"
)
	if (EXISTS "${_flex_inc_dir}/FlexLexer.h")
		set(_flex_lexer_h "${_flex_inc_dir}/FlexLexer.h")
		break()
	endif()
endforeach()
if (_flex_lexer_h)
	configure_file(
		"${_flex_lexer_h}"
		"${CMAKE_CURRENT_BINARY_DIR}/flex_include/FlexLexer.h"
		COPYONLY
	)
	set(FLEX_INCLUDE_DIRS "${CMAKE_CURRENT_BINARY_DIR}/flex_include")
elseif (NOT FLEX_INCLUDE_DIRS)
	set(FLEX_INCLUDE_DIRS ${YOSYS_CMAKE_SOURCE_DIR}/libs/flex)
endif()

flex_target(verilog_lexer
	verilog_lexer.l
	verilog_lexer.cc
)
bison_target(verilog_parser
	verilog_parser.y
	verilog_parser.tab.cc
	# (requires CMake 4.0)
	# OPTIONS
	# 	-Wall -Werror
)
yosys_frontend(verilog
  const2ast.cc
	preproc.cc
	preproc.h
	verilog_error.cc
	verilog_error.h
	verilog_frontend.cc
	verilog_frontend.h
	verilog_lexer.h
	verilog_location.h
	${FLEX_verilog_lexer_OUTPUTS}
	${BISON_verilog_parser_OUTPUTS}
	INCLUDE_DIRS
		${FLEX_INCLUDE_DIRS}
	REQUIRES
		sha1
		ast
	PROVIDES
		verilog_defaults
		verilog_defines
		read_verilog_file_list
	ESSENTIAL
)
set_source_files_properties(
	${BISON_verilog_parser_OUTPUT_SOURCE}
	PROPERTIES
		COMPILE_DEFINITIONS -DYYMAXDEPTH=10000000
)
