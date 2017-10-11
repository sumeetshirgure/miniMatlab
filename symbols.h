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
};

/* Definition of an entry in a symbol table */
class Symbol {

public:
  
  /* Identifier for this symbol. Unique in its scope. */
  std::string id;
  
  /* Datatype of this symbol. */
  DataType type;
  
  /* Symbol entry type. */
  SymbolType symType;
  
  /* Initialized flag, and value if applicable. */
  bool isInitialized;
  InitialValue value;

  /* Constant flag.
     Flags wether this symbol is a constant or an expression made
     solely by programmer written constants. 
     Even if isConstant is high , symbol's value is still stored in initial value. */
  bool isConstant;
  
  /* Offset w.r.t current SymbolTable */
  unsigned int offset;
  
  /* Address of the possible nested table (all of which are translator objects) */
  unsigned int child;
  
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

  /* Index in translator's list of tables. */
  unsigned int id;

  /* Name of the symbol table. */
  std::string name;
  
  /* SymbolTable id of the parent of this table (globalTable has 0) */
  unsigned int parent;

  /* The table itself. */
  std::vector<Symbol> table;
  
  /* Size of all entries in this table */
  unsigned int offset;

  /* No of parameter entries in the table (in case of functions) */
  unsigned int params;
  
  /* Search a symbol by its id
     If it does not exist , throws error.
     Else returns index of that symbol in the table. */
  unsigned int lookup (const std::string &) ;
  
  /*Create a symbol by its id and datatype
    Throws error if it exists in table.
    If not , returns index of a dummy symbol which must be initialized by the caller. */
  unsigned int lookup (const std::string &, DataType &, const SymbolType &) ;
  
  // construct ST
  SymbolTable(unsigned int,const std::string&);
  
  virtual ~SymbolTable() ;
};

/* Print the symbol table */
std::ostream& operator<<(std::ostream&, SymbolTable &);

#endif /* ! MM_SYMBOLS_H */
