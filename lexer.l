%{
#include <string>
#include <climits>
#include "translator.hh"
#include "parser.tab.hh"
  
  // Work around an incompatibility in flex (at least versions
  // 2.5.31 through 2.5.33): it generates code that does
  // not conform to C89.  See Debian bug 333231
  // <http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=333231>.
#undef yywrap
#define yywrap() 1

static yy::location scan_loc;
%}

%option noyywrap nounput batch debug noinput

/* Token patterns */
identifier [_[:alpha:]][_[:alnum:]]*

integer_constant [1-9][0-9]*

digit_sequence [[:digit:]]+
sign [+-]
exponent_part [eE]{sign}?{digit_sequence}
fractional_constant ({digit_sequence}?"."{digit_sequence})|({digit_sequence}".")
floating_const ({fractional_constant}{exponent_part}?)|({digit_sequence}{exponent_part})

escape_sequence "\\'"|"\\\""|"\\?"|"\\\\"|"\\a"|"\\b"|"\\f"|"\\n"|"\\r"|"\\t"|"\\v"

c_char [^\\\'\n]|{escape_sequence}
c_char_sequence {c_char}+
character_constant \'{c_char_sequence}\'

s_char [^\"\\\n]|{escape_sequence}
string_literal "\""{s_char}+"\""

zero_constant "0"

%x multicomment
%x comment

%{
  /* Code run every time the scanner matches a rule. */
#define YY_USER_ACTION scan_loc.columns(yyleng);
%}

%%

%{
  // Code run every time yylex() is called.
  scan_loc.step();
%}

[[:blank:]]+ { scan_loc.step(); }
[\n]+ { scan_loc.lines(yyleng); scan_loc.step(); }

"/*" BEGIN(multicomment);
<multicomment>[^*\n]*	   {scan_loc.step();}
<multicomment>"*"+[^*/\n]* {scan_loc.step();}
<multicomment>\n           { scan_loc.lines(1);scan_loc.step(); }
<multicomment>"*"+"/"	   BEGIN(INITIAL);

"//" BEGIN(comment);
<comment>[^\n]* scan_loc.step(); /* eat until new line */
<comment>"\n" { scan_loc.lines(1); scan_loc.step() ; BEGIN(INITIAL); }

"if" return yy::mm_parser::make_MM_IF(scan_loc);
"else" return yy::mm_parser::make_MM_ELSE(scan_loc);
"do" return yy::mm_parser::make_MM_DO(scan_loc);
"while" return yy::mm_parser::make_MM_WHILE(scan_loc);
"for" return yy::mm_parser::make_MM_FOR(scan_loc);
"return" return yy::mm_parser::make_MM_RETURN(scan_loc);

"void" return yy::mm_parser::make_MM_VOID(scan_loc);
"char" return yy::mm_parser::make_MM_CHAR(scan_loc);
"int" return yy::mm_parser::make_MM_INT(scan_loc);
"double" return yy::mm_parser::make_MM_DOUBLE(scan_loc);
"Matrix" return yy::mm_parser::make_MM_MATRIX(scan_loc);

{identifier} return yy::mm_parser::make_IDENTIFIER(yytext,scan_loc);

{string_literal} return yy::mm_parser::make_STRING_LITERAL(yytext,scan_loc);

{character_constant} {
  char ret = yytext[0];
  // "\\'"|"\\\""|"\\?"|"\\\\"|"\\a"|"\\b"|"\\f"|"\\n"|"\\r"|"\\t"|"\\v"
  if( yytext[1] == '\\' ) {
    if( yyleng > 4 ) {
      translator.error (scan_loc, "Warning : Improper character constant." );
    }
    switch( yytext[2] ) {
    case '\'': ret = '\'';break;
    case '"': ret = '"';break;
    case '?': ret = '?';break;
    case '\\': ret = '\\';break;
    case 'a': ret = '\a';break;
    case 'b': ret = '\b';break;
    case 'f': ret = '\f';break;
    case 'n': ret = '\n';break;
    case 'r': ret = '\r';break;
    case 't': ret = '\t';break;
    case 'v': ret = '\v';break;
    default : ret = '\0';
    }
  } else {
    if( yyleng > 3 ) {
      translator.error (scan_loc, "Warning : Improper character constant." );
    }
    ret = yytext[1];
  }
  return yy::mm_parser::make_CHARACTER_CONSTANT(ret,scan_loc);
}

{integer_constant}|{zero_constant} {
  long val = strtol(yytext,NULL,10);
  if( val < INT_MIN or val > INT_MAX or errno == ERANGE ){
    translator.error(scan_loc,"Warning : Integer constant out of range.");
  }
  return yy::mm_parser::make_INTEGER_CONSTANT(val,scan_loc);
};

{floating_const} {
  double val = strtod(yytext,NULL);
  if( errno == ERANGE ){
    translator.error(scan_loc,"Warning : Floating constant out of range.");
  }
  return yy::mm_parser::make_FLOATING_CONSTANT(val,scan_loc);
};

"{" return yy::mm_parser::make_LBRACE(scan_loc);
"}" return yy::mm_parser::make_RBRACE(scan_loc);
"[" return yy::mm_parser::make_LBOX(scan_loc);
"]" return yy::mm_parser::make_RBOX(scan_loc);
"(" return yy::mm_parser::make_LBRACKET(scan_loc);
")" return yy::mm_parser::make_RBRACKET(scan_loc);

"++" return yy::mm_parser::make_INC(scan_loc);
"--" return yy::mm_parser::make_DEC(scan_loc);
"<<" return yy::mm_parser::make_SHL(scan_loc);
">>" return yy::mm_parser::make_SHR(scan_loc);

"&&" return yy::mm_parser::make_AND(scan_loc);
"||" return yy::mm_parser::make_OR(scan_loc);
".'" return yy::mm_parser::make_TRANSPOSE(scan_loc);

"&" return yy::mm_parser::make_AMPERSAND(scan_loc);
"^" return yy::mm_parser::make_CARET(scan_loc);
"|" return yy::mm_parser::make_BAR(scan_loc);
"!" return yy::mm_parser::make_NOT(scan_loc);

"*" return yy::mm_parser::make_STAR(scan_loc);
"+" return yy::mm_parser::make_PLUS(scan_loc);
"-" return yy::mm_parser::make_MINUS(scan_loc);
"/" return yy::mm_parser::make_SLASH(scan_loc);
"~" return yy::mm_parser::make_TILDE(scan_loc);
"%" return yy::mm_parser::make_PERCENT(scan_loc);
"=" return yy::mm_parser::make_ASSGN(scan_loc);

"<" return yy::mm_parser::make_LT(scan_loc);
">" return yy::mm_parser::make_GT(scan_loc);
"<=" return yy::mm_parser::make_LTE(scan_loc);
">=" return yy::mm_parser::make_GTE(scan_loc);
"==" return yy::mm_parser::make_EQUAL(scan_loc);
"!=" return yy::mm_parser::make_NEQ(scan_loc);

"?" return yy::mm_parser::make_QMARK(scan_loc);
":" return yy::mm_parser::make_COLON(scan_loc);
";" return yy::mm_parser::make_SEMICOLON(scan_loc);
"," return yy::mm_parser::make_COMMA(scan_loc);

<comment,multicomment><<EOF>> {
  BEGIN(INITIAL);
  std::string err = "EOF encountered inside comment" ;
  throw yy::mm_parser::syntax_error(scan_loc , err);
}

<<EOF>> return yy::mm_parser::make_END(scan_loc);

. {
  std::string err = "Lexical error `" ;
  err += yytext; err += "'";
  throw yy::mm_parser::syntax_error(scan_loc , err);
  }

%%
;

/* Implement translator's scanner handlers */

/**
   begin_scan opens the requested file. If it does not exist , an error is generated.
   Returns 1 in case of any error, 0 otherwise.
 */
int mm_translator::begin_scan() {
  yy_flex_debug = trace_scan;
  if( file.empty() || file == "-" ) {// scan from stdin
    yyin = stdin;
  }else if(! (yyin = fopen( file.c_str() , "r" ) ) ){
    this->error( "Could not open : " + file + " : " + strerror(errno) );
    return 1;
  }
  /* Reset scanner to beginning of new file */
  YY_NEW_FILE;
  return 0;
}

/* Closes the stream. Always returns 0. */
int mm_translator::end_scan() {
  if(yyin)
    fclose(yyin);
  return 0;
}
