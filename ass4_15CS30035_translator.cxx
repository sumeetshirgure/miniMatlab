#include "ass4_15CS30035_translator.h"
#include "ass4_15CS30035.tab.hh"

/* Constructor for translator */
mm_translator::mm_translator() :
  trace_scan(false) , trace_parse(false) , trace_tacos(false) {

  parameterDeclaration = false;
  temporaryCount = 0; // initialize tempCount to 0  
  newEnvironment("globalTable"); // initialize global table
  globalTable().parent = 0;
}

/* Destructor for translator */
mm_translator::~mm_translator() {
  tables.clear();
  while( not environment.empty() ) environment.pop();
}

/**
 * Translate file
 * Returns 1 in case of any syntax error after reporting it to error stream.
 * Returns 0 if translation completes succesfully.
 */
int mm_translator::translate(const std::string & _file) {
  file = _file;
  
  if( begin_scan() != 0 ) {
    end_scan();
    return 1;
  }
  
  yy::mm_parser parser(*this);
  
  parser.set_debug_level(trace_parse);

  int result = 0;
  try {
    result = parser.parse();
  } catch ( ... ) {
    result = 1;
  }
  
  end_scan();
  
  return result;
}

void mm_translator::error (const yy::location &loc, const std::string & msg) {
  std::cerr << file << " : " << loc << " : " << msg << std::endl;
}

void mm_translator::error (const std::string &msg) {
  std::cerr << file << " : " << msg << std::endl;
}

void mm_translator::emit (const Taco & taco) {
  if(trace_tacos) {
    std::cerr << "Emitted (" << quadArray.size() << ") :\t" << taco << std::endl;
  }
  quadArray.emplace_back( taco );
}

void mm_translator::printQuadArray () {
  for( int idx=0 ; idx<quadArray.size() ; idx++ ) {
    std::cout << idx << "\t" << quadArray[idx] << std::endl;
  }
}

unsigned int mm_translator::nextInstruction() {
  return quadArray.size();
}

SymbolTable & mm_translator::globalTable() {
  return tables[0];
}

unsigned int mm_translator::newEnvironment(const std::string &name="") {
  unsigned int idx = tables.size();
  environment.push(idx);// push the address to new symbol table
  tables.push_back(SymbolTable(idx,name));
  return idx;
}

unsigned int mm_translator::currentEnvironment() {
  return environment.top();
}

SymbolTable & mm_translator::currentTable() {
  return tables[environment.top()];
}

void mm_translator::popEnvironment() {
  environment.pop();
}

Symbol & mm_translator::getSymbol(SymbolRef ref) {
  return tables[ref.first].table[ref.second];
}

// returns if expression is a programmer written symbol reference
bool mm_translator::isSimpleReference(Expression & expr) {
  return expr.symbol == expr.auxSymbol;
};
  
// returns if expression points to some address
bool mm_translator::isPointerReference(Expression &expr) {
  DataType baseType = getSymbol(expr.symbol).type, auxType = getSymbol(expr.auxSymbol).type;
  baseType.pointers++;
  return baseType == auxType;
};
  
// returns if expression refers to some element of some matrix
bool mm_translator::isMatrixReference(Expression &expr) {
  DataType baseType = getSymbol(expr.symbol).type, auxType = getSymbol(expr.auxSymbol).type;
  return baseType.isMatrix() and (auxType == MM_INT_TYPE);
}

SymbolRef mm_translator::genTemp(DataType & type) {
  std::string tempId = "#" + std::to_string(++temporaryCount);
  /* # so it won't collide with any existing non-temporary entries */
  int idx = currentEnvironment();
  return std::make_pair(idx,tables[idx].lookup(tempId,type,SymbolType::TEMP));
}

SymbolRef mm_translator::genTemp(unsigned int idx , DataType & type) {
  std::string tempId = "#" + std::to_string(++temporaryCount);
  /* # so it won't collide with any existing non-temporary entries */
  return std::make_pair(idx,tables[idx].lookup(tempId,type,SymbolType::TEMP));
}

bool mm_translator::isTemporary(const SymbolRef & ref) {
  Symbol & symbol = getSymbol(ref);
  return symbol.symType == SymbolType::TEMP;
}

void mm_translator::updateSymbolTable(unsigned int tableId) {
  SymbolTable & symbolTable = tables[tableId];
  for(int idx = 0; idx<symbolTable.table.size(); idx++) {
    if( idx + 1 < symbolTable.table.size() ) {
      Symbol & curSymbol = symbolTable.table[idx];
      Symbol & nextSymbol = symbolTable.table[idx+1];
      nextSymbol.offset = curSymbol.offset + curSymbol.type.getSize();
      symbolTable.offset = nextSymbol.offset + nextSymbol.type.getSize();
    }
  }
}

/* Print the entire symbol table */
void mm_translator::printSymbolTable() {
  for( int i = 0; i < tables.size() ; i++ ) {
    std::cout << tables[i] << std::endl;
  }
}

/* Max type */
DataType mm_translator::maxType(DataType & t1,DataType & t2) {
  if( t1.isPointer() or t1==MM_VOID_TYPE or t1==MM_FUNC_TYPE )
    return MM_VOID_TYPE;
  if( t2.isPointer() or t2==MM_VOID_TYPE or t2==MM_FUNC_TYPE )
    return MM_VOID_TYPE;
  
  if( t1 == MM_DOUBLE_TYPE or t2 == MM_DOUBLE_TYPE )
    return MM_DOUBLE_TYPE;
  if( t1 == MM_INT_TYPE or t2 == MM_INT_TYPE )
    return MM_INT_TYPE;
  if( t1 == MM_CHAR_TYPE or t2 == MM_CHAR_TYPE )
    return MM_CHAR_TYPE;
  if( t1 == MM_BOOL_TYPE or t2 == MM_BOOL_TYPE )
    return MM_BOOL_TYPE;
  
  return MM_VOID_TYPE;
}

void mm_translator::patchBack(unsigned int idx,unsigned int address){
  quadArray[idx].z = std::to_string(address);
  if( trace_tacos )
    std::cerr << "Goto @" << idx << " linked to " << address << std::endl;
}

void mm_translator::patchBack(std::list<unsigned int>& quadList,unsigned int address){
  std::string target = std::to_string(address);
  for(std::list<unsigned int>::iterator it=quadList.begin();it!=quadList.end();it++) {
    quadArray[*it].z = target;
    if( trace_tacos )
      std::cerr << "Goto @" << *it << " linked to " << address << std::endl;
  }
}

/* Main translation driver */
int main( int argc , char * argv[] ){
  using namespace std ;
  using namespace yy ;

  if(argc < 2) {
    cerr << "Enter a .mm file to translate" << endl;
    return 1;
  }
  
  bool trace_scan = false , trace_parse = false , trace_tacos = false;
  for(int i=1;i<argc;i++){
    string cmd = string(argv[i]);
    if(cmd == "--trace-scan") {
      trace_scan = true;
    } else if(cmd == "--trace-parse") {
      trace_parse = true;
    } else if(cmd == "--trace-tacos") {
      trace_tacos = true;      
    } else {
      mm_translator translator;
      translator.trace_parse = trace_parse;
      translator.trace_scan = trace_scan;
      translator.trace_tacos = trace_tacos;
      int result = translator.translate(cmd);
      if(result != 0) cout << cmd << " : Translation failed " << endl;
      else {
	cout << "3 Address codes :" << endl;
	translator.printQuadArray();
	cout << endl << "Symbol tables : " << endl;
	translator.printSymbolTable();
	cout << cmd << " : Translation completed successfully " << endl;
      }
    }
  }
  
  return 0;
}
