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

/* Include datatype definitions */
#include "types.h"

/* Include symbol definitions */
#include "symbols.h"

/* Include expression definitions */
#include "expressions.h"

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

  // Temporary symbol generation
  int temporaryCount ;
  // generate a temporary and store it in the current table.
  // return the generated symbol's reference
  Symbol & genTemp( DataType & ) ;
  // the symbol table is provided
  Symbol & genTemp( size_t , DataType & ) ;

  // Print all tables
  void printSymbolTable();
  
  // Parsing context information
  /* The global symbol table */
  SymbolTable & globalTable ();
  
  /* Symbol table of the current locality */
  std::vector<SymbolTable> tables;
  std::stack<int> environment;

  // Symbol table management
  /* Pushes a new environment and returns a pointer to it */
  size_t newEnvironment(const std::string&);
  size_t currentEnvironment();
  SymbolTable & currentTable();
  void popEnvironment();
  
  /* DataType of the object/method being declared currently */
  std::stack<DataType> typeContext;
  
  /* std::stack<Symbol> declarationContext ; */
};

#endif /* ! MM_TRANSLATOR_H */
