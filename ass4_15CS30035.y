/* -*- C++  LALR1 Parser specification -*- */
%skeleton "lalr1.cc"
%require "3.0.4"
%defines
%define parser_class_name {mm_parser};

/* Generate token constructors */
%define api.token.constructor;

/* Use C++ variant semantic values */
%define api.value.type variant;
%define parse.assert;

%code requires {
#include <string>
  class mm_translator;
 }

/* A translator object is used to construct its parser. */
%param {mm_translator &translator};

%code {
  /* Include translator definitions completely */
#include "ass4_15CS30035_translator.h"
 }

/* Enable bison location tracking */
%locations;

%initial-action{
  @$.initialize( &translator.file );
 }

/* Enable verobse parse tracing */
%define parse.trace
%define parse.error verbose

/* Prefix all token constants with TOK_ */
%define api.token.prefix {TOK_};

/* Token definitions */
%token
END 0 "EOF"
MM_IF "if"
MM_ELSE "else"
MM_DO "do"
MM_WHILE "while"
MM_FOR "for"
MM_RETURN "return"
MM_VOID "void"
MM_CHAR "char"
MM_INT "int"
MM_DOUBLE "double"
MM_MATRIX "Matrix"

LBRACE "{"
RBRACE "}"
LBOX "["
RBOX "]"
LBRACKET "("
RBRACKET ")"

INC "++"
DEC "--"
SHL "<<"
SHR ">>"
AND "&&"
OR "||"
TRANSPOSE ".'"

AMPERSAND "&"
CARET "^"
BAR "|"
NOT "!"

STAR "*"
PLUS "+"
MINUS "-"
SLASH "/"
TILDE "~"
PERCENT "%"
ASSGN "="

LT "<"
GT ">"
LTE "<="
GTE ">="
EQUAL "=="
NEQ "!="

QMARK "?"
COLON ":"
SEMICOLON ";"
COMMA ","
;

%token <std::string> IDENTIFIER STRING_LITERAL CHARACTER_CONSTANT ;

/* Non-terminal definitions */
%type <int>
translation_unit
;

/* Parse debugger */
%printer { yyoutput << $$ ; } <int> ;
%printer { yyoutput << $$ ; } <std::string> ;

/* TODO : Write grammar rules . */

%%

%start translation_unit;

translation_unit : %empty { };

%%
;

/* Bison parser error . Sends a message to the translator. Aborts any further parsing. */
void yy::mm_parser::error (const location_type& loc,const std::string &msg) {
  translator.error(loc,msg);
  throw syntax_error(loc,msg);
}
