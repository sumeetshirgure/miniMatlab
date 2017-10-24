#include "ass5_15CS30035_translator.h"

class mm_x86_64{
public:
  
  /* Reference to machine independant code and data. */
  mm_translator & mic;

  /* Output file stream to write generated .asm file. */
  std::ofstream fout;

  /* Output the target code. */
  void generateTargetCode();
  
  /* Write strings to read-only data segment. */
  void printStringTable();
  
  mm_x86_64(mm_translator&);
  virtual ~mm_x86_64();
};
