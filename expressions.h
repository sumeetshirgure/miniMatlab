#ifndef MM_EXPRESSION_H
#define MM_EXPRESSION_H

#include "symbols.h"
#include <list>

class Expression {
public:

  /* Symbol corresponding to ( temporary ) variable holding
     the value of this expression.*/
  std::pair<size_t,size_t> symbol ;

  /* In case this is a reference */
  bool isReference;
  std::pair<size_t,size_t> auxSymbol;
  
  /// TODO Later
  std::list<int> trueList , falseList;
  
  Expression();
  
  virtual ~ Expression() ;
};


#endif /* ! MM_EXPRESSION_H */
