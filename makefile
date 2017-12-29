generator = x86_64gen.cc
translator_defns = translator.cc quads.cc types.cc symbols.cc expressions.cc
parser_defn = parser.tab.cc
scanner_defn = lex.yy.c
FILES = $(generator) $(translator_defns) $(parser_defn) $(scanner_defn)
FLAGS = -std=c++11 -O2 #-g

all : build mmstd.o clean

build : scanner_files parser_files translator_files quad_files expression_files symbols_files types_files
	@(echo "This may take a few seconds...")
	g++ $(FLAGS) $(FILES) -o ./compile

mmstd.o : mmstd.c
	gcc -c mmstd.c

quad_files : quads.cc quads.hh

expression_files : expressions.cc expressions.hh

symbols_files : symbols.cc symbols.hh

types_files : types.cc types.hh

scanner_files : lex.yy.c

lex.yy.c : translator_files parser_files lexer.l
	flex lexer.l

parser_files : parser.tab.cc

parser.tab.cc : parser.tab.hh

parser.tab.hh : translator_files parser.y
	bison --language=c++ parser.y

translator_files : translator.hh translator.cc

clean : remove_generated_headers remove_tab_files remove_scanner_files remove_garbage

remove_generated_headers :
	rm -f ./location.hh ./position.hh ./stack.hh

remove_tab_files :
	rm -f ./parser.tab.hh ./parser.tab.cc

remove_scanner_files :
	rm -f ./lex.yy.c

remove_garbage :
	rm -f ./*~ ./.*~
