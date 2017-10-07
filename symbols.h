#ifndef MM_SYMBOLS_H
#define MM_SYMBOLS_H

#include <iostream>
#include <vector>
#include <string>
#include "types.h"

/* Typedef for storing "pointer" to symbol entry 
   first value is table index and second value is entry index in table.
 */
typedef std::pair<unsigned int,unsigned int> SymbolRef;

/* Union for storing initial value of a symbol
   with non-zero size basic datatype only */
union InitialValue {
  char charVal;
  int intVal;
  double doubleVal;
};

enum SymbolType {
  LOCAL = 0 , // local variable name
  TEMP ,      // compiler generated temporary
  RETVAL ,    // first symbol of a function's symbol table
  PARAM ,     // parameter type symbol
  LINK        // link to dynamically allocated memory
};

/* Definition of an entry in a symbol table */
class Symbol {

public:
  
  std::string id;
  
  DataType type;

  SymbolType symType;

  InitialValue value;

  bool isInitialized;
  
  unsigned int offset; // offset w.r.t current SymbolTable
  
  unsigned int child; // address to the possible nested table (all of which are translator object)

  /* Default constructor */
  Symbol ( );
  
  /* Construct empty symbol */
  Symbol(const std::string&,const DataType &);

  /* Construct and initialize */
  Symbol(const std::string&,const DataType &,InitialValue);

  /* Dummy symbol */
  Symbol(const std::string&,const DataType &,const SymbolType &);
  
  virtual ~Symbol() ;
};

/* Print the symbol entry */
std::ostream& operator<<(std::ostream&, Symbol &);

class SymbolTable {
public:
  
  unsigned int id;

  std::string name;
  
  /* SymbolTable id of the parent of this table (globalTable has 0) */
  unsigned int parent;
  
  std::vector<Symbol> table;

  /* Size of all entries in this table */
  unsigned int offset;

  /* No of parameter entries in the table (in case of functions) */
  unsigned int params;

  /* Search a symbol by its id
     If it does not exist , throws error.
     Else returns index of that symbol in the table.
   */
  unsigned int lookup (const std::string &) ;
  
  /*Create a symbol by its id and datatype
    Throws error if it exists in table.
    If not , returns index of a dummy symbol which must be initialized by the caller.
  */
  unsigned int lookup (const std::string &, DataType &, const SymbolType &) ;
  
  // construct ST
  SymbolTable(unsigned int,const std::string&);
  
  virtual ~SymbolTable() ;
};

/* Print the symbol table */
std::ostream& operator<<(std::ostream&, SymbolTable &);

#endif /* ! MM_SYMBOLS_H */
