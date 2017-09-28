#include "symbols.h"

Symbol::Symbol(const Symbol & symbol) {
  this->id = symbol.id;
  this->type = symbol.type;
  this->offset = 0;
  this->child = NULL;
}

Symbol::Symbol (const std::string & _id, const DataType & _type,size_t _offset) :
  id(_id),type(_type),offset(_offset),child(NULL) {
  
}
Symbol::~Symbol () {
  child = NULL;
  
}

std::ostream& operator<<(std::ostream& out,const Symbol & symbol) {
  return out;
}

std::ostream& operator<<(std::ostream& out,const SymbolTable & symbolTable) {
  
  return out;
}

SymbolTable::SymbolTable() :
  offset(0),parent(NULL){ }

SymbolTable::~SymbolTable() {
  parent = NULL;
  
}
