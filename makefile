translator_defn = ass4_15CS30035_translator.cxx quads.cc types.cc symbols.cc
parser_defn = ass4_15CS30035.tab.cc
scanner_defn = lex.yy.c
FILES = $(translator_defn) $(parser_defn) $(scanner_defn)
FLAGS = -std=c++11 -g

build : scanner_files parser_files translator_files quad_files
	g++ $(FLAGS) $(FILES) -o ./translator

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
