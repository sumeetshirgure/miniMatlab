trans_dfn = ass4_15CS30035_translator.cxx quads.cc symbols.cc
parser_dfn = ass4_15CS30035.tab.cc
scanner_dfn = lex.yy.c
FILES = $(trans_dfn) $(parser_dfn) $(scanner_dfn) $(quad_dfn) $

build : scanner_files parser_files translator_files quad_files
	g++ -std=c++11 $(FILES) -o ./translator
	make clean

quad_files : quads.h quads.cc

scanner_files : lex.yy.c

lex.yy.c : translator_files parser_files ass4_15CS30035.l
	flex ass4_15CS30035.l

parser_files : ass4_15CS30035.tab.cc

ass4_15CS30035.tab.cc : ass4_15CS30035.tab.hh

ass4_15CS30035.tab.hh : translator_files ass4_15CS30035.y
	bison --language=c++ ass4_15CS30035.y

translator_files : ass4_15CS30035_translator.h ass4_15CS30035_translator.cxx

clean : remove_generated_headers remove_tab_files remove_scanner_files remove_garbage

remove_generated_headers :
	rm -f ./location.hh ./position.hh ./stack.hh

remove_tab_files :
	rm -f ./ass4_15CS30035.tab.hh ./ass4_15CS30035.tab.cc

remove_scanner_files :
	rm -f ./lex.yy.c

remove_garbage :
	rm -f ./*~ ./.*~
