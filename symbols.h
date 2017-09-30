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

/* Definition of an entry in a symbol table */
class Symbol {

public:
  
  std::string id;
  
  DataType type;

  InitialValue value;

  bool isInitialized;
  
  size_t offset; // offset w.r.t current SymbolTable
  
  size_t child; // address to the possible nested table (all of which are translator object)

  /* Default constructor */
  Symbol ( );
  
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

  std::string name;
  
  /* SymbolTable id of the parent of this table (globalTable has 0) */
  size_t parent;
  
  std::vector<Symbol> table;

  /* Size of all entries in this table */
  size_t offset;

  /* No of parameter entries in the table (in case of functions) */
  size_t params;

  /* Search a symbol by its id
     If it does not exist , throws error.
     Else returns a reference to that symbol.
   */
  Symbol& lookup (const std::string &) ;
  
  /*Create a symbol by its id and datatype
    Throws error if it exists in table.
    If not , returns a dummy symbol which must be initialized by the caller.
  */
  Symbol& lookup (const std::string &, DataType &) ;
  
  // construct ST
  SymbolTable(size_t,const std::string&);
  
  virtual ~SymbolTable() ;
};

/* Print the symbol table */
std::ostream& operator<<(std::ostream&, SymbolTable &);

#endif /* ! MM_SYMBOLS_H */
