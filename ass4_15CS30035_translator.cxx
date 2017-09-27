#include "ass4_15CS30035_translator.h"
#include "ass4_15CS30035.tab.hh"

/* Constructor for translator */
mm_translator::mm_translator() :
  trace_scan(false) , trace_parse(false) {
}

/* Destructor for translator */
mm_translator::~mm_translator() { }

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
    return 1;
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

/* Main translation driver */
int main( int argc , char * argv[] ){
  
  // read and translate files
  
  return 0;
}
