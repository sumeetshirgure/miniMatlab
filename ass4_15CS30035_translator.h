#ifndef MM_TRANSLATOR_H
#define MM_TRANSLATOR_H

#include <string>
#include <stack>

/* For determining return type of yylex */
#include "ass4_15CS30035.tab.hh"

#define YY_DECL yy::mm_parser::symbol_type yylex(mm_translator& translator)
YY_DECL;

/* Include 3 address code definitions */
#include "quads.h"

/* Include datatype defintions */
#include "types.h"

/* Default datatype constants */
const DataType MM_VOID_TYPE(0,0);
const DataType MM_BOOL_TYPE(0,1); // implicit
const DataType MM_CHAR_TYPE(0,2);
const DataType MM_INT_TYPE(0,3);
const DataType MM_DOUBLE_TYPE(0,4);
const DataType MM_MATRIX_TYPE(0,5);
const DataType MM_FUNC_TYPE(0,6);
const DataType MM_MATRIX_ROW_TYPE(0,7); // implicit

#include "symbols.h"

/**
   Minimatlab translator class. An mm_translator object is used
   to instantiate a translation for every requested file.
*/
class mm_translator {
public:
  
  mm_translator();
  virtual ~mm_translator();
  
  // scanner handlers
  int begin_scan();
  int end_scan();
  bool trace_scan;
  
  // parse handlers
  int translate (const std::string&);
  std::string file;
  bool trace_parse;
  
  // error handlers
  void error(const yy::location&,const std::string&);
  void error(const std::string&);
  
  // Code generation
  std::vector<Taco> quadArray; // Address of a taco is its index in quadArray
  void emit( const Taco & );
  void printQuadArray();
  size_t nextInstruction();

  // Parsing context information
  
  /* DataType of the object/method being declared currently */
  std::stack<DataType> typeContext;

  /* Symbol table of the current locality */
  std::stack<SymbolTable> environment;

  /* The global symbol table */
  SymbolTable globalST;
  
};

#endif /* ! MM_TRANSLATOR_H */
