#ifndef MM_SYMBOLS_H
#define MM_SYMBOLS_H

#include <iostream>
#include <vector>
#include <string>
#include "types.h"

/* Union for storing initial value of a symbol
   with non-zero size basic datatype only */
union InitialValue {
  char charVal;
  int intVal;
  double doubleVal;
};

/* Forward definition of the symbol table */
class SymbolTable;

/* Definition of an entry in a symbol table */
class Symbol {

public:
  
  std::string id;
  
  DataType type;

  InitialValue value;

  bool isInitialized;
  
  size_t offset; // offset w.r.t current SymbolTable
  
  int child; // address to the possible nested table (all of which are translator object)
  
  Symbol ( const Symbol & );
  
  /* Construct empty symbol */
  Symbol(const std::string&,const DataType &,size_t offset);

  /* Construct and initialize */
  Symbol(const std::string&,const DataType &,size_t offset,InitialValue _value);
  
  virtual ~Symbol() ;
};

/* Print the symbol entry */
std::ostream& operator<<(std::ostream&, Symbol &);

class SymbolTable {
public:
  
  size_t id;
  
  std::vector<Symbol> table;
  
  size_t offset;
  
  // insert symbol into this table
  Symbol & insert(Symbol &) ;
  
  // search a symbol by its (id,type)
  // returns the symbol reference if it exists in table
  // if not , returns a dummy symbol which must be initialized by the caller
  Symbol& lookup (const std::string &, DataType &) ;
  
  // construct ST
  SymbolTable(size_t);
  
  virtual ~SymbolTable() ;
};

/* Print the symbol table */
std::ostream& operator<<(std::ostream&, SymbolTable &);

#endif /* ! MM_SYMBOLS_H */
