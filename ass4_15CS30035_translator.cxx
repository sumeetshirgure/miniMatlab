#include "ass4_15CS30035_translator.h"
#include "ass4_15CS30035.tab.hh"

/* Constructor for translator */
mm_translator::mm_translator() :
  trace_scan(false) , trace_parse(false) {

  temporaryCount = 0; // initialize tempCount to 0  
  newEnvironment(); // initialize global table
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
  quadArray.emplace_back( taco );
}

void mm_translator::printQuadArray () {
  for( int idx=0 ; idx<quadArray.size() ; idx++ ) {
    std::cout << quadArray[idx] << std::endl;
  }
}

size_t mm_translator::nextInstruction() {
  return quadArray.size();
}

SymbolTable & mm_translator::globalTable() {
  return tables[0];
}

size_t mm_translator::newEnvironment() {
  size_t idx = tables.size();
  environment.push(idx);// push the address to new symbol table
  tables.push_back(SymbolTable(idx));
  return idx;
}

size_t mm_translator::currentEnvironment() {
  return environment.top();
}

void mm_translator::popEnvironment() {
  environment.pop();
}

Symbol & mm_translator::genTemp(size_t idx , DataType & type) {
  std::string tempId = "t#" + std::to_string(++temporaryCount);
  /* # so it won't collide with any existing non-temporary entries */
  return tables[idx].lookup(tempId,type,true);
}

/* Print the entire symbol table */
void mm_translator::printSymbolTable() {
  for( int i = 0; i < tables.size() ; i++ ) {
    std::cout << tables[i] << std::endl;
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
  
  bool trace_scan = false , trace_parse = false;
  for(int i=1;i<argc;i++){
    string cmd = string(argv[i]);
    if(cmd == "--trace-scan") {
      trace_scan = true;
    } else if(cmd == "--trace-parse") {
      trace_parse = true;
    } else {
      mm_translator translator;
      translator.trace_parse = trace_parse;
      translator.trace_scan = trace_scan;
      int result = translator.translate(cmd);
      if(result != 0) cout << cmd << " : Translation failed " << endl;
      else {
	translator.printQuadArray();
	cout << endl;
	translator.printSymbolTable();
	cout << cmd << " : Translation completed successfully " << endl;
      }
    }
  }
  
  return 0;
}
