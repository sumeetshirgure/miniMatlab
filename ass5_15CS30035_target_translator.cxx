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
  
  // Function header
  SymbolTable & rootTable = mic.tables[rootId];
  fout << "\t.text\n"; // Text segment
  fout << "\t.globl\t" << rootTable.name << '\n'; // Make declaration visible to linker
  fout << "\t.type\t" << rootTable.name << ", @function\n"; // Function type declaration
  fout << rootTable.name << ":\n";
  
  // Set up base and stack pointers
  const size_t BP = 6 , SP = 7;
  fout << "\tpushq\t" << Regs[BP][QUAD] << '\n' ;
  fout << "\tmovq\t" << Regs[SP][QUAD]  << " , " << Regs[BP][QUAD] << '\n' ;

  // Align with nearest 16-byte mark
  int frameSize = stack.acR.empty() ? 0 : -stack.acR.back().second ; // last offset
  while( frameSize & 15 ) frameSize += frameSize & -frameSize;
  if( frameSize > 0 )
    fout << "\tsubq\t$" << frameSize << " , " << Regs[SP][QUAD] << '\n';
  
  // Push parameters onto the stack
  const static int argRegs[] = { 5, 4, 3, 2, 8, 9 };
  int stdRegs = 0 , fpRegs = 0 ;
  for( Record & record : stack.acR ) {
    int location = record.second;
    if( location > 0 ) continue; // on caller side of stack
    Symbol & symbol = record.first;
    if( symbol.symType == SymbolType::PARAM ) {
      if( symbol.type == MM_DOUBLE_TYPE ) {
	fout << "\tmovsd\t" << XReg << fpRegs++ << " , " << location << "(%rbp)\n" ;
      } else if( symbol.type == MM_CHAR_TYPE ) {
	fout << "\tmovb\t" << Regs[argRegs[stdRegs++]][BYTE] << " , " << location << "(%rbp)\n" ;
      } else if( symbol.type == MM_INT_TYPE ) {
	fout << "\tmovl\t" << Regs[argRegs[stdRegs++]][LONG] << " , " << location << "(%rbp)\n" ;
      } else { // poinrix / Matter
	fout << "\tmovq\t" << Regs[argRegs[stdRegs++]][QUAD] << " , " << location << "(%rbp)\n" ;
      }
    }
  }
  
  std::vector<int> marks;
  // Mark potential target instructions of all gotos.
  for(unsigned int index = from + 1; index < to ; index++ ) {
    const Taco & quad = mic.quadArray[index];
    if( quad.isJump() ) {
      marks.emplace_back( atoi(quad.z.c_str()) );
    }
  }

  std::sort( marks.begin() , marks.end() , std::greater<int>() );
  for(unsigned int index = from + 1; index < to ; index++ ) {
    if( not marks.empty() and marks.back() == index ) {
      fout << ".L" << index << ":\n";
      marks.pop_back();
    }
    emitQuadOps( mic.quadArray[index] , stack );
  }
  
  /* TODO : Emit function footer */
  // Deallocate all memory on heap , and leave
  fout << ".L" << to << ":\n";
  fout << "\tleave\n\tret\n" ; // return statement
  fout << "\t.size\t" << rootTable.name << ", .-" << rootTable.name << '\n' ;
  // TODO : fout << "\t.section\t.rodata\n" ; // Dump all constants if non-empty
  
}

void mm_x86_64::emitQuadOps(const Taco & quad , const ActivationRecord & stack) {
  const size_t BP = 6 ;
  switch(quad.opCode) {

    /* Conditional jumps */
  case OP_LT : case OP_LTE : case OP_GT : case OP_GTE : case OP_EQ : case OP_NEQ : {
    std::string regName , lId , rId, movInstr, cmpInstr;

    auto aRef = stack.locMap.find( quad.x );
    if( aRef != stack.locMap.end() ) {
      int pos = aRef->second;
      const Symbol & lhs = stack.acR[pos].first ;
      lId = std::to_string(stack.acR[pos].second) + "(" + Regs[BP][QUAD] + ")" ;
      if( lhs.type == MM_DOUBLE_TYPE ) {
        regName = XReg+"1";
	movInstr = "movsd"; cmpInstr = "ucomisd";
      } else if( lhs.type == MM_CHAR_TYPE ) {
        regName = Regs[1][BYTE];
	movInstr = "movb"; cmpInstr = "cmpb";
      } else if( lhs.type == MM_INT_TYPE ) {
        regName = Regs[1][LONG];
	movInstr = "movl"; cmpInstr = "cmpl";
      }
    } else { // constant literals
      aRef = stack.constMap.find( quad.x );
      int id = aRef->second;
      const Symbol & lhs = stack.toC[id];
      if( lhs.type == MM_DOUBLE_TYPE ) {
	lId = "$.LC"+std::to_string(id)+"(%rip)";
	usedConstants.emplace_back(id);
	regName = XReg+"1";
	movInstr = "movsd"; cmpInstr = "ucomisd";
      } else if( lhs.type == MM_CHAR_TYPE ) {
	lId = "$"+std::to_string( (int) lhs.value.charVal );
	movInstr = "movb"; cmpInstr = "cmpb";
	regName = Regs[1][BYTE];
      } else if( lhs.type == MM_INT_TYPE ) {
	lId = "$"+std::to_string( lhs.value.intVal );
	movInstr = "movl"; cmpInstr = "cmpl";
	regName = Regs[1][LONG];
      }
    }
    // Move first operand to register
    fout << '\t' << movInstr << '\t' << lId << " , " << regName << '\n';
    
    auto bRef = stack.locMap.find( quad.y );
    if( bRef != stack.locMap.end() ) {
      int pos = bRef->second;
      const Symbol & rhs = stack.acR[pos].first ;
      rId = std::to_string(stack.acR[pos].second) + "(" + Regs[BP][QUAD] + ")" ;
    } else { // constant literals
      bRef = stack.constMap.find( quad.y );
      int id = bRef->second;
      const Symbol & rhs = stack.toC[id];
      if( rhs.type == MM_DOUBLE_TYPE )
	rId = "$.LC"+std::to_string(id)+"(%rip)";
      else if( rhs.type == MM_CHAR_TYPE )
	rId = "$"+std::to_string( (int) rhs.value.charVal );
      else if( rhs.type == MM_INT_TYPE )
	rId = "$"+std::to_string( rhs.value.intVal );
    }
    
    fout << '\t' << cmpInstr << '\t' << rId << " , " << regName << "\n\t";
    switch( quad.opCode ) {
    case OP_LT : fout << "jl" ; break;
    case OP_LTE : fout << "jle" ; break;
    case OP_GT : fout << "jg" ; break;
    case OP_GTE : fout << "jge" ; break;
    case OP_EQ : fout << "je" ; break;
    case OP_NEQ : fout << "jne" ; break;
    default : break;
    };
    fout << "\t.L" << quad.z << '\n';
  } break;
  case OP_GOTO : {
    fout << "\tjmp\t.L" << quad.z << '\n';
  } break;
  default: fout << "\t#\t[" << quad << "]\n";
  }
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
    } else { // Align to 8 byte boundary
      calleeOffset &= -8;
      calleeOffset -= symbol.type.getSize();
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
  }
  
  for( int index = 0; index < toC.size() ; index++ ) {
    Symbol & constant = toC[index];
    constMap[constant.id] = index;
  }
  
  params.clear();
  vars.clear();
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
