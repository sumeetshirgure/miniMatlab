#include "x86_64gen.hh"

mm_x86_64::mm_x86_64 (mm_translator & translator)
  : mic(translator) , fout(std::cout) {
  int len = mic.file.length();
  constIds = 0;
  tempLabels = 0;
}

mm_x86_64::~mm_x86_64 () { }

std::tuple< std::string , DataType >
mm_x86_64::getLocation (const std::string & addr,const ActivationRecord & stack) {
  const size_t BP = 6;
  std::string retId; DataType retType;
  auto ref = stack.locMap.find( addr );
  if( ref != stack.locMap.end() ) {
    int pos = ref->second;
    retId = std::to_string(stack.acR[pos].second) + "(" + Regs[BP][QUAD] + ")" ;
    retType = stack.acR[pos].first.type ;
  } else if( ( ref = stack.constMap.find( addr ) ) != stack.constMap.end() ) { // constant literals
    int id = ref->second;
    const Symbol & sym = stack.toC[id];
    retType = sym.type;
    if( retType == MM_DOUBLE_TYPE ) {
      retId = ".LC"+std::to_string(constIds)+"(%rip)";
      usedConstants.emplace_back(id , constIds++);
    } else if( retType == MM_CHAR_TYPE ) {
      retId = "$"+std::to_string( (int) sym.value.charVal );
    } else if( retType == MM_INT_TYPE ) {
      retId = "$"+std::to_string( sym.value.intVal );
    } else { // string
      retId = "$.LS"+std::to_string( sym.value.intVal );
      usedStrings.emplace_back( sym.value.intVal );
    }
  } else { // global variables
    const Symbol & sym = mic.getSymbol( mic.lookup( addr ) );
    retType = sym.type;
    retId = addr.substr(2,addr.length()-2)+"(%rip)";
  }
  return std::tie( retId , retType );
}

void mm_x86_64::generateTargetCode() {

  // Handle global declarations.
  std::vector< Symbol > & globalTable = mic.globalTable().table;
  std::vector< Taco > & QA = mic.quadArray;
  
  fout << "\t.data\n";
  for(unsigned int index = 0 , addr = 0; index < globalTable.size() ; index++) {
    Symbol & symbol = globalTable[index];
    if( symbol.symType != SymbolType::LOCAL ) continue;
    DataType type = symbol.type ;
    if( type == MM_FUNC_TYPE ) continue;
    std::string sId = symbol.id , name = sId.substr(2,sId.length()-2);
    if( type.isPointer() ) {
      fout << "\t.comm\t" << name << ",8,8\n" ;
    } else if( type == MM_CHAR_TYPE ) {
      if( !symbol.isInitialized ) {
	fout << "\t.comm\t" << name << ",1,1\n" ;
      } else {
	fout << "\t.globl\t" << name
	     << "\n\t.type\t" << name << ", @object"
	     << "\n\t.size\t" << name << ", 1\n"
	     << name << ":\n\t.byte\t" << (int) symbol.value.charVal << '\n';
      }
      for( ; addr < QA.size() ; addr++ ) {
	const Taco & quad = QA[addr];
	if( quad.opCode == OP_DECLARE and quad.z == sId ) break;
      }
    } else if( type == MM_INT_TYPE ) {
      if( !symbol.isInitialized ) {
	fout << "\t.comm\t" << name << ",4,4\n" ;
      } else {
	fout << "\t.globl\t" << name
	     << "\n\t.align\t4"
	     << "\n\t.type\t" << name << ", @object"
	     << "\n\t.size\t" << name << ", 4\n"
	     << name << ":\n\t.long\t" << symbol.value.intVal << '\n';
      }
      for( ; addr < QA.size() ; addr++ ) {
	const Taco & quad = QA[addr];
	if( quad.opCode == OP_DECLARE and quad.z == sId ) break;
      }
    } else if( type == MM_DOUBLE_TYPE ) {
      if( !symbol.isInitialized ) {
	fout << "\t.comm\t" << name << ",8,8\n" ;
      } else {
	int *ptr = (int*) (&symbol.value.doubleVal);
	fout << "\t.globl\t" << name
	     << "\n\t.align\t8"
	     << "\n\t.type\t" << name << ", @object"
	     << "\n\t.size\t" << name << ", 8\n"
	     << name << ":\n\t.long\t" << ptr[0]
	     << "\n\t.long\t" << ptr[1] << '\n';
      }
      for( ; addr < QA.size() ; addr++ ) {
	const Taco & quad = QA[addr];
	if( quad.opCode == OP_DECLARE and quad.z == sId ) break;
      }
    } else { // Matrix
      int remSize = symbol.type.getSize();
      fout << "\t.globl\t" << name
	   << "\n\t.align\t16"
	   << "\n\t.type\t" << name << ", @object"
	   << "\n\t.size\t" << name << ", " << remSize << '\n'
	   << name << ':' ;
      for( ; addr < QA.size() ; addr++ ) {
	const Taco & quad = QA[addr];
	if( quad.opCode == OP_DECLARE and quad.z == sId ) break;
	if( quad.opCode == OP_LXC and quad.z == sId ) {
	  if( quad.x == "0" ) {
	    fout << "\n\t.long\t" << symbol.type.rows ;
	    remSize -= 4;
	  } else if( quad.x == "4" ) {
	    fout << "\n\t.long\t" << symbol.type.cols ;
	    remSize -= 4;
	  } else {
	    Symbol & sym = mic.getSymbol( mic.lookup( quad.y ) );
	    int *ptr = (int*) (&sym.value.doubleVal);
	    fout << "\n\t.long\t" << ptr[0] << "\n\t.long\t" << ptr[1];
	    remSize -= 8;
	  }
	}
      }
      if( remSize > 0 ) fout << "\n\t.zero\t" << remSize ;
      fout << '\n';
    }
  }

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

  fout << "\t.section\t.rodata\n";
  
  /* Negating doubles. */
  fout << "\t.align 8\n.LNEGD:\n\t.long\t0\n\t.long\t-2147483648\n";
  /* Float point unit. */
  fout << "\t.align 8\n.LUNIT:\n\t.long\t0\n\t.long\t1072693248\n";
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
  
  for( Record record : stack.acR ) {
    Symbol & symbol = record.first ;
    if( symbol.type == MM_MATRIX_TYPE and symbol.symType == SymbolType::LOCAL ) {
      // emitDeallocatorOps( Taco(OP_DEALLOC , symbol.id) , stack ) ;
      std::string id = std::to_string(record.second) + "(" + Regs[BP][QUAD] + ")" ;
      fout << "\tmovq\t$0, " << id << '\n'; // initialize with 0
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
  
  stdRegs = 0 , fpRegs = 0;
  std::stack<std::string> paramCodes; // to be passed in reverse order
  int paramOffset = 0; // change in %rsp on caller side
  
  for(unsigned int index = from + 1; index < to ; index++ ) {
    if( not marks.empty() and marks.back() == index ) {
      fout << ".L" << index << ":\n";
      while( not marks.empty() and marks.back() == index )
	marks.pop_back();
    }
    const Taco & quad = mic.quadArray[index];
    if( quad.isJump() ) {
      emitJumpOps( quad , stack ); // emit (conditional) jump operation
      
    } else if( quad.isCopy() ) {
      emitCopyOps( quad , stack ); // emit data copy operation(s)

    } else if( quad.opCode == OP_PLUS or quad.opCode == OP_MINUS ) {
      emitPlusMinusOps( quad , stack );
      
    } else if( quad.opCode == OP_UMINUS ) {
      emitUnaryMinusOps( quad , stack );
      
    } else if( quad.isBitwise() ) {
      std::cerr << "Bitwise operands not implemented yet." << std::endl;
      throw 1;

    } else if( quad.isConversion() ) {
      emitConversionOps( quad , stack );

    } else if( quad.opCode == OP_ALLOC ) {
      emitAllocatorOps(quad , stack);
      
    } else if( quad.opCode == OP_DEALLOC ) {
      emitDeallocatorOps(quad , stack);

    } else if( quad.opCode == OP_MULT or quad.opCode == OP_DIV or quad.opCode == OP_MOD ) {
      emitMultDivOps( quad , stack );
      
    } else if( quad.opCode == OP_RETURN ) {
      emitReturnOps( to , quad , stack ); // emit return operation
      
    } else if( quad.opCode == OP_PARAM ) { // push parameters
      std::string pId ; DataType pType ;
      std::tie ( pId , pType ) = getLocation( quad.z , stack );
      if( pType == MM_CHAR_TYPE ) {
	std::string code;
	if( stdRegs >= 6 ) {
	  code = "\tpushq\t%rax\n"; paramCodes.push( code );
	  code = "\tmovb\t"+pId+", %rax\n"; paramCodes.push( code );
	  paramOffset += 8;
	} else {
	  code = "\tmovb\t"+pId+", "+Regs[argRegs[stdRegs++]][BYTE]+'\n';
	  paramCodes.push( code );
	}
      } else if( pType == MM_INT_TYPE ) {
	std::string code;
	if( stdRegs >= 6 ) {
	  code = "\tpushq\t%rax\n"; paramCodes.push( code );
	  code = "\tmovl\t"+pId+", %eax\n"; paramCodes.push( code );
	  paramOffset += 8;
	} else {
	  code = "\tmovl\t"+pId+", "+Regs[argRegs[stdRegs++]][LONG]+'\n';
	  paramCodes.push( code );
	}
      } else if( pType == MM_DOUBLE_TYPE ) {
	std::string code;
	if( fpRegs >= 8 ) {
	  code = "\tmovsd\t%xmm8, (%rsp)\n"; paramCodes.push( code );
	  code = "\tleaq\t-8(%rsp), %rsp\n"; paramCodes.push( code );
	  code = "\tmovsd\t"+pId+", %xmm8\n"; paramCodes.push( code );
	  paramOffset += 8; // push on stack
	} else {
	  code = "\tmovsd\t"+pId+", "+XReg+std::to_string(fpRegs++)+'\n';
	  paramCodes.push( code );
	}
      } else if( pType.isMatrix() ) {
	std::string movInstr = (pType.isStaticMatrix() ? "leaq" : "movq") ;
	std::string code;
	if( stdRegs >= 6 ) {
	  code = "\tpushq\t%rax\n"; paramCodes.push( code );
	  code = "\t"+movInstr+pId+", %rax" ; paramCodes.push( code );
	  paramOffset += 8;
	} else {
	  code = "\t"+movInstr+"\t"+pId+", "+Regs[argRegs[stdRegs++]][QUAD]+'\n';
	  paramCodes.push( code );
	}
      } else { // pointers
	std::string code;
	if( stdRegs >= 6 ) {
	  code = "\tpushq\t%rax\n"; paramCodes.push( code );
	  code = "\tmovq\t"+pId+", %rax" ; paramCodes.push( code );
	  paramOffset += 8;
	} else {
	  code = "\tmovq\t"+pId+", "+Regs[argRegs[stdRegs++]][QUAD]+'\n';
	  paramCodes.push( code );
	}
      }
      
    } else if( quad.opCode == OP_CALL ) {
      if( paramOffset & 15 ) { // align to 16 bytes
	fout << "\tleaq\t-8(%rsp), %rsp\n";
	paramOffset += 8;
      }
      while( not paramCodes.empty() ) {
	fout << paramCodes.top() ;
	paramCodes.pop();
      }
      fout << "\tcall\t" << quad.x << '\n';
      if( paramOffset > 0 )
	fout << "\tleaq\t" << paramOffset << "(%rsp), %rsp\n" ;// pop parameters off the stack
      stdRegs = fpRegs = paramOffset = 0;
      std::string retId ; DataType retType ;
      std::tie( retId , retType ) = getLocation( quad.z , stack );
      if( retType == MM_CHAR_TYPE ) fout << "\tmovb\t"+Regs[0][BYTE]+", "+retId+'\n';
      else if( retType == MM_INT_TYPE ) fout << "\tmovl\t"+Regs[0][LONG]+", "+retId+'\n';
      else if( retType == MM_DOUBLE_TYPE ) fout << "\tmovsd\t%xmm0, "+retId+'\n';
      else fout << "\tmovq\t"+Regs[0][QUAD]+", "+retId+'\n'; // Poinrix / Matter
      
    } else if( quad.opCode == OP_TRANSPOSE ) {
      emitTransposeOps( quad , stack );
      
    }
  }
  
  fout << ".L" << to << ":\n";
  fout << "\tpushq\t" << Regs[0][QUAD] << '\n';
  fout << "\tleaq\t-8(%rsp), %rsp\n\tmovsd\t%xmm0, (%rsp)\n";
  // Deallocate all memory on heap , and leave.
  for( Record record : stack.acR ) {
    Symbol & symbol = record.first ;
    if( symbol.type == MM_MATRIX_TYPE and symbol.symType == SymbolType::LOCAL )
      emitDeallocatorOps( Taco(OP_DEALLOC , symbol.id) , stack ) ;
  }
  fout << "\tmovsd\t(%rsp), %xmm0\n\tleaq\t8(%rsp), %rsp\n";
  fout << "\tpopq\t" << Regs[0][QUAD] << '\n';
  fout << "\tleave\n\tret\n" ; // return statement
  fout << "\t.size\t" << rootTable.name << ", .-" << rootTable.name << '\n' ;
  
  if( usedConstants.size() + usedStrings.size() > 0 )
    fout << "\t.section\t.rodata\n";
  for( const auto & cId : usedConstants ) {
    fout << "\t.align 8\n.LC" << cId.second << ":\n";
    int *ptr = (int*) (&stack.toC[cId.first].value.doubleVal) ;
    fout << "\t.long\t" << ptr[0] << "\n\t.long\t" << ptr[1] << '\n';
  }
  for( int id : usedStrings ) {
    fout << ".LS" << id << ":\n\t.string\t" << mic.stringTable[id] << '\n';
  }
  usedStrings.clear() ; usedConstants.clear();
}

void mm_x86_64::emitReturnOps(int retLabel,const Taco & quad , const ActivationRecord & stack) {
  if( stack.retVal.type != MM_VOID_TYPE ) {
    const size_t BP = 6 , CX = 2 , DX = 3 , SI = 4 , DI = 5 ;
    std::string retId ; DataType retType ;
    std::tie( retId , retType ) = getLocation( quad.z , stack ) ;
    const size_t ACC = 0;
    std::string movInstr , regName ;
    if( retType == MM_CHAR_TYPE ) {
      movInstr = "movb" , regName = Regs[ACC][BYTE];
    } else if( retType == MM_INT_TYPE ) {
      movInstr = "movl" , regName = Regs[ACC][LONG];
    } else if( retType == MM_DOUBLE_TYPE ) {
      movInstr = "movsd" , regName = XReg+"0";
    } else if( retType.isPointer() ) { // pointer
      movInstr = "movq" , regName = Regs[ACC][QUAD];
    } else if( retType.isMatrix() ) {
      // Allocate memory for matrix to be returned and copy contents.
      
      if( retType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << retId << ", " << Regs[DX][QUAD] << '\n';
      
      fout << "\tmovl\t("  << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // rows
      fout << "\timull\t4(" << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // rows * columns
      fout << "\tincl\t" << Regs[DI][LONG] << '\n';
      
      fout << "\tmovq\t$8, "  << Regs[SI][QUAD] << '\n'; // size of each `element'
      
      fout << "\tmovslq\t" << Regs[SI][LONG] << ", " << Regs[14][QUAD] << '\n';
      fout << "\timulq\t" << Regs[DI][QUAD] << ", " << Regs[14][QUAD] << '\n'; // save number of bytes
      
      fout << "\tcall\tcalloc\n" ;
      
      fout << "\tmovq\t" << Regs[ACC][QUAD] << ", " << Regs[15][QUAD] << '\n'; // save the pointer
      
      fout << "\tmovq\t" << Regs[ACC][QUAD] << ", " << Regs[DI][QUAD] << '\n'; // Destination pointer
      if( retType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << retId << ", " << Regs[SI][QUAD] << '\n'; // Source pointer
      fout << "\tmovq\t" << Regs[14][QUAD] << ", " << Regs[DX][QUAD] << '\n'; // Number of bytes
      fout << "\tcall\tmemcpy\n";
      movInstr = "movq" , retId = Regs[15][QUAD] , regName = Regs[ACC][QUAD];
    }
    fout << '\t' << movInstr << '\t' << retId << ", " << regName << '\n';
  }
  fout << "\tjmp\t.L" << retLabel << '\n';
}

void mm_x86_64::emitMultDivOps(const Taco & quad , const ActivationRecord & stack) {
  if( stack.constMap.find( quad.z ) != stack.constMap.end() )
    return ; // Ignore.

  const size_t ACC = 0 , CX = 2 , DX = 3 , SI = 4 , DI = 5;
  DataType retType , xType , yType ;
  std::string zId , xId , yId , movInstr , opInstr ;

  std::tie( zId , retType ) = getLocation( quad.z , stack );
  std::tie( xId , xType ) = getLocation( quad.x , stack );
  
  try {
    int value = std::stoi( quad.y );
    yId = "$" + quad.y; yType = MM_INT_TYPE;
  } catch ( std::invalid_argument ex ) {
    std::tie( yId , yType ) = getLocation( quad.y , stack );
  }
  
  if( retType.isScalarType() ) {
    if( retType == MM_CHAR_TYPE ) {
      fout << "\tmovb\t" << xId << ", " << Regs[ACC][BYTE] << '\n';
      fout << "\tmovsbl\t" << Regs[ACC][BYTE] << ", " << Regs[ACC][LONG] << '\n';
      if( quad.opCode == OP_DIV or quad.opCode == OP_MOD ) fout << "\tcltd\n" ; // sign extends %eax to %edx:%eax
      fout << "\tmovb\t" << yId << ", " << Regs[CX][BYTE] << '\n';
      fout << "\tmovsbl\t" << Regs[CX][BYTE] << ", " << Regs[CX][LONG] << '\n';
      if( quad.opCode == OP_DIV or quad.opCode == OP_MOD ) fout << "\tidivl\t" << Regs[CX][LONG] << '\n';
      else fout << "\timull\t" << Regs[CX][LONG] << ", " << Regs[ACC][LONG] << '\n';
      if( quad.opCode == OP_MULT or quad.opCode == OP_DIV )
	fout << "\tmovb\t" << Regs[ACC][BYTE] << ", " << zId << '\n';
      else
	fout << "\tmovb\t" << Regs[DX][BYTE] << ", " << zId << '\n';
    } else if( retType == MM_INT_TYPE ) {
      fout << "\tmovl\t" << xId << ", " << Regs[ACC][LONG] << '\n';
      if( quad.opCode == OP_DIV or quad.opCode == OP_MOD ) fout << "\tcltd\n" ; // sign extends %eax to %edx:%eax
      fout << "\tmovl\t" << yId << ", " << Regs[CX][LONG] << '\n';
      if( quad.opCode == OP_DIV or quad.opCode == OP_MOD ) fout << "\tidivl\t" << Regs[CX][LONG] << '\n';
      else fout << "\timull\t" << Regs[CX][LONG] << ", " << Regs[ACC][LONG] << '\n';
      if( quad.opCode == OP_MULT or quad.opCode == OP_DIV )
	fout << "\tmovl\t" << Regs[ACC][LONG] << ", " << zId << '\n';
      else
	fout << "\tmovl\t" << Regs[DX][LONG] << ", " << zId << '\n';
    } else if( retType == MM_DOUBLE_TYPE ) {
      fout << "\tmovsd\t" << xId << ", %xmm0\n";
      fout << "\tmovsd\t" << yId << ", %xmm1\n";
      if( quad.opCode == OP_MULT ) fout << "\tmulsd\t%xmm1, %xmm0\n";
      else fout << "\tdivsd\t%xmm1, %xmm0\n";
      fout << "\tmovsd\t%xmm0, " << zId << '\n';
    }
    
  } else if( retType.isMatrix() ) {
    
    if( yType.isMatrix() ) { // matrix multiplication
      if( retType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << zId << ", " << Regs[DI][QUAD] << '\n'; // first argument
      if( xType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << xId << ", " << Regs[SI][QUAD] << '\n'; // second argument
      if( yType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << yId << ", " << Regs[DX][QUAD] << '\n'; // third argument
      fout << "\tcall\tmatMult\n" ;
    } else {
      
      if( retType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << zId << ", " << Regs[DI][QUAD] << '\n';
    
      if( xType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << xId << ", " << Regs[SI][QUAD] << '\n';
      
      fout << "\tmovsd\t" << yId << ", %xmm1\n";
      fout << "\tmovq\t(" << Regs[DI][QUAD] <<"), " << Regs[DX][QUAD] << '\n';
      fout << "\tmovq\t(" << Regs[SI][QUAD] <<"), " << Regs[CX][QUAD] << '\n';
      fout << "\tcmpq\t" << Regs[DX][QUAD] << ", " << Regs[CX][QUAD] << '\n';
      fout << "\tje\t.LTEMP" << ++tempLabels << "\n\tcall\tabort\n.LTEMP" << tempLabels << ":\n";
      fout << "\tmovq\t$8, " << Regs[DX][QUAD] << '\n';
      fout << "\tmovl\t(" << Regs[DI][QUAD] <<"), " << Regs[CX][LONG] << '\n';
      fout << "\timull\t4(" << Regs[DI][QUAD] <<"), " << Regs[CX][LONG] << '\n';
      fout << "\tincl\t" << Regs[CX][LONG] << '\n';
      fout << "\timull\t$8, " << Regs[CX][LONG] << '\n';
      fout << ".LTEMP" << ++tempLabels << ":\n";
      fout << "\tmovsd\t(" << Regs[SI][QUAD] << "," << Regs[DX][QUAD] <<"), %xmm0\n";
      opInstr = ( quad.opCode == OP_MULT ? "mulsd" : "divsd" );
      fout << '\t' << opInstr << "\t%xmm1, %xmm0\n";
      fout << "\tmovsd\t%xmm0, (" << Regs[DI][QUAD] << "," << Regs[DX][QUAD] <<")\n";
      fout << "\taddq\t$8, " << Regs[DX][QUAD] << '\n';
      fout << "\tcmpq\t" << Regs[DX][QUAD] << ", " << Regs[CX][QUAD] << '\n';
      fout << "\tjg\t.LTEMP" << tempLabels << "\n";
      
    }
    
  }
  
}

void mm_x86_64::emitPlusMinusOps(const Taco & quad , const ActivationRecord & stack) {
  if( stack.constMap.find( quad.z ) != stack.constMap.end() )
    return ; // Ignore.
  
  const size_t ACC = 0 , CX = 2 , DX = 3 , SI = 4 , DI = 5;
  DataType retType , xType , yType ;
  std::string zId , xId , yId , movInstr , opInstr ;
  bool inc_dec = false;
  
  std::tie( zId , retType ) = getLocation( quad.z , stack );
  std::tie( xId , xType ) = getLocation( quad.x , stack );

  try {
    int value = std::stoi( quad.y );
    if( value == 1 ) inc_dec = true;
    yId = "$" + quad.y; yType = MM_INT_TYPE;
  } catch ( std::invalid_argument ex ) {
    std::tie( yId , yType ) = getLocation( quad.y , stack );
  }
  
  if( retType.isScalarType() ) {
    std::string alphaReg , betaReg ;
    
    movInstr = "mov";
    opInstr = (quad.opCode == OP_PLUS ? "add" : "sub") ;
    
    if( retType != MM_DOUBLE_TYPE and inc_dec )
      opInstr = (quad.opCode == OP_PLUS ? "inc" : "dec") ;
    
    if( retType == MM_CHAR_TYPE ) {
      movInstr += 'b'; opInstr  += 'b';
      alphaReg = Regs[ACC][BYTE] , betaReg = Regs[DX][BYTE];
    } else if( retType == MM_INT_TYPE ) {
      movInstr += 'l'; opInstr  += 'l';
      alphaReg = Regs[ACC][LONG] , betaReg = Regs[DX][LONG];
    } else { // MM_DOUBLE_TYPE
      if( inc_dec ) {
	yId = ".LUNIT(%rip)";
	inc_dec = false ;
      }
      movInstr += "sd"; opInstr += "sd";
      alphaReg = XReg+"0" , betaReg = XReg+"1";
    }
    fout << '\t' << movInstr << '\t' << xId << ", " << alphaReg << '\n';
    
    if( inc_dec ) {
      fout << '\t' << opInstr << '\t' << alphaReg << '\n';
    } else {
      fout << '\t' << movInstr << '\t' << yId << ", " << betaReg  << '\n';
      fout << '\t' << opInstr << '\t' << betaReg << ", " << alphaReg << '\n';
    }
    fout << '\t' << movInstr << '\t' << alphaReg << ", " << zId << '\n';
    
  } else if( retType.isPointer() ) {
    if( xType.isMatrix() and yType == MM_INT_TYPE ) { // base + offset

      // get base address
      if( xType.isStaticMatrix() )
	fout << "\tleaq\t" << xId << ", " << Regs[DX][QUAD] << '\n';
      else
	fout << "\tmovq\t" << xId << ", " << Regs[DX][QUAD] << '\n';
      
      fout << "\tmovl\t" << yId << ", " << Regs[ACC][LONG] << "\n\tcltq\n";
      fout << "\taddq\t" << Regs[ACC][QUAD] << ", " << Regs[DX][QUAD] << '\n';
      fout << "\tmovq\t" << Regs[DX][QUAD] << ", " << zId << '\n';
    } else if( xType.isPointer() and yType == MM_INT_TYPE ) {
      std::string opInstr = (quad.opCode == OP_PLUS ? "addq" : "subq");
      fout << "\tmovq\t" << xId << ", " << Regs[DX][QUAD] << '\n';
      fout << "\tmovl\t" << yId << ", " << Regs[ACC][LONG] << "\n\tcltq\n";
      fout << '\t' << opInstr << '\t' << Regs[ACC][QUAD] << ", " << Regs[DX][QUAD] << '\n';
      fout << "\tmovq\t" << Regs[DX][QUAD] << ", " << zId << '\n';
    }
    
  } else if( retType.isMatrix() ) {
    
    if( retType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
    fout << zId << ", " << Regs[DI][QUAD] << '\n';
    
    if( xType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
    fout << xId << ", " << Regs[8][QUAD] << '\n';
    
    if( yType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
    fout << yId << ", " << Regs[9][QUAD] << '\n';
    
    fout << "\tmovq\t(" << Regs[DI][QUAD] <<"), " << Regs[DX][QUAD] << '\n';
    fout << "\tmovq\t(" << Regs[8][QUAD] <<"), " << Regs[CX][QUAD] << '\n';
    fout << "\tcmpq\t" << Regs[DX][QUAD] << ", " << Regs[CX][QUAD] << '\n';
    fout << "\tje\t.LTEMP" << ++tempLabels << "\n\tcall\tabort\n.LTEMP" << tempLabels << ":\n";
    
    fout << "\tmovq\t(" << Regs[DI][QUAD] <<"), " << Regs[DX][QUAD] << '\n';
    fout << "\tmovq\t(" << Regs[9][QUAD] <<"), " << Regs[CX][QUAD] << '\n';
    fout << "\tcmpq\t" << Regs[DX][QUAD] << ", " << Regs[CX][QUAD] << '\n';
    fout << "\tje\t.LTEMP" << ++tempLabels << "\n\tcall\tabort\n.LTEMP" << tempLabels << ":\n"; // check dimensions
    
    fout << "\tmovq\t$8, " << Regs[DX][QUAD] << '\n';
    fout << "\tmovl\t(" << Regs[DI][QUAD] <<"), " << Regs[CX][LONG] << '\n';
    fout << "\timull\t4(" << Regs[DI][QUAD] <<"), " << Regs[CX][LONG] << '\n';
    fout << "\tincl\t" << Regs[CX][LONG] << '\n';
    fout << "\timull\t$8, " << Regs[CX][LONG] << '\n'; // size in bytes
    fout << ".LTEMP" << ++tempLabels << ":\n";
    fout << "\tmovsd\t(" << Regs[8][QUAD] << "," << Regs[DX][QUAD] <<"), %xmm0\n";
    
    opInstr = (quad.opCode == OP_PLUS ? "addsd" : "subsd") ;
    fout << '\t' << opInstr << "\t(" << Regs[9][QUAD] << "," << Regs[DX][QUAD] <<"), %xmm0\n";
    
    fout << "\tmovsd\t%xmm0, (" << Regs[DI][QUAD] << "," << Regs[DX][QUAD] <<")\n";
    
    fout << "\taddq\t$8, " << Regs[DX][QUAD] << '\n';
    
    fout << "\tcmpq\t" << Regs[DX][QUAD] << ", " << Regs[CX][QUAD] << '\n';
    fout << "\tjg\t.LTEMP" << tempLabels << "\n";
    
  }
  
}

void mm_x86_64::emitAllocatorOps(const Taco & quad , const ActivationRecord & stack) {
  fout << "\t#\t" << quad << '\n';
  
  const size_t ACC = 0 , DI = 5 , SI = 4 , DX = 3 , CX = 2 ;
  
  std::string zId , xId , yId ;
  DataType xType , yType ;
  
  std::tie( zId , std::ignore ) = getLocation( quad.z , stack );
  
  if( quad.y.empty() ) { // z = alloc( Matrix )
    std::tie( xId , xType ) = getLocation( quad.x , stack );

    if( xType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
    fout << xId << ", " << Regs[DX][QUAD] << '\n';
    
    fout << "\tmovl\t("  << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // rows
    fout << "\timull\t4(" << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // rows * columns
    fout << "\tincl\t" << Regs[DI][LONG] << '\n';
    fout << "\tmovl\t$8, "  << Regs[SI][LONG] << '\n'; // size of each `element'
    fout << "\tcall\tcalloc\n" ;
    fout << "\tmovq\t" << Regs[ACC][QUAD] << ", " << zId << '\n';

    if( xType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
    fout << xId << ", " << Regs[DX][QUAD] << '\n';
    
    fout << "\tmovl\t("  << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // copy
    fout << "\tmovl\t"  << Regs[DI][LONG] << ", (" << Regs[ACC][QUAD] << ")\n"; // rows
    fout << "\tmovl\t4("  << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // copy
    fout << "\tmovl\t"  << Regs[DI][LONG] << ", 4(" << Regs[ACC][QUAD] << ")\n"; // cols
    
  } else if( quad.x.empty() ) { // z = alloc( Matrix.' )
    std::tie( yId , yType ) = getLocation( quad.y , stack );
    
    if( yType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
    fout << yId << ", " << Regs[DX][QUAD] << '\n';
    
    fout << "\tmovl\t4("  << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // rows
    fout << "\timull\t(" << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // rows * columns
    fout << "\tincl\t" << Regs[DI][LONG] << '\n';
    fout << "\tmovl\t$8, "  << Regs[SI][LONG] << '\n'; // size of each `element'
    fout << "\tcall\tcalloc\n" ;
    fout << "\tmovq\t" << Regs[ACC][QUAD] << ", " << zId << '\n';
    
    if( yType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
    fout << yId << ", " << Regs[DX][QUAD] << '\n';
    
    fout << "\tmovl\t4("  << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // copy
    fout << "\tmovl\t"  << Regs[DI][LONG] << ", (" << Regs[ACC][QUAD] << ")\n"; // rows
    fout << "\tmovl\t("  << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // copy
    fout << "\tmovl\t"  << Regs[DI][LONG] << ", 4(" << Regs[ACC][QUAD] << ")\n"; // cols
    
  } else { // z = alloc( Matrix , Matrix ) or alloc( int , int )
    std::tie( xId , xType ) = getLocation( quad.x , stack );
    std::tie( yId , yType ) = getLocation( quad.y , stack );
    if( xType.isMatrix() and yType.isMatrix() ) { // multiplication
      if( xType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << xId << ", " << Regs[DX][QUAD] << '\n';
      if( yType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << yId << ", " << Regs[CX][QUAD] << '\n';

      fout << "\tmovl\t("  << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // rows
      
      fout << "\timull\t4(" << Regs[CX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // rows * columns
      
      fout << "\tincl\t" << Regs[DI][LONG] << '\n';
      fout << "\tmovl\t$8, "  << Regs[SI][LONG] << '\n'; // size of each `element'
      fout << "\tcall\tcalloc\n" ;
      fout << "\tmovq\t" << Regs[ACC][QUAD] << ", " << zId << '\n';
      
      if( xType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << xId << ", " << Regs[DX][QUAD] << '\n';
      if( yType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << yId << ", " << Regs[CX][QUAD] << '\n';
      
      fout << "\tmovl\t("  << Regs[DX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // copy from x
      fout << "\tmovl\t"  << Regs[DI][LONG] << ", (" << Regs[ACC][QUAD] << ")\n"; // rows
      fout << "\tmovl\t4("  << Regs[CX][QUAD] << "), " << Regs[DI][LONG] << '\n'; // copy from y
      fout << "\tmovl\t"  << Regs[DI][LONG] << ", 4(" << Regs[ACC][QUAD] << ")\n"; // cols
      
    } else if( xType == MM_INT_TYPE and yType == MM_INT_TYPE ) {
      fout << "\tmovl\t"  << xId << ", " << Regs[DI][LONG] << '\n'; // rows
      fout << "\timull\t"  << yId << ", " << Regs[DI][LONG] << '\n'; // rows * columns
      fout << "\tincl\t" << Regs[DI][LONG] << '\n';
      fout << "\tmovl\t$8, "  << Regs[SI][LONG] << '\n'; // size of each `element'
      fout << "\tcall\tcalloc\n" ;
      fout << "\tmovq\t" << Regs[ACC][QUAD] << ", " << zId << '\n';
      
      fout << "\tmovl\t"  << xId << ", " << Regs[DI][LONG] << '\n'; // copy
      fout << "\tmovl\t"  << Regs[DI][LONG] << ", (" << Regs[ACC][QUAD] << ")\n"; // rows
      fout << "\tmovl\t"  << yId << ", " << Regs[DI][LONG] << '\n'; // copy
      fout << "\tmovl\t"  << Regs[DI][LONG] << ", 4(" << Regs[ACC][QUAD] << ")\n"; // cols
      
    }
  }
  
}

void mm_x86_64::emitDeallocatorOps(const Taco & quad , const ActivationRecord & stack) {
  const size_t ACC = 0 , ARG1 = 5;
  std::string zId ;
  std::tie( zId , std::ignore ) = getLocation( quad.z , stack );
  fout << "\tmovq\t" << zId << ", " << Regs[ARG1][QUAD] << '\n';
  fout << "\tcall\tfree\n" ;
  fout << "\tmovq\t$0, " << zId << '\n';
}

void mm_x86_64::emitUnaryMinusOps(const Taco & quad , const ActivationRecord & stack) {
  if( stack.constMap.find( quad.z ) != stack.constMap.end() )
    return ; // Ignore.

  const size_t ACC = 0 , CX = 2 , DX = 3 , SI = 4 , DI = 5 ;
  DataType retType , rType ;
  std::string zId , xId;
  std::tie( zId , retType ) = getLocation( quad.z , stack );
  std::tie( xId , rType ) = getLocation( quad.x , stack );
  if( retType.isMatrix() ) {
    
    if( retType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
    fout << zId << ", " << Regs[DI][QUAD] << '\n';
    
    if( rType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
    fout << xId << ", " << Regs[SI][QUAD] << '\n';
    
    fout << "\tmovq\t(" << Regs[DI][QUAD] <<"), " << Regs[DX][QUAD] << '\n';
    fout << "\tmovq\t(" << Regs[SI][QUAD] <<"), " << Regs[CX][QUAD] << '\n';
    fout << "\tcmpq\t" << Regs[DX][QUAD] << ", " << Regs[CX][QUAD] << '\n';
    fout << "\tje\t.LTEMP" << ++tempLabels << "\n\tcall\tabort\n.LTEMP" << tempLabels << ":\n";
    
    fout << "\tmovq\t$8, " << Regs[DX][QUAD] << '\n';
    fout << "\tmovl\t(" << Regs[DI][QUAD] <<"), " << Regs[CX][LONG] << '\n';
    fout << "\timull\t4(" << Regs[DI][QUAD] <<"), " << Regs[CX][LONG] << '\n';
    fout << "\tincl\t" << Regs[CX][LONG] << '\n';
    fout << "\timull\t$8, " << Regs[CX][LONG] << '\n';
    fout << "\tmovsd\t.LNEGD(%rip), %xmm1\n" ;
    fout << ".LTEMP" << ++tempLabels << ":\n";
    fout << "\tmovsd\t(" << Regs[SI][QUAD] << "," << Regs[DX][QUAD] <<"), %xmm0\n";
    fout << "\txorpd\t%xmm1, %xmm0\n" ;
    fout << "\tmovsd\t%xmm0, (" << Regs[DI][QUAD] << "," << Regs[DX][QUAD] <<")\n";
    fout << "\taddq\t$8, " << Regs[DX][QUAD] << '\n';
    
    fout << "\tcmpq\t" << Regs[DX][QUAD] << ", " << Regs[CX][QUAD] << '\n';
    fout << "\tjg\t.LTEMP" << tempLabels << "\n";
    
  } else {
    if( retType == MM_CHAR_TYPE ) {
      fout << "\tmovb\t" << xId << ", " << Regs[ACC][BYTE] << '\n';
      fout << "\tmovzbl\t" << Regs[ACC][BYTE] << ", " << Regs[ACC][LONG] << '\n';
      fout << "\tnegl\t" << Regs[ACC][LONG] << '\n';
      fout << "\tmovb\t" << Regs[ACC][BYTE] << ", " << zId << '\n';
    } else if( retType == MM_INT_TYPE ) {
      fout << "\tmovl\t" << xId << ", " << Regs[ACC][LONG] << '\n';
      fout << "\tnegl\t" << Regs[ACC][LONG] << '\n';
      fout << "\tmovl\t" << Regs[ACC][LONG] << ", " << zId << '\n';
    } else {
      fout << "\tmovsd\t" << xId << ", %xmm0\n" ;
      fout << "\tmovsd\t.LNEGD(%rip), %xmm1\n" ;
      fout << "\txorpd\t%xmm1, %xmm0\n" ;
      fout << "\tmovsd\t%xmm0, " << zId << '\n';
    }
  }
}

void mm_x86_64::emitTransposeOps(const Taco & quad , const ActivationRecord & stack) {
  
  const size_t ACC = 0 , CX = 2 , DX = 3 , SI = 4 , DI = 5 ;
  DataType retType , rType ;
  std::string zId , xId;
  std::tie( zId , retType ) = getLocation( quad.z , stack );
  std::tie( xId , rType ) = getLocation( quad.x , stack );
  
  /* Check dimensions */
  if( retType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
  fout << zId << ", " << Regs[DI][QUAD] << '\n';
  if( rType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
  fout << xId << ", " << Regs[SI][QUAD] << '\n';
  fout << "\tmovq\t(" << Regs[DI][QUAD] <<"), " << Regs[DX][QUAD] << '\n';
  fout << "\tmovq\t(" << Regs[SI][QUAD] <<"), " << Regs[CX][QUAD] << '\n';
  fout << "\tror\t$32, " << Regs[CX][QUAD] << '\n'; // `swap' dimensions
  fout << "\tcmpq\t" << Regs[DX][QUAD] << ", " << Regs[CX][QUAD] << '\n';
  fout << "\tje\t.LTEMP" << ++tempLabels << "\n\tcall\tabort\n.LTEMP" << tempLabels << ":\n";
  
  fout << "\tmovl\t4(" << Regs[DI][QUAD] << "), " << Regs[DX][LONG] << '\n';
  fout << "\timull\t$8, " << Regs[DX][LONG] << '\n'; // width of row
  fout << "\tmovl\t" << Regs[DX][LONG] << ", " << Regs[CX][LONG] << '\n'; // store size of matrices in %rcx
  fout << "\timull\t(" << Regs[DI][QUAD] << "), " << Regs[CX][LONG] << '\n'; // *= rows
  
  fout << "\tmovslq\t" << Regs[DX][LONG] << ", " << Regs[DX][QUAD] << '\n'; // in 8 bytes
  fout << "\tmovslq\t" << Regs[CX][LONG] << ", " << Regs[CX][QUAD] << '\n'; // in 8 bytes
  
  fout << "\txorq\t" << Regs[8][QUAD] << ", " << Regs[8][QUAD] << '\n';
  fout << "\txorq\t" << Regs[9][QUAD] << ", " << Regs[9][QUAD] << '\n'; // %r8 = %r9 = 0
  
  unsigned int loopLabel = ++tempLabels;
  fout << ".LTEMP" << loopLabel << ":\n";
  
  fout << "\tmovsd\t8(%rsi,%r9), %xmm0\n";
  fout << "\tmovsd\t%xmm0, 8(%rdi,%r8)\n";
  
  fout << "\taddq\t%rdx,%r8\n"; // %r8 += row-width
  fout << "\tmovq\t%rcx, %rax\n";
  fout << "\tcmpq\t%r8, %rax\n"; // %r8 < %rcx ?
  fout << "\tjg\t.LTEMP" << ++tempLabels << '\n';
  fout << "\tsubq\t%rcx, %r8\n";
  fout << "\taddq\t$8, %r8\n";
  
  fout << ".LTEMP" << tempLabels << ":\n";
  fout << "\taddq\t$8,%r9\n"; // %r9 += 8
  fout << "\tcmpq\t%r9, %rcx\n"; // %r9 < %rcx ?
  fout << "\tjg\t.LTEMP" << loopLabel << '\n';
  
}

void mm_x86_64::emitConversionOps(const Taco & quad , const ActivationRecord & stack) {
  if( stack.constMap.find( quad.z ) != stack.constMap.end() )
    return ; // Ignore.
  
  const size_t ACC = 0;
  DataType rType ;
  std::string zId , xId ;
  std::tie( zId , std::ignore ) = getLocation( quad.z , stack );
  std::tie( xId , rType ) = getLocation( quad.x , stack );
  
  if( quad.opCode == OP_CONV_TO_CHAR ) {
    if( rType == MM_INT_TYPE ) {
      fout << "\tmovl\t" << xId << ", " << Regs[ACC][LONG] << '\n';
      fout << "\tmovb\t" << Regs[ACC][BYTE] << ", " << zId << '\n';
    } else if( rType == MM_DOUBLE_TYPE ) {
      fout << "\tmovsd\t" << xId << ", %xmm0\n";
      fout << "\tcvttsd2si\t%xmm0, " << Regs[ACC][LONG] << '\n';
      fout << "\tmovb\t" << Regs[ACC][BYTE] << ", " << zId << '\n';
    }
  } else if( quad.opCode == OP_CONV_TO_INT ) {
    if( rType == MM_CHAR_TYPE ) {
      fout << "\tmovb\t" << xId << ", " << Regs[ACC][BYTE] << '\n';
      fout << "\tmovzbl\t" << Regs[ACC][BYTE] << ", " << Regs[ACC][LONG] << '\n';
      fout << "\tmovl\t" << Regs[ACC][LONG] << ", " << zId << '\n';
    } else if( rType == MM_DOUBLE_TYPE ) {
      fout << "\tmovsd\t" << xId << ", %xmm0\n";
      fout << "\tcvttsd2si\t%xmm0, " << Regs[ACC][LONG] << '\n';
      fout << "\tmovl\t" << Regs[ACC][LONG] << ", " << zId << '\n';
    }
  } else if( quad.opCode == OP_CONV_TO_DOUBLE ) {
    if( rType == MM_CHAR_TYPE ) {
      fout << "\tmovb\t" << xId << ", " << Regs[ACC][BYTE] << '\n';
      fout << "\tmovzbl\t" << Regs[ACC][BYTE] << ", " << Regs[ACC][LONG] << '\n';
    } else if( rType == MM_INT_TYPE ) {
      fout << "\tmovl\t" << xId << ", " << Regs[ACC][LONG] << '\n';
    }
    fout << "\tcvtsi2sd\t" << Regs[ACC][LONG] << ", %xmm0\n" ;
    fout << "\tmovsd\t%xmm0, " << zId << '\n';
  }

}

void mm_x86_64::emitCopyOps(const Taco & quad , const ActivationRecord & stack) {
  const size_t BP = 6 , ACC = 0 , CX = 2 , DX = 3 , SI = 4 , DI = 5 , PTR = 3;
  switch(quad.opCode) {
    
  case OP_COPY : {
    if( stack.constMap.find( quad.z ) != stack.constMap.end() )
      return ; // Ignore.
    std::string lId , rId , movInstr , regName ;
    DataType type , rType ;
    std::tie( lId , type ) = getLocation( quad.z , stack );
    std::tie( rId , rType ) = getLocation( quad.x , stack );
    if( type == MM_CHAR_TYPE ) movInstr = "movb" , regName = Regs[ACC][BYTE] ;
    else if( type == MM_INT_TYPE ) movInstr = "movl" , regName = Regs[ACC][LONG] ;
    else if( type == MM_DOUBLE_TYPE ) movInstr = "movsd" , regName = XReg+"0" ;
    else if( type.isPointer() ) movInstr = "movq" , regName = Regs[ACC][QUAD] ;
    else if( type.isMatrix() ) {
      
      if( type.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << lId << ", " << Regs[DI][QUAD] << '\n';

      if( rType.isStaticMatrix() ) fout << "\tleaq\t" ; else fout << "\tmovq\t" ;
      fout << rId << ", " << Regs[SI][QUAD] << '\n';
      
      fout << "\tmovq\t(" << Regs[DI][QUAD] <<"), " << Regs[DX][QUAD] << '\n';
      fout << "\tmovq\t(" << Regs[SI][QUAD] <<"), " << Regs[CX][QUAD] << '\n';
      fout << "\tcmpq\t" << Regs[DX][QUAD] << ", " << Regs[CX][QUAD] << '\n';
      fout << "\tje\t.LTEMP" << ++tempLabels << "\n\tcall\tabort\n.LTEMP" << tempLabels << ":\n";
      
      fout << "\tmovl\t(" << Regs[DI][QUAD] <<"), " << Regs[DX][LONG] << '\n';
      fout << "\timull\t4(" << Regs[DI][QUAD] <<"), " << Regs[DX][LONG] << '\n';
      fout << "\tincl\t" << Regs[DX][LONG] << '\n';
      fout << "\timull\t$8, " << Regs[DX][LONG] << '\n';
      fout << "\tmovslq\t" << Regs[DX][LONG] << ", " << Regs[DX][QUAD] << '\n';
      fout << "\tcall\tmemcpy\n" ;
      
      return ;
    }
    fout << '\t' << movInstr << '\t' << rId << ", " << regName << '\n';
    fout << '\t' << movInstr << '\t' << regName << ", " << lId << '\n';
  } break;
    
  case OP_R_DEREF : {
    if( stack.constMap.find( quad.z ) != stack.constMap.end() )
      return ;
    std::string lId , rId , movInstr , regName ;
    DataType type ;
    std::tie( lId , type ) = getLocation( quad.z , stack );
    std::tie( rId , std::ignore ) = getLocation( quad.x , stack );
    if( type == MM_CHAR_TYPE ) movInstr = "movb" , regName = Regs[ACC][BYTE] ;
    else if( type == MM_INT_TYPE ) movInstr = "movl" , regName = Regs[ACC][LONG] ;
    else if( type == MM_DOUBLE_TYPE ) movInstr = "movsd" , regName = XReg+"0" ;
    else if( type.isPointer() ) movInstr = "movq" , regName = Regs[ACC][QUAD] ;
    fout << "\tmovq\t" << rId << ", " << Regs[PTR][QUAD] << '\n';
    fout << '\t' << movInstr << "\t(" << Regs[PTR][QUAD] << "), " << regName << '\n';
    fout << '\t' << movInstr << '\t' << regName << ", " << lId << '\n';
  } break;
    
  case OP_L_DEREF : {
    if( stack.constMap.find( quad.z ) != stack.constMap.end() )
      return ;
    std::string lId , rId , movInstr , regName ;
    DataType type ;
    std::tie( lId , std::ignore ) = getLocation( quad.z , stack );
    std::tie( rId , type ) = getLocation( quad.x , stack );
    if( type == MM_CHAR_TYPE ) movInstr = "movb" , regName = Regs[ACC][BYTE] ;
    else if( type == MM_INT_TYPE ) movInstr = "movl" , regName = Regs[ACC][LONG] ;
    else if( type == MM_DOUBLE_TYPE ) movInstr = "movsd" , regName = XReg+"0" ;
    else if( type.isPointer() ) movInstr = "movq" , regName = Regs[ACC][QUAD] ;
    fout << "\tmovq\t" << lId << ", " << Regs[PTR][QUAD] << '\n';
    fout << '\t' << movInstr << '\t' << rId << ", " << regName << '\n';
    fout << '\t' << movInstr << '\t' << regName << ", (" << Regs[PTR][QUAD] << ")\n";
  } break;
    
  case OP_REFER : {
    if( stack.constMap.find( quad.z ) != stack.constMap.end() )
      return ;
    std::string lId , rId , movInstr ;
    std::tie( lId , std::ignore ) = getLocation( quad.z , stack );
    std::tie( rId , std::ignore ) = getLocation( quad.x , stack );
    fout << "\tleaq\t" << rId << ", " << Regs[PTR][QUAD] << '\n';
    fout << "\tmovq\t" << Regs[PTR][QUAD] << ", " << lId << '\n';
  } break;

  case OP_LXC : {
    DataType matType;
    std::string zId , xId , yId , movInstr , dataReg ;

    std::tie( zId , matType ) = getLocation( quad.z , stack );

    /* Get base address. */
    if( matType.isStaticMatrix() )
      fout << "\tleaq\t" << zId << ", " << Regs[PTR][QUAD] << '\n';
    else
      fout << "\tmovq\t" << zId << ", " << Regs[PTR][QUAD] << '\n';
    
    /* Get index. */
    try {
      int index = std::stoi( quad.x ) ;
      xId = "$" + quad.x ;
      fout << "\tmovq\t" << xId << ", " << Regs[ACC][QUAD] << '\n';
    } catch ( std::invalid_argument ex ) {
      DataType indexType ;
      std::tie( xId , indexType ) = getLocation( quad.x , stack );
      fout << "\tmovl\t" << xId << ", " << Regs[ACC][LONG] << '\n';
      fout << "\tcltq\n";
    }

    /* Get rhs location. */
    DataType dataType ;
    std::tie( yId , dataType ) = getLocation( quad.y , stack );
    if( dataType == MM_INT_TYPE ) {
      dataReg = Regs[CX][LONG] ; movInstr = "movl";
    } else {
      dataReg = XReg+"0"; movInstr = "movsd";
    }
    fout << '\t' << movInstr << '\t' << yId << ", " << dataReg << '\n';

    /* Copy into memory. */
    fout << '\t' << movInstr << '\t' << dataReg << ", (" << Regs[PTR][QUAD] << ',' << Regs[ACC][QUAD] << ")\n";
    
  } break;
    
  case OP_RXC : {
    DataType retType , matType ;
    std::string zId , xId , yId , movInstr , dataReg ;

    std::tie( xId , matType ) = getLocation( quad.x , stack );

    /* Get base address. */
    if( matType.isStaticMatrix() )
      fout << "\tleaq\t" << xId << ", " << Regs[PTR][QUAD] << '\n';
    else
      fout << "\tmovq\t" << xId << ", " << Regs[PTR][QUAD] << '\n';
    
    /* Get index. */
    try {
      int index = std::stoi( quad.y ) ;
      yId = "$" + quad.y ;
      fout << "\tmovq\t" << yId << ", " << Regs[ACC][QUAD] << '\n';
    } catch ( std::invalid_argument ex ) {
      DataType indexType ;
      std::tie( yId , indexType ) = getLocation( quad.y , stack );
      fout << "\tmovl\t" << yId << ", " << Regs[ACC][LONG] << '\n';
      fout << "\tcltq\n";
    }

    /* Copy data. */
    std::tie( zId , retType ) = getLocation( quad.z , stack );
    if( retType == MM_DOUBLE_TYPE ) {
      dataReg = XReg+"0";
      fout << "\tmovsd\t(" << Regs[PTR][QUAD] << ',' << Regs[ACC][QUAD] << "), " << dataReg << '\n';
      fout << "\tmovsd\t" << dataReg << ", " << zId << '\n';
    } else if( retType == MM_INT_TYPE ) {
      dataReg = Regs[CX][LONG];
      fout << "\tmovl\t(" << Regs[PTR][QUAD] << ',' << Regs[ACC][QUAD] << "), " << dataReg << '\n';
      fout << "\tmovl\t" << dataReg << ", " << zId << '\n';
    }
    
  } break;
    
  default : fout << "\t#\t" << quad << '\n';
  }
}

void mm_x86_64::emitJumpOps(const Taco & quad , const ActivationRecord & stack) {
  const size_t BP = 6 ;
  switch(quad.opCode) {
    /* Conditional jumps */
  case OP_LT : case OP_LTE : case OP_GT : case OP_GTE : case OP_EQ : case OP_NEQ : {
    std::string regName , lId , rId, movInstr, cmpInstr;
    const size_t ACC = 1;
    DataType type;
    std::tie( lId , type ) = getLocation( quad.x , stack );
    std::tie( rId , std::ignore ) = getLocation( quad.y , stack );
    if( type == MM_CHAR_TYPE )
      movInstr = "movb" , cmpInstr = "cmpb" , regName = Regs[ACC][BYTE] ;
    else if( type == MM_INT_TYPE )
      movInstr = "movl" , cmpInstr = "cmpl" , regName = Regs[ACC][LONG] ;
    else if( type == MM_DOUBLE_TYPE )
      movInstr = "movsd" , cmpInstr = "ucomisd" , regName = XReg+"1" ;
    else if( type.isPointer() )
      movInstr = "movq" , cmpInstr = "cmpq" , regName = Regs[ACC][QUAD] ;
    // Move first operand to register
    fout << '\t' << movInstr << '\t' << lId << " , " << regName << '\n';
    // Compare operands
    fout << '\t' << cmpInstr << '\t' << rId << " , " << regName << "\n\t";
    switch( quad.opCode ) {
    case OP_LT : if( type == MM_DOUBLE_TYPE ) fout << "jb" ; else fout << "jl" ; break;
    case OP_LTE : if( type == MM_DOUBLE_TYPE ) fout << "jbe" ; else fout << "jle" ; break;
    case OP_GT : if( type == MM_DOUBLE_TYPE ) fout << "ja" ; else fout << "jg" ;break;
    case OP_GTE : if( type == MM_DOUBLE_TYPE ) fout << "jae" ; else fout << "jge" ;break;
    case OP_EQ : fout << "je" ; break; case OP_NEQ : fout << "jne" ; break;
    default : break;
    };
    fout << "\t.L" << quad.z << '\n';
  } break;
  case OP_GOTO : {
    fout << "\tjmp\t.L" << quad.z << '\n';
  } break;
  default : break;
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
	  cerr << cmd << " : Translation failed" << endl;
	  return 1;
	}
	
	if( emit_mic ) { /* Generate machine-independant code */
	  translator.emit_MIC();
	} else { /* Generate target code */
	  mm_x86_64 generator(translator);
	  generator.generateTargetCode();
	}

	return 0;
      } catch ( ... ) {
	cerr << cmd << " : Compilation failed" << endl;
	return 1;
      }
    }
  }
  
  cerr << "Error : no input files" << endl;
  return 1;
}
