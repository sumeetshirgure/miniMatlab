#include "expressions.h"


Expression::Expression() :
  isReference(false) { }

Expression::~Expression() {
  trueList.clear();
  falseList.clear();
}
