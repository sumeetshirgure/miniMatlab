#include "symbols.h"

Symbol::Symbol ( const Symbol & symbol ){
  id = symbol.id;
  type = symbol.type;
  value = symbol.value;
  isInitialized = symbol.isInitialized;
  offset = symbol.offset;
  child = symbol.child;
}

// Empty symbol
Symbol::Symbol (const std::string & _id, const DataType & _type,size_t _offset) :
  id(_id),type(_type),isInitialized(false),offset(_offset),child(0) { }

// Initialized symbol
Symbol::Symbol (const std::string & _id, const DataType & _type,size_t _offset,InitialValue _value) :
  id(_id),type(_type),value(_value),isInitialized(true),offset(_offset),child(0) { }

Symbol::~Symbol () {
  
}

std::ostream& operator<<(std::ostream& out, Symbol & symbol) {
  out << "$(" << &symbol << ") ";
  out << symbol.id << "\t\t" << symbol.type << "\t\t";
  if( symbol.type == MM_CHAR_TYPE ) out << symbol.value.charVal ;
  else if( symbol.type == MM_INT_TYPE) out << symbol.value.intVal ;
  else if( symbol.type == MM_DOUBLE_TYPE) out << symbol.value.doubleVal ;
  out << "\t\t" << symbol.type.getSize() << "\t\t" << symbol.offset << "\t\t" << symbol.child ;
  return out;
}

std::ostream& operator<<(std::ostream & out, SymbolTable & symbolTable) {
  out << "Table #" << symbolTable.id << std::endl;
  for( int idx = 0; idx < symbolTable.table.size() ; idx++ ) {
    std::cout << symbolTable.table[idx] << std::endl;
  }
  return out;
}

Symbol & SymbolTable::lookup (const std::string & id , DataType & type) {
  for( int idx = 0 ; idx < table.size() ; idx++ ) {
    if( table[idx].id == id ) 
      return table[idx];
  }
  table.emplace_back(Symbol(id,type,offset));
  return table.back();
}

SymbolTable::SymbolTable(size_t _id) :
  id(_id),offset(0) { }

SymbolTable::~SymbolTable() {
  table.clear();
}
