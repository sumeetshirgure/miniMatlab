%{
#include <string>
#include "ass4_15CS30035_translator.h"
#include "ass4_15CS30035.tab.hh"
  
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

%{
  /* Code run every time the scanner matches a rule. */
#define YY_USER_ACTION scan_loc.columns(yyleng);
%}

%%

%{
  // Code run every time yylex() is called.
  scan_loc.step();
%}

<<EOF>> return yy::mm_parser::make_END(scan_loc);

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
  fclose(yyin);
  return 0;
}
