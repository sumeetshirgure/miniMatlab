#ifndef MM_SYMBOLS_H
#define MM_SYMBOLS_H

#include <iostream>
#include <vector>
#include <string>
#include "types.h"

/* Forward definition of the symbol table */
class SymbolTable;

/* Definition of an entry in a symbol table */
class Symbol {

public:
  
  std::string id;
  
  DataType type;
  
  size_t offset; // offset w.r.t current SymbolTable
  
  SymbolTable * child; // address to the possible nested table
  
  // copy constructor
  Symbol(const Symbol&);
  
  Symbol(const std::string&,const DataType &,size_t offset);
  
  virtual ~Symbol() ;
};

/* Print the symbol entry */
std::ostream& operator<<(std::ostream&,const Symbol &);

class SymbolTable {
public:
  
  std::vector<Symbol> table;
  
  size_t offset;
  
  // insert symbol into this table
  void insert(const Symbol & ) ;
  
  // generate a temporary and store it in the table. return the generated symbol's reference
  Symbol& genTemp() ;
  
  // search a symbol by its id ... trie map ?
  Symbol& lookup (const std::string &) ;

  // address to parent table
  SymbolTable * parent;
  
  // construct ST
  SymbolTable();
  
  virtual ~SymbolTable() ;
};

/* Print the entire symbol table */
std::ostream& operator<<(std::ostream&,const SymbolTable &);


#endif /* ! MM_SYMBOLS_H */
