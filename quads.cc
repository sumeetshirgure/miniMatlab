#include "quads.h"

std::ostream& operator<<(std::ostream& out,const Taco& taco) {
  switch(taco.opCode) {
  case OP_PLUS:return out<<taco.z<<" = "<<taco.x<<" + "<<taco.y;
  case OP_MINUS:return out<<taco.z<<" = "<<taco.x<<" - "<<taco.y;
  case OP_MULT:return out<<taco.z<<" = "<<taco.x<<" * "<<taco.y;
  case OP_DIV:return out<<taco.z<<" = "<<taco.x<<" / "<<taco.y;
  case OP_MOD:return out<<taco.z<<" = "<<taco.x<<" * "<<taco.y;
  case OP_BIT_AND:return out<<taco.z<<" = "<<taco.x<<" & "<<taco.y;
  case OP_BIT_XOR:return out<<taco.z<<" = "<<taco.x<<" ^ "<<taco.y;
  case OP_BIT_OR:return out<<taco.z<<" = "<<taco.x<<" | "<<taco.y;
  case OP_SHL:return out<<taco.z<<" = "<<taco.x<<" << "<<taco.y;
  case OP_SHR:return out<<taco.z<<" = "<<taco.x<<" >> "<<taco.y;

  case OP_UMINUS:return out<<taco.z<<" = - "<<taco.x;
  case OP_BIT_NOT:return out<<taco.z<<" = ~ "<<taco.x;
  case OP_COPY:return out<<taco.z<<" = "<<taco.x;

  case OP_IF_VAL:return out<<" if "<<taco.x<<" goto "<<taco.z;
  case OP_IF_NOT:return out<<" ifNot "<<taco.x<<" goto "<<taco.z;

  case OP_LT:return out<<" if "<<taco.x<<"<"<<taco.y<<" goto "<<taco.z;
  case OP_LTE:return out<<" if "<<taco.x<<"<="<<taco.y<<" goto "<<taco.z;
  case OP_GT:return out<<" if "<<taco.x<<">"<<taco.y<<" goto "<<taco.z;
  case OP_GTE:return out<<" if "<<taco.x<<">="<<taco.y<<" goto "<<taco.z;
  case OP_EQ:return out<<" if "<<taco.x<<"=="<<taco.y<<" goto "<<taco.z;
  case OP_NEQ:return out<<" if "<<taco.x<<"!="<<taco.y<<" goto "<<taco.z;
  case OP_GOTO:return out<<" goto "<<taco.z;

  case OP_PARAM:return out<<"param "<<taco.z;

  case OP_CALL:return out<<taco.z<<" = call "<<taco.x<<","<<taco.y;
  case OP_RETURN:return out<<"return "<<taco.z;

  case OP_FUNC_START:return out<<"function "<<taco.z<<" starts";
  case OP_FUNC_END:return out<<"function "<<taco.z<<" ends";

  case OP_REFER:return out<<taco.z<<" = & "<<taco.x;
  case OP_L_DEREF:return out<<"*"<<taco.z<<" = "<<taco.x;
  case OP_R_DEREF:return out<<taco.z<<" = * "<<taco.x;

  case OP_LXC:return out<<taco.z<<"[ "<<taco.x<<" ] = "<<taco.y;
  case OP_RXC:return out<<taco.z<<" = "<<taco.x<<" [ "<<taco.y<<" ]";
  default : break;
  }
  return out;
}
