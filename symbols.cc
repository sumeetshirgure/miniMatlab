#include "symbols.h"

Symbol::Symbol ( ) :
  id(""),type(MM_VOID_TYPE),offset(0),isInitialized(false),child(0) { }
// Empty symbol
Symbol::Symbol (const std::string & _id, const DataType & _type,size_t _offset) :
  id(_id),type(_type),offset(_offset),isInitialized(false),child(0) { }

// Initialized symbol
Symbol::Symbol (const std::string & _id, const DataType & _type,size_t _offset,InitialValue _value) :
  id(_id),type(_type),offset(_offset),isInitialized(true),value(_value),child(0) { }

Symbol::~Symbol () {
  
}

std::ostream& operator<<(std::ostream& out, Symbol & symbol) {
  out << "$(" << &symbol << ") ";
  out << symbol.id << "\t\t" << symbol.type << "\t\t";
  if( !symbol.isInitialized ) out << "NULL" ;
  else if( symbol.type == MM_CHAR_TYPE ) out << (int)symbol.value.charVal ;
  else if( symbol.type == MM_INT_TYPE) out << symbol.value.intVal ;
  else if( symbol.type == MM_DOUBLE_TYPE) out << symbol.value.doubleVal ;
  else out << "BadType" ;
  out << "\t\t" << symbol.type.getSize() << "\t\t" << symbol.offset << "\t\t" << symbol.child ;
  return out;
}

std::ostream& operator<<(std::ostream & out, SymbolTable & symbolTable) {
  out << "Table #" << symbolTable.id << " , parent = # " << symbolTable.parent << std::endl;
  for( int idx = 0; idx < symbolTable.table.size() ; idx++ ) {
    std::cout << symbolTable.table[idx] << std::endl;
  }
  return out;
}

Symbol & SymbolTable::lookup (const std::string & id , DataType & type, bool createNew) {
  for( int idx = 0 ; idx < table.size() ; idx++ ) {
    if( table[idx].id == id ) {
      if( createNew ) throw 1;
      return table[idx];
    }
  }
  table.push_back(Symbol(id,type,offset));
  offset += type.getSize(); // 
  return table.back();
}

SymbolTable::SymbolTable(size_t _id) :
  id(_id),offset(0) { }

SymbolTable::~SymbolTable() {
  table.clear();
}
