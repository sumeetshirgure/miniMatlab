#include "expressions.h"


Expression::Expression():
  symbol(NULL) { }

Expression::~Expression() {
  trueList.clear();
  falseList.clear();
}
