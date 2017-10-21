#include "ass4_15CS30035_translator.h"
#include "ass4_15CS30035.tab.hh"
#include <iomanip>

/* Constructor for translator */
mm_translator::mm_translator(const std::string &_file) :
  trace_scan(false) , trace_parse(false) , trace_tacos(false) , file(_file) , auxTable(0,"") {
  int len = file.length();
  if( file == "-" ) { // scanning from stdin
    fout.open("mm.out");
  } else if( len < 3 or file[len-3] != '.' or file[len-2] != 'm' or file[len-1] != 'm' ) {
    std::cerr << "Fatal error : " << _file << " : Not a .mm file" << std::endl; // lol
    throw 1;
  } else {
    std::string outFileName = file.substr(0,file.length()-3) + ".out";
    fout = std::ofstream(outFileName);
  }
  needsDefinition = false;
  parameterDeclaration = false;
  temporaryCount = 0; // initialize tempCount to 0  
  newEnvironment("gST"); // initialize global table
  scopePrefix = "::";
  globalTable().parent = 0;
  stringTable.emplace_back("");
}

/* Destructor for translator */
mm_translator::~mm_translator() {
  fout.close();
  tables.clear();
  while( not environment.empty() ) environment.pop();
}

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
    fout << std::setw(5) << idx << "\t\t" << quadArray[idx] << std::endl;
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
    fout << tables[i] << std::endl;
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

/**************************************************/

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
      int result;
      try {
	mm_translator translator(cmd);
	translator.trace_parse = trace_parse;
	translator.trace_scan = trace_scan;
	translator.trace_tacos = trace_tacos;
	
	result = translator.translate();
	
	if(result != 0) cerr << cmd << " : Translation failed" << endl;
	else {
	  translator.fout << cmd << " : Translated code :" << endl;
	  translator.fout << "3 Address codes :" << endl;
	  translator.printQuadArray();
	  
	  translator.fout << endl;
	  for(int i=0;i<100;i++)translator.fout<<'-';
	  
	  translator.fout << endl;
	  translator.fout << endl << "Symbol tables : " << endl;
	  translator.printSymbolTable();
	  
	  for(int i=0;i<100;i++)translator.fout<<'-';
	  translator.fout << endl;
	  translator.fout << endl << "String table : " << endl;
	  for(int i = 1 ; i < translator.stringTable.size() ; i++ )
	    translator.fout << i << " : " << translator.stringTable[i] << endl;
	  translator.fout << endl;
	  
	  for(int i=0;i<100;i++)translator.fout<<'*';
	  translator.fout << endl;
	  
	  cout << cmd << " : Translation completed successfully " << endl;
	}
      } catch ( ... ) { } // "fatal" errors
      
    }
  }
  
  return 0;
}
