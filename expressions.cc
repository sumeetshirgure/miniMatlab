#include "expressions.hh"


Expression::Expression() :
  isReference(false) { }

Expression::~Expression() {
  trueList.clear();
  falseList.clear();
}
