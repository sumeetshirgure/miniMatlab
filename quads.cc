#include "quads.h"

std::ostream& operator<<(std::ostream& out,const Taco& taco) {
  /* TODO : write printer function for 3AC */
  switch(taco.opCode) {
  case OP_PLUS: return out << taco.z << " = " << taco.x << " + " << taco.y ;
    //case OP_MINUS: return out << z << " = " << x << " - " << y ;
  }
}
