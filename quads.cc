#include "quads.hh"

bool Taco::isJump() const {
  return OP_IF_VAL <= opCode and opCode <= OP_GOTO ;
}

bool Taco::isCopy() const {
  return OP_COPY <= opCode and opCode <= OP_RXC ;
}

bool Taco::isBitwise() const {
  return OP_BIT_AND <= opCode and opCode <= OP_SHR or opCode == OP_BIT_NOT ;
}

bool Taco::isConversion() const {
  return OP_CONV_TO_CHAR <= opCode and opCode <= OP_CONV_TO_DOUBLE ;
}

std::ostream& operator<<(std::ostream& out,const Taco& taco) {
  switch(taco.opCode) {
  case OP_PLUS:return out<<taco.z<<" = "<<taco.x<<" + "<<taco.y;
  case OP_MINUS:return out<<taco.z<<" = "<<taco.x<<" - "<<taco.y;
  case OP_MULT:return out<<taco.z<<" = "<<taco.x<<" * "<<taco.y;
  case OP_DIV:return out<<taco.z<<" = "<<taco.x<<" / "<<taco.y;
  case OP_MOD:return out<<taco.z<<" = "<<taco.x<<" % "<<taco.y;
  case OP_BIT_AND:return out<<taco.z<<" = "<<taco.x<<" & "<<taco.y;
  case OP_BIT_XOR:return out<<taco.z<<" = "<<taco.x<<" ^ "<<taco.y;
  case OP_BIT_OR:return out<<taco.z<<" = "<<taco.x<<" | "<<taco.y;
  case OP_SHL:return out<<taco.z<<" = "<<taco.x<<" << "<<taco.y;
  case OP_SHR:return out<<taco.z<<" = "<<taco.x<<" >> "<<taco.y;

  case OP_UMINUS:return out<<taco.z<<" = - "<<taco.x;
  case OP_BIT_NOT:return out<<taco.z<<" = ~ "<<taco.x;

  case OP_IF_VAL:return out<<"if "<<taco.x<<" goto "<<taco.z;
  case OP_IF_NOT:return out<<"ifNot "<<taco.x<<" goto "<<taco.z;
  case OP_LT:return out<<"if "<<taco.x<<" < "<<taco.y<<" goto "<<taco.z;
  case OP_LTE:return out<<"if "<<taco.x<<" <= "<<taco.y<<" goto "<<taco.z;
  case OP_GT:return out<<"if "<<taco.x<<" > "<<taco.y<<" goto "<<taco.z;
  case OP_GTE:return out<<"if "<<taco.x<<" >= "<<taco.y<<" goto "<<taco.z;
  case OP_EQ:return out<<"if "<<taco.x<<" == "<<taco.y<<" goto "<<taco.z;
  case OP_NEQ:return out<<"if "<<taco.x<<" != "<<taco.y<<" goto "<<taco.z;
  case OP_GOTO:return out<<"goto "<<taco.z;
  case OP_PARAM:return out<<"param "<<taco.z;
  case OP_CALL:return out<<taco.z<<" = call "<<taco.x<<" , "<<taco.y;
  case OP_RETURN:return out<<"return "<<taco.z;
  case OP_FUNC_START:return out<<"function "<<taco.z<<" starts";
  case OP_FUNC_END:return out<<"function "<<taco.z<<" ends";

  case OP_COPY:return out<<taco.z<<" = "<<taco.x;
  case OP_REFER:return out<<taco.z<<" = & "<<taco.x;
  case OP_L_DEREF:return out<<"* "<<taco.z<<" = "<<taco.x;
  case OP_R_DEREF:return out<<taco.z<<" = * "<<taco.x;
  case OP_LXC:return out<<taco.z<<" [ "<<taco.x<<" ] = "<<taco.y;
  case OP_RXC:return out<<taco.z<<" = "<<taco.x<<" [ "<<taco.y<<" ]";

  case OP_CONV_TO_CHAR : return out<<taco.z<<" = toChar( "<<taco.x<<" )";
  case OP_CONV_TO_INT : return out<<taco.z<<" = toInt( "<<taco.x<<" )";
  case OP_CONV_TO_DOUBLE : return out<<taco.z<<" = toDouble( "<<taco.x<<" )";

  case OP_ALLOC : return out<<taco.z<<" = alloc("<<taco.x<<" , "<<taco.y<<" )";
  case OP_DEALLOC : return out<<"dealloc( "<<taco.z<<" )";

  case OP_TRANSPOSE : return out<<taco.z<<" = "<<taco.x<<".'";

  case OP_DECLARE : return out<<"Declared : "<<taco.z;
  default : break;
  }
  return out;
}
