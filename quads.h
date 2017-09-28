#ifndef MM_QUADS_H
#define MM_QUADS_H

#include <iostream>
#include <string>

enum OpCode {
  /* Binary operations */
  OP_PLUS, // z = x op y
  OP_MINUS,
  OP_MULT,
  OP_DIV,
  OP_MOD,
  OP_BIT_AND,
  OP_BIT_XOR,
  OP_BIT_OR,
  OP_SHL,
  OP_SHR,
  
  /* Unary operations */
  OP_UMINUS, // z = -x
  OP_BIT_NOT,// z = !x
  OP_COPY,   // z = x


  /* Conditional jump operations */
  OP_IF_VAL, // if x goto L
  OP_IF_NOT, // ifNot x got L
  
  OP_LT,     // if x relop y goto L
  OP_LTE,
  OP_GT,
  OP_GTE,
  OP_EQ,
  OP_NEQ,

  /* Jump operations */
  OP_GOTO,      // goto L
  
  OP_PARAM,     // push parameter
  
  OP_CALL,      // y = call p,N
  OP_RETURN,    // return v
  
  OP_FUNC_START,// function start label
  OP_FUNC_END,  // function end label
  
  OP_REFER,     // z = &x
  OP_L_DEREF,   // *z = x
  OP_R_VAL_AT,  // z = *x
  OP_LXC,       // left indexed copy : a[b] = c
  OP_RXC,       // a = b[c]
};

// Saw the opportunity and took it.
class Taco {
public:
  OpCode opCode;
  // z is result and x,y are 1st and 2nd operands respectively
  std::string z , x , y;
  Taco(OpCode code,std::string _z = "",std::string _x = "",std::string _y="") :
    opCode(code),z(_z),x(_x),y(_y){}
};

/* 3ACode printer */
std::ostream& operator<<(std::ostream& ,const Taco& ) ;

#endif /* !MM_QUADS_H */