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
    fout = std::ofstream(outFileName);
  }
}

mm_x86_64::~mm_x86_64 () {
  fout.close();
}

void mm_x86_64::generateTargetCode() {

  // TODO : Generate activation records
  
  printStringTable();
}

/* Print string table contents in read-only memory section. */
void mm_x86_64::printStringTable() {
  std::vector<std::string> & stringTable = mic.stringTable;
  if(stringTable.size() > 1)
    fout << "\t.section\t.rodata\n";
  for( int idx = 1 ; idx < stringTable.size() ; idx++ )
    fout << ".LS" << idx << ":\t.string\t" << stringTable[idx] << "\n";
}

/**************************************************************************************************/

/* Main translation driver */
int main( int argc , char * argv[] ){
  using namespace std ;
  using namespace yy ;

  if(argc < 2) {
    cerr << "Enter a .mm file to translate" << endl;
    return 1;
  }
  
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
