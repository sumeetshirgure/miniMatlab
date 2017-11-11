#include "translator.hh"
#include "parser.tab.hh"
#include <iomanip>

/* Constructor for translator */
mm_translator::mm_translator(const std::string &_file) :
  trace_scan(false) , trace_parse(false) , trace_tacos(false) , file(_file) , auxTable(0,"") , fout(std::cout) {
  needsDefinition = false;
  parameterDeclaration = false;
  temporaryCount = 0; // initialize tempCount to 0  
  newEnvironment("gST"); // initialize global table
  scopePrefix = "::";
  globalTable().parent = 0;
  stringTable.emplace_back("");
}

/* Destructor for translator */
mm_translator::~mm_translator() { }

/**
 * Translate file
 * Returns 1 in case of any syntax error after reporting it to error stream.
 * Returns 0 if translation completes succesfully.
 */
int mm_translator::translate() {
  
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
    fout << std::setw(5) << idx << "\t\t" << quadArray[idx] << '\n';
  }
}

unsigned int mm_translator::nextInstruction() {
  return quadArray.size();
}

SymbolTable & mm_translator::globalTable() {
  return tables[0];
}

SymbolRef mm_translator::lookup(const std::string & id) {
  auto it = idMap.find( id );
  if( it == idMap.end() ) throw 1;
  return it->second;
}

SymbolRef mm_translator::createSymbol(const std::string & id,DataType & dataType,const SymbolType & symbolType) {
  return createSymbol(currentEnvironment(),id,dataType,symbolType);
}

SymbolRef mm_translator::createSymbol(unsigned int env,const std::string & id,DataType & dataType,const SymbolType & symbolType) {
  auto it = idMap.find( id );
  if( it != idMap.end() ) throw 1;
  tables[env].table.emplace_back(Symbol(id,dataType,symbolType));
  SymbolRef ret = std::make_pair( env , tables[env].table.size() - 1 );
  idMap[id] = ret;
  return ret;
}

unsigned int mm_translator::newEnvironment(const std::string &name="") {
  unsigned int idx = tables.size();
  environment.push(idx);// push the address to new symbol table
  tables.push_back(SymbolTable(idx,name));
  scopePrefix += name + "::";
  return idx;
}

unsigned int mm_translator::currentEnvironment() {
  return environment.top();
}

SymbolTable & mm_translator::currentTable() {
  return tables[environment.top()];
}

void mm_translator::pushEnvironment(unsigned int envId) {
  environment.push(envId);
  std::string name = currentTable().name;
  scopePrefix += name + "::";
}

void mm_translator::popEnvironment() {
  unsigned int curLength = currentTable().name.length();
  scopePrefix = scopePrefix.substr(0,scopePrefix.length() - curLength - 2);
  environment.pop();
}

Symbol & mm_translator::getSymbol(SymbolRef ref) {
  return tables[ref.first].table[ref.second];
}

// returns if expression is a programmer written symbol reference
bool mm_translator::isSimpleReference(Expression & expr) {
  return expr.isReference and expr.symbol == expr.auxSymbol;
}

// returns if expression points to some address
bool mm_translator::isPointerReference(Expression &expr) {
  DataType baseType = getSymbol(expr.symbol).type, auxType = getSymbol(expr.auxSymbol).type;
  baseType.pointers++;
  return expr.isReference and baseType == auxType;
}

// returns if expression refers to some element of some matrix
bool mm_translator::isMatrixReference(Expression &expr) {
  DataType baseType = getSymbol(expr.symbol).type, auxType = getSymbol(expr.auxSymbol).type;
  return expr.isReference and baseType.isMatrix() and (auxType == MM_INT_TYPE);
}

// returns if expression refers to some matrix
bool mm_translator::isMatrixOperand(Expression &expr) {
  DataType baseType = getSymbol(expr.symbol).type, auxType = getSymbol(expr.auxSymbol).type;
  return baseType.isMatrix() and (!expr.isReference or auxType != MM_INT_TYPE);
}

SymbolRef mm_translator::genTemp(DataType & type) {
  std::string tempId = "#" + std::to_string(++temporaryCount);
  /* # so it won't collide with any existing non-temporary entries */
  return createSymbol(tempId,type,SymbolType::TEMP);
}

SymbolRef mm_translator::genTemp(unsigned int idx , DataType & type) {
  std::string tempId = "#" + std::to_string(++temporaryCount);
  /* # so it won't collide with any existing non-temporary entries */
  return createSymbol(idx,tempId,type,SymbolType::TEMP);
}

bool mm_translator::isTemporary(SymbolRef ref) {
  Symbol & symbol = getSymbol(ref);
  return symbol.symType == SymbolType::TEMP;
}

/* Print the entire symbol table */
void mm_translator::printSymbolTable() {
  for( int i = 0; i < tables.size() ; i++ )
    fout << tables[i] << '\n';
}

/* Max type */
DataType mm_translator::maxType(DataType & t1,DataType & t2) {
  if( t1.isPointer() or t1==MM_VOID_TYPE or t1==MM_FUNC_TYPE ) return MM_VOID_TYPE;
  if( t2.isPointer() or t2==MM_VOID_TYPE or t2==MM_FUNC_TYPE ) return MM_VOID_TYPE;
  if( t1 == MM_DOUBLE_TYPE or t2 == MM_DOUBLE_TYPE ) return MM_DOUBLE_TYPE;
  if( t1 == MM_INT_TYPE or t2 == MM_INT_TYPE ) return MM_INT_TYPE;
  if( t1 == MM_CHAR_TYPE or t2 == MM_CHAR_TYPE ) return MM_CHAR_TYPE;
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

void mm_translator::emit_MIC() {
  fout << file << " : Translated code :\n";
  fout << "3 Address codes :\n";
  printQuadArray();
  
  fout << '\n';
  for(int i=0;i<100;i++)fout<<'-';
  
  fout << '\n';
  fout << std::endl << "Symbol tables : \n";
  printSymbolTable();
  
  for(int i=0;i<100;i++)fout<<'-';
  fout << '\n';
  fout << std::endl << "String table : \n";
  for(int i = 1 ; i < stringTable.size() ; i++ )
    fout << i << " : " << stringTable[i] << '\n';
  fout << '\n';
  
  for(int i=0;i<100;i++)fout<<'*';
  fout << '\n';
}

/**************************************************************************************************/
