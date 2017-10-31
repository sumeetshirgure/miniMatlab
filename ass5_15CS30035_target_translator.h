#include "ass5_15CS30035_translator.h"

/* A map from string identifiers to locations on tables. */
typedef __gnu_pbds::trie<std::string, unsigned int ,
			 __gnu_pbds::trie_string_access_traits<> ,
			 __gnu_pbds::pat_trie_tag ,
			 __gnu_pbds::trie_prefix_search_node_update > LocMap ;

/* An element of the activation record. */
typedef std::pair< Symbol , int > Record;

/* An activation record corresponding to a function instantiation. */
class ActivationRecord {
  void dft(mm_translator&,unsigned int);
public:

  /* Constructor. */
  ActivationRecord(mm_translator&,unsigned int);
  virtual ~ActivationRecord();
  
  /* Getting position of a symbol in the record. */
  LocMap locMap , constMap;
  
  // Elements of the record.
  std::vector< Record > acR;
  // Function variables.
  std::vector< Symbol > vars;
  // Function parameters.
  std::vector< Symbol > params;
  // Table of constants.
  std::vector< Symbol > toC;
  Symbol retVal;
  
};

/* A class for generation of x86-64 miniMatlab code. */
class mm_x86_64{
public:

  static const size_t BYTE = 2 , LONG = 1 , QUAD = 0;
  
  // x86 Register array
  const std::string Regs[16][3] = {
    { "%rax" , "%eax" , "%al" } ,
    { "%rbx" , "%ebx" , "%bl" } ,
    { "%rcx" , "%ebx" , "%bl" } ,
    { "%rdx" , "%edx" , "%dl" } ,
    { "%rsi" , "%esi" , "%sil" } ,
    { "%rdi" , "%edi" , "%dil" } ,
    { "%rbp" , "%ebp" , "%bpl" } ,
    { "%rsp" , "%esp" , "%spl" } ,
    { "%r8" , "%r8d" , "%r8b" } ,
    { "%r9" , "%r9d" , "%r9b" } ,
    { "%r10" , "%r10d" , "%r10b" } ,
    { "%r11" , "%r11d" , "%r11b" } ,
    { "%r12" , "%r12d" , "%r12b" } ,
    { "%r13" , "%r13d" , "%r13b" } ,
    { "%r14" , "%r14d" , "%r14b" } ,
    { "%r15" , "%r15d" , "%r15b" }
  } , XReg = "%xmm" ;
  
  mm_x86_64(mm_translator&);
  virtual ~mm_x86_64();
  
  /* Reference to machine independant code and data. */
  mm_translator & mic;
  
  /* Output file stream to write generated .asm file. */
  std::ofstream fout;

  /* Output the entire target code. */
  void generateTargetCode();

  /* Function code generation. */
  void emitFunction(unsigned int, unsigned int, unsigned int);
  
  /* Emit target code corresponding to a jump instruction quad. */
  void emitJumpOps(const Taco &,const ActivationRecord &, mm_translator &);

  /* Auxiliary data */
  std::vector<int> usedConstants; // constant ids actually used
};
