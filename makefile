translator_defns = ass5_15CS30035_translator.cxx quads.cc types.cc symbols.cc expressions.cc
parser_defn = ass5_15CS30035.tab.cc
scanner_defn = lex.yy.c
FILES = $(translator_defns) $(parser_defn) $(scanner_defn)
FLAGS = -std=c++11 -O2 #-g

all : build clean

build : scanner_files parser_files translator_files quad_files
	g++ $(FLAGS) $(FILES) -o ./translator

quad_files : quads.h quads.cc

scanner_files : lex.yy.c

lex.yy.c : translator_files parser_files ass5_15CS30035.l
	flex ass5_15CS30035.l

parser_files : ass5_15CS30035.tab.cc

ass5_15CS30035.tab.cc : ass5_15CS30035.tab.hh

ass5_15CS30035.tab.hh : translator_files ass5_15CS30035.y
	bison --language=c++ ass5_15CS30035.y

translator_files : ass5_15CS30035_translator.h ass5_15CS30035_translator.cxx

clean : remove_generated_headers remove_tab_files remove_scanner_files remove_garbage

remove_generated_headers :
	rm -f ./location.hh ./position.hh ./stack.hh

remove_tab_files :
	rm -f ./ass5_15CS30035.tab.hh ./ass5_15CS30035.tab.cc

remove_scanner_files :
	rm -f ./lex.yy.c

remove_garbage :
	rm -f ./*~ ./.*~
