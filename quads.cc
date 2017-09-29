#include "quads.h"

std::ostream& operator<<(std::ostream& out,const Taco& taco) {
  /* TODO : write printer function for 3AC */
  switch(taco.opCode) {
  case OP_PLUS: return out << taco.z << " = " << taco.x << " + " << taco.y ;
  default : break;
  }
  return out;
}
