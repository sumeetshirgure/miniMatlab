#ifndef MM_EXPRESSION_H
#define MM_EXPRESSION_H

#include "symbols.h"
#include <list>

typedef std::list<unsigned int> AddressList;

class Expression {
public:

  /* Symbol corresponding to ( temporary ) variable holding
     the value of this expression.*/
  SymbolRef symbol ;

  /* Flags if l-value */
  bool isReference;
  /* Auxiliary symbol to store offsets */
  SymbolRef auxSymbol;
  
  /// Jump statements corresponding to true/false evaluations
  AddressList trueList , falseList;
  
  Expression();
  
  virtual ~ Expression() ;
};


#endif /* ! MM_EXPRESSION_H */
