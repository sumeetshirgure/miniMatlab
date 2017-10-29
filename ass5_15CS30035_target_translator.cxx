#include "ass5_15CS30035_target_translator.h"

mm_x86_64::mm_x86_64 (mm_translator & translator)
  : mic(translator) {
  int len = mic.file.length();
  if( mic.file == "-" ) { // scanning from stdin
    fout.open("mm.asm");
  } else if( len < 3 or mic.file[len-3] != '.' or mic.file[len-2] != 'm' or mic.file[len-1] != 'm' ) {
    std::cerr << "Fatal error : " << mic.file << " : Not a .mm file" << std::endl;
    throw 1;
  } else {
    std::string outFileName = mic.file.substr(0,mic.file.length()-3) + ".asm";
    fout.open(outFileName);
  }
}

mm_x86_64::~mm_x86_64 () {
  fout.close();
}

void mm_x86_64::generateTargetCode() {

  // TODO : Handle global declarations.
  
  std::vector< Taco > & QA = mic.quadArray;
  for(unsigned int addr = 0; addr < QA.size() ; ) {
    if( QA[addr].opCode == OP_FUNC_START ) {
      unsigned int nxtAddr = addr;
      for( ; nxtAddr < QA.size() and QA[nxtAddr].opCode != OP_FUNC_END ; nxtAddr++ ) ;
      std::string funcName = "::" + QA[addr].z;
      SymbolRef funcRef = mic.lookup(funcName);
      unsigned int rootId = mic.getSymbol( funcRef ).child;
      emitFunction(addr , nxtAddr, rootId);
      addr = nxtAddr + 1;
    } else {
      addr++;
    }
  }
  
}

void mm_x86_64::emitFunction(unsigned int from, unsigned int to, unsigned int rootId) {
  // Populate stack
  ActivationRecord stack(mic,rootId);
  
  /* TODO : Emit function header */
  // TODO : Set up base and stack pointers
  // TODO : Push parameters onto the stack
  
  // TODO : emit rtlops
  
  /* TODO : Emit function footer */
  
}

ActivationRecord::ActivationRecord(mm_translator& mic,unsigned int rootId){
  dft(mic,rootId);
  
  // Populate stack
  std::vector< Record > callerStack , calleeStack;
  unsigned int callerOffset = 16 , calleeOffset = 0;
  // (%rsp) contains %rbp and 8(%rsp) contains %rip of caller
  unsigned int stdCount = 0 , xmmCount = 0; // Number of parameters passed through standard / X registers
  for(auto & symbol : params) {
    bool onCallerStack = false;
    if( symbol.type == MM_DOUBLE_TYPE ) {
      if( xmmCount >= 8 ) onCallerStack = true;
    } else {
      if( stdCount >= 6 ) onCallerStack = true;
    }
    if( symbol.type.isIntegerType() ) { // 4 bytes
      if( onCallerStack ) {
	callerStack.emplace_back( symbol , callerOffset );
	callerOffset += 4;
      } else {
	calleeOffset -= 4;
	calleeStack.emplace_back( symbol , calleeOffset );
      }
    } else { // Matrix / Double / any Pointer : 8 bytes
      if( onCallerStack ) {
	// Align to 8-byte boundary
	if( (callerOffset & 7) != 0 ) callerOffset += 4;
	callerStack.emplace_back( symbol , callerOffset );
	callerOffset += 8;
      } else { //
	// Align to 8-byte boundary
	if( (calleeOffset & 7) != 0 ) calleeOffset -= 4;
	calleeOffset -= 8;
	calleeStack.emplace_back( symbol , calleeOffset );
      }
    }
    if( symbol.type == MM_DOUBLE_TYPE ) xmmCount++;
    else stdCount++;
  }

  // Push all variables on stack
  for(auto & symbol : vars) {
    if( symbol.type.isIntegerType() ) { // 4 bytes
      calleeOffset -= 4;
      calleeStack.emplace_back( symbol , calleeOffset );
    } else {
      if( (calleeOffset & 7) != 0 ) calleeOffset -= 4;
      calleeOffset -= 8;
      calleeStack.emplace_back( symbol , calleeOffset );
    }
  }

  std::reverse( callerStack.begin() , callerStack.end() ) ;
  acR.clear() ; std::swap( acR , callerStack );
  acR.insert( acR.end() , calleeStack.begin() , calleeStack.end());
  calleeStack.clear();

  // Construct symbol location map
  for( int index = 0; index < acR.size() ; index++ ) {
    Record & record = acR[index];
    locMap[record.first.id] = index ;
    // std::cerr << record.first << " @ " << record.second << std::endl;
  }
}

ActivationRecord::~ActivationRecord() { }

/* Perform a depth first traversal. */
void ActivationRecord::dft(mm_translator& mic, unsigned int tableId) {
  std::vector< Symbol > & table = mic.tables[tableId].table;
  for(unsigned int idx = 0; idx < table.size() ; idx++ ) {
    Symbol & symbol = table[idx];
    if( symbol.child != 0 ) {
      dft(mic,symbol.child);
    } else if( symbol.symType == SymbolType::RETVAL ) {
      retVal = symbol;
    } else if( symbol.symType == SymbolType::CONST ) {
      toC.emplace_back( symbol );
    } else if( symbol.symType == SymbolType::PARAM ) {
      params.emplace_back( symbol );
    } else { // LOCAL or TEMPorary variables
      vars.emplace_back( symbol );
    }
  }
}

/**************************************************************************************************/

/* Main compilation driver */
int main( int argc , char * argv[] ){
  using namespace std ;
  using namespace yy ;
  
  bool trace_scan = false , trace_parse = false
    , trace_tacos = false , emit_mic = false;
  
  for(int i=1;i<argc;i++){
    string cmd = string(argv[i]);
    if(cmd == "--trace-scan") {
      trace_scan = true;
    } else if(cmd == "--trace-parse") {
      trace_parse = true;
    } else if(cmd == "--trace-tacos") {
      trace_tacos = true;
    } else if(cmd == "--emit-mic") {
      emit_mic = true;
    } else {
      int result;
      
      try {
	mm_translator translator(cmd);
	translator.trace_parse = trace_parse;
	translator.trace_scan = trace_scan;
	translator.trace_tacos = trace_tacos;
	
	result = translator.translate();
	
	if(result != 0) {
	  throw 1;
	}
        
	if( emit_mic ) {
	  translator.emit_MIC();
	  cout << cmd << " : Translation completed successfully " << endl;
	}
	
	/* Construct a target code generator */
	mm_x86_64 generator(translator);
	generator.generateTargetCode();
      } catch ( ... ) {
	cerr << cmd << " : Compilation failed" << endl;
      }
      
    }
  }
  
  return 0;
}
