#include "symbols.h"

Symbol::Symbol ( ) :
  id(""),type(MM_VOID_TYPE),symType(LOCAL),offset(0),isInitialized(false),child(0) { }

// Empty symbol
Symbol::Symbol (const std::string & _id, const DataType & _type) :
  id(_id),type(_type),symType(LOCAL),offset(0),isInitialized(false),child(0) { }

// Initialized symbol
Symbol::Symbol (const std::string & _id, const DataType & _type,InitialValue _value) :
  id(_id),type(_type),symType(LOCAL),offset(0),isInitialized(true),value(_value),child(0) { }

// Dummy symbol
Symbol::Symbol (const std::string & _id, const DataType & _type, const SymbolType & _symType) :
  id(_id),type(_type),symType(_symType),offset(0),isInitialized(false),child(0) { }

Symbol::~Symbol () { }

std::ostream& operator<<(std::ostream& out, Symbol & symbol) {
  out << symbol.id << "\t\t" << symbol.type << "\t\t";
  if( !symbol.isInitialized ) out << "NULL" ;
  else if( symbol.type == MM_CHAR_TYPE ) out << (int)symbol.value.charVal ;
  else if( symbol.type == MM_INT_TYPE) out << symbol.value.intVal ;
  else if( symbol.type == MM_DOUBLE_TYPE) out << symbol.value.doubleVal ;
  else out << "---" ;
  out << "\t\t";
  if( symbol.symType == LOCAL ) out << "local" ;
  else if( symbol.symType == TEMP ) out << "temp" ;
  else if( symbol.symType == RETVAL ) out << "retval" ;
  else if( symbol.symType == PARAM ) out << "param" ;
  else if( symbol.symType == LINK ) out << "link" ;
  else out << "---" ;
  out << "\t\t" << symbol.type.getSize() << "\t\t" << symbol.offset << "\t\t" << symbol.child ;
  return out;
}

std::ostream& operator<<(std::ostream & out, SymbolTable & symbolTable) {
  out << "Table " << symbolTable.name << "(" << symbolTable.id << ")"
      << " , parent = #" << symbolTable.parent
      << " , paramCount = " << symbolTable.params << std::endl;
  for( int idx = 0; idx < symbolTable.table.size() ; idx++ ) {
    std::cout << symbolTable.table[idx] << std::endl;
  }
  return out;
}

SymbolTable::SymbolTable(unsigned int _id,const std::string& _name="") :
  id(_id),name(_name),offset(0),params(0) { }

SymbolTable::~SymbolTable() {
  table.clear();
}

unsigned int SymbolTable::lookup (const std::string & id) {
  for( int idx = 0 ; idx < table.size() ; idx++ ) {
    if( table[idx].id == id ) {
      return idx;
    }
  }
  throw 1;
}

unsigned int SymbolTable::lookup (const std::string & id , DataType & _dataType, const SymbolType & _type) {
  for( int idx = 0 ; idx < table.size() ; idx++ ) {
    if( table[idx].id == id ) {
      throw 1;
    }
  }
  table.push_back(Symbol(id,_dataType,_type));
  table.back().offset = offset;
  offset += _dataType.getSize();
  return table.size()-1;
}
