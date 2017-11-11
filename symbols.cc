#include "symbols.hh"
#include <iomanip>

Symbol::Symbol ( ) :
  id(""),type(MM_VOID_TYPE),symType(LOCAL),isInitialized(false),isConstant(false),child(0) { }

// Empty symbol
Symbol::Symbol (const std::string & _id, const DataType & _type) :
  id(_id),type(_type),symType(LOCAL),isInitialized(false),isConstant(false),child(0) { }

// Initialized symbol
Symbol::Symbol (const std::string & _id, const DataType & _type,InitialValue _value) :
  id(_id),type(_type),symType(LOCAL),isInitialized(true),isConstant(false),value(_value),child(0) { }

// Dummy symbol
Symbol::Symbol (const std::string & _id, const DataType & _type, const SymbolType & _symType) :
  id(_id),type(_type),symType(_symType),isInitialized(false),isConstant(false),child(0) { }

Symbol::~Symbol () { }

std::ostream& operator<<(std::ostream& out, Symbol & symbol) {
  out << std::setw(30) << symbol.id
      << std::setw(15) << symbol.type ;
  out << std::setw(10);
  if( !symbol.isInitialized ) out << "NULL" ;
  else if( symbol.type == MM_CHAR_TYPE ) out << (int)symbol.value.charVal ;
  else if( symbol.type == MM_INT_TYPE ) out << symbol.value.intVal ;
  else if( symbol.type == MM_DOUBLE_TYPE ) out << symbol.value.doubleVal ;
  else if( symbol.type == MM_STRING_TYPE ) {
    std::string output = "$." + std::to_string(symbol.value.intVal) ;
    out << output;
  }
  else out << "-----" ;
  
  out << std::setw(10);
  if( symbol.symType == LOCAL ) out << "local" ;
  else if( symbol.symType == TEMP ) out << "temp" ;
  else if( symbol.symType == RETVAL ) out << "retval" ;
  else if( symbol.symType == PARAM ) out << "param" ;
  else if( symbol.symType == CONST ) out << "const" ;
  else out << "-----" ;
  
  out << std::setw(10) << symbol.type.getSize()
      << std::setw(10) << symbol.child ;
  return out;
}

std::ostream& operator<<(std::ostream & out, SymbolTable & symbolTable) {
  out << "Table " << symbolTable.name << "(" << symbolTable.id << ")"
      << " , parent = #" << symbolTable.parent
      << " , paramCount = " << symbolTable.params << std::endl;
  for( int idx = 0; idx < symbolTable.table.size() ; idx++ ) {
    out << symbolTable.table[idx] << std::endl;
  }
  return out;
}

SymbolTable::SymbolTable(unsigned int _id,const std::string& _name="") :
  id(_id),name(_name),parent(0),params(0),isDefined(false) { }

SymbolTable::~SymbolTable() {
  table.clear();
}
