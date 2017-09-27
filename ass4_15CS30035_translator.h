#ifndef MM_TRANSLATOR_H
#define MM_TRANSLATOR_H

#include <string>
/* include pbds trie */

/* For determining return type of yylex */
#include "ass4_15CS30035.tab.hh"

#define YY_DECL yy::mm_parser::symbol_type yylex(mm_translator& translator)
YY_DECL;
  
/**
   Minimatlab translator class. An mm_translator object is used to instantiate
   a translation for every requested file.
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
    
};

#endif /* ! MM_TRANSLATOR_H */
