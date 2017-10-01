/* -*- C++  LALR1 Parser specification -*- */
%skeleton "lalr1.cc"
%require "3.0.4"
%defines
%define parser_class_name {mm_parser};

/* Generate token constructors */
%define api.token.constructor;

/* Use C++ variant semantic values */
%define api.value.type variant;
%define parse.assert;

%code requires {
#include <string>
#include "types.h"
#include "symbols.h"
#include "expressions.h"
  class mm_translator;
 }

/* A translator object is used to construct its parser. */
%param {mm_translator &translator};

%code {
  /* Include translator definitions completely */
#include "ass4_15CS30035_translator.h"
 }

/* Enable bison location tracking */
%locations;

/* Initialize the parser location to the new file */
%initial-action{
  @$.initialize( &translator.file );
 }

/* Enable verobse parse tracing */
%define parse.trace;
%define parse.error verbose;

/* Prefix all token constants with TOK_ */
%define api.token.prefix {TOK_};


/**************************************************/
/**********Begin token definitions*****************/
%token
END 0 "EOF"
MM_IF "if"
MM_ELSE "else"
MM_DO "do"
MM_WHILE "while"
MM_FOR "for"
MM_RETURN "return"
MM_VOID "void"
MM_CHAR "char"
MM_INT "int"
MM_DOUBLE "double"
MM_MATRIX "Matrix"

LBRACE "{"
RBRACE "}"
LBOX "["
RBOX "]"
LBRACKET "("
RBRACKET ")"

INC "++"
DEC "--"
SHL "<<"
SHR ">>"
AND "&&"
OR "||"
TRANSPOSE ".'"

AMPERSAND "&"
CARET "^"
BAR "|"
NOT "!"

STAR "*"
PLUS "+"
MINUS "-"
SLASH "/"
TILDE "~"
PERCENT "%"
ASSGN "="

LT "<"
GT ">"
LTE "<="
GTE ">="
EQUAL "=="
NEQ "!="

QMARK "?"
COLON ":"
SEMICOLON ";"
COMMA ","
;

%token <std::string> IDENTIFIER STRING_LITERAL ;
%token <char> CHARACTER_CONSTANT ;

/* Only 32-bit signed integer is supported for now */
%token <int> INTEGER_CONSTANT ;

/* All float-point arithmetic is in double precision only */
%token <double> FLOATING_CONSTANT ;

/************End token definitions*****************/
/**************************************************/



/* Parse debugger */
%printer { yyoutput << $$ ; } <int> ;
%printer { yyoutput << $$ ; } <double> ;
%printer { yyoutput << $$ ; } <std::string> ;

%%

/**********************************************************************/
/*********************EXPRESSION NON-TERMINALS*************************/
/**********************************************************************/

%type <Expression> primary_expression;
primary_expression :
IDENTIFIER {
  int scope = translator.currentEnvironment();
  bool found = false;
  for( ; scope != 0 ; scope = translator.tables[scope].parent ) {
    try {
      $$.symbol.second = translator.tables[scope].lookup($1);
      $$.symbol.first = scope;
      found = true;
    } catch ( ... ) {
    }
  }
  try {
    $$.symbol.second = translator.tables[0].lookup($1);
    $$.symbol.first = scope;
    found = true;
  } catch ( ... ) {
  }
  if(not found) {
    throw syntax_error(@$ , "Identifier :"+$1+" not declared in scope.") ;
  }

}
|
INTEGER_CONSTANT {
  DataType intType = MM_INT_TYPE;
  std::pair<size_t,size_t> ref = translator.genTemp(intType);
  Symbol & temp = translator.getSymbol(ref);
  temp.value.intVal = $1;
  temp.isInitialized = true;
  $$.symbol = ref;
  translator.emit(Taco(OP_COPY,temp.id,std::to_string($1)));
}
|
FLOATING_CONSTANT {
  DataType doubleType = MM_DOUBLE_TYPE;
  std::pair<size_t,size_t> ref = translator.genTemp(doubleType);
  Symbol & temp = translator.getSymbol(ref);
  temp.value.doubleVal = $1;
  temp.isInitialized = true;
  $$.symbol = ref;
  translator.emit(Taco(OP_COPY,temp.id,std::to_string($1)));
}
|
CHARACTER_CONSTANT {
  DataType charType = MM_CHAR_TYPE;
  std::pair<size_t,size_t> ref = translator.genTemp(charType);
  Symbol & temp = translator.getSymbol(ref);
  temp.value.charVal = $1;
  temp.isInitialized = true;
  $$.symbol = ref;
  translator.emit(Taco(OP_COPY,temp.id,std::to_string($1)));  
}
|
STRING_LITERAL {
  DataType charPointerType = MM_CHAR_TYPE;
  charPointerType.pointers++;
  std::pair<size_t,size_t> ref = translator.genTemp(charPointerType);
  Symbol & temp = translator.getSymbol(ref);
  $$.symbol = ref;
}
|
"(" expression ")" {
  std::swap($$,$2);
}
;

%type <Expression> postfix_expression;
postfix_expression:
primary_expression {
  std::swap($$,$1);
}
|
/* Dereference matrix element. Empty expression not allowed.
   exactly two addresses are required */
postfix_expression "[" expression "]" "[" expression "]" {
  Symbol & lSym = translator.getSymbol($1.symbol);
  std::swap($$,$1);
  
  if( !$$.isReference and lSym.type.isProperMatrix() ) {// valid matrix

    Symbol & rowIndex = translator.getSymbol($3.symbol);
    Symbol & colIndex = translator.getSymbol($6.symbol);
    
    if( rowIndex.type != MM_INT_TYPE or colIndex.type != MM_INT_TYPE ) {
      throw syntax_error(@$ , "Non-integral index for matrix " + lSym.id + "." );
    }

    std::pair<size_t,size_t> tempRef = translator.genTemp(rowIndex.type);
    Symbol & temp = translator.getSymbol(tempRef);
    
    translator.emit(Taco(OP_MULT,temp.id,rowIndex.id,std::to_string(lSym.type.cols)));
    translator.emit(Taco(OP_PLUS,temp.id,temp.id,colIndex.id));
    translator.emit(Taco(OP_MULT,temp.id,temp.id,std::to_string(SIZE_OF_DOUBLE)));
    translator.emit(Taco(OP_PLUS,temp.id,temp.id,std::to_string(2*SIZE_OF_INT)));
    
    $$.auxSymbol = tempRef;
    $$.isReference = true;
  } else {
    throw syntax_error(@$ , "Invalid type for subscripting.");
  }
}
|
/* Function call */
postfix_expression "(" optional_argument_list ")" {
  Symbol & lSym = translator.getSymbol($1.symbol);
  std::swap($$,$1);
  if( lSym.type != MM_FUNC_TYPE or lSym.child == 0 ) {
    throw syntax_error( @$ , lSym.id + " is not a defined function." );
  } else {
    bool paramCheck = true;
    std::vector<Expression> & paramList = $3;
    SymbolTable & symTable = translator.tables[lSym.child];
    if( paramList.size() != symTable.params ) {
      paramCheck = false;
    } else {
      for(int idx = 0;idx < paramList.size(); idx++ ) {
	Symbol & parameter = translator.getSymbol(paramList[idx].symbol);
	if( symTable.table[idx+1].type != parameter.type ) {
	  paramCheck = false;
	  break;
	}
	translator.emit(Taco(OP_PARAM,parameter.id));
      }
    }
    if( not paramCheck ) {
      throw syntax_error(@$, lSym.id + " is not called with proper parameters." );
    }
    std::pair<size_t,size_t> retRef = translator.genTemp(symTable.table[0].type);
    Symbol & retVal = translator.getSymbol(retRef);
    translator.emit(Taco(OP_CALL,retVal.id,lSym.id,std::to_string(paramList.size())));
    $$.symbol = retRef;
    $$.isReference = false;
  }

}
|
postfix_expression "++" {
  Symbol & lSym = translator.getSymbol($1.symbol);
  std::swap($$,$1); // copy everything
  DataType & type = lSym.type;
  if( $$.isReference ) {// first dereference then assign
    if( lSym.type.isPointer() ) {
      DataType elementType = lSym.type;
      elementType.pointers--;
      if( elementType.isPointer() ){
	throw syntax_error( @$ , "Pointer arithmetic not supported yet.");
      }
      if( elementType!=MM_CHAR_TYPE and elementType!=MM_INT_TYPE and elementType!=MM_DOUBLE_TYPE ) {
	throw syntax_error(@$ , "Invalid operand.");
      }
      std::pair<size_t,size_t> retRef = translator.genTemp(elementType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      translator.emit(Taco(OP_R_DEREF,retSymbol.id,lSym.id));// ret = *v
      std::pair<size_t,size_t> newRef = translator.genTemp(elementType);
      Symbol & newSymbol = translator.getSymbol(newRef);
      translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,"1"));// temp = ret+1
      translator.emit(Taco(OP_L_DEREF,lSym.id,newSymbol.id));//copy back : *v = temp
      $$.symbol = retRef;// returns ret
    } else if( lSym.type.isProperMatrix() ) { // reference to matrix element
      DataType elementType = MM_DOUBLE_TYPE;
      Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
      std::pair<size_t,size_t> retRef = translator.genTemp(elementType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      translator.emit(Taco(OP_RXC,retSymbol.id,lSym.id,auxSymbol.id));// ret = m[off]
      std::pair<size_t,size_t> newRef = translator.genTemp(elementType);
      Symbol & newSymbol = translator.getSymbol(newRef);
      translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,"1"));// temp = ret+1
      translator.emit(Taco(OP_LXC,lSym.id,auxSymbol.id,newSymbol.id));//copy back : m[off] = temp
      $$.symbol = retRef;
      $$.isReference = false;
    } else {
      throw syntax_error(@$, "Invalid operand." );
    }
  } else if( type == MM_CHAR_TYPE or type == MM_INT_TYPE or type == MM_DOUBLE_TYPE ) {
    std::pair<size_t,size_t> tempRef = translator.genTemp(type);
    Symbol & temp = translator.getSymbol(tempRef);
    translator.emit(Taco(OP_COPY,temp.id,lSym.id));
    translator.emit(Taco(OP_PLUS,lSym.id,lSym.id,"1"));
    $$.symbol = tempRef;
  } else if( lSym.type.isPointer() ) {
    /* TODO : support pointer arithmetic */
    throw syntax_error( @$ , "Pointer arithmetic not supported yet.");
  } else {
    throw syntax_error(@$, "Invalid operand." );
  } // this expression now refers to the value before incrementation

}
|
postfix_expression "--" {
  throw syntax_error(@$ , "TODO.");
}
|
postfix_expression ".'" {
  /* TODO : Support matrix transposition */
  throw syntax_error(@$, "Matrix transpose not supported yet.");
}
;

%type < std::vector<Expression> > optional_argument_list;
optional_argument_list :
%empty {
}
|
argument_list {
  std::swap($$,$1);
}
;

%type < std::vector<Expression> > argument_list;
argument_list :
expression {
  $$.push_back($1);
}
|
argument_list "," expression {
  swap($$,$1);
  $$.push_back($3);
}
;

%type <Expression> unary_expression;
unary_expression :
postfix_expression {
  std::swap($$,$1); // copy everything
}
|
"++" unary_expression {
  throw syntax_error(@$, "TODO.");
}
|
"--" unary_expression {
  throw syntax_error(@$, "TODO.");
}
|
unary_operator unary_expression {
  Symbol & rSym = translator.getSymbol($2.symbol);
  std::swap($$,$2);// copy all
  switch($1) {
  case '&' : {
    if( $$.isReference ) { // double * x = & m[a][b] ; int *x = &(*v);
      if( rSym.type.isPointer() ) {
	std::pair<size_t,size_t> retRef = translator.genTemp(rSym.type);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_COPY,retSymbol.id,rSym.id));
	$$.symbol = retRef;
      } else if( rSym.type.isProperMatrix() ) { // reference to matrix element
	DataType pointerType = MM_DOUBLE_TYPE;
	pointerType.pointers++;
	std::pair<size_t,size_t> retRef = translator.genTemp(pointerType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_REFER,retSymbol.id,rSym.id)); // take address of base
	Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
	translator.emit(Taco(OP_PLUS,retSymbol.id,retSymbol.id,auxSymbol.id)); // take address of base	
	$$.symbol = retRef;
      } else {
	throw syntax_error(@$, "Invalid operand to take reference." );
      }
    } else if ( rSym.type.isPointer() or rSym.type == MM_CHAR_TYPE or
		rSym.type == MM_INT_TYPE or rSym.type == MM_DOUBLE_TYPE or
		rSym.type.isProperMatrix() ) { // proper matrix
      if( translator.isTemporary($$.symbol) ) {
	// cannot take reference of compiler generated temporary
	throw syntax_error(@$ , "Invalid operand to take reference.");
      }
      DataType pointerType = rSym.type;
      pointerType.pointers++;
      std::pair<size_t,size_t> retRef = translator.genTemp(pointerType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      translator.emit(Taco(OP_REFER,retSymbol.id,rSym.id));
      $$.symbol = retRef;
    } else {
      throw syntax_error(@$ , "Invalid operand to take reference.");
    }
    $$.isReference = false;
  } break;
  case '*' : {
    if( rSym.type.isPointer() ) {
      DataType elementType = rSym.type; elementType.pointers--;
      if( elementType.isPointer() ) {
	std::pair<size_t,size_t> retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_R_DEREF,retSymbol.id,rSym.id));
	$$.symbol = retRef;
	$$.isReference = true;
      } else {
	// just turn reference flag on for possible dereferencing
	$$.isReference = true;
      }
    } else {
      throw syntax_error(@$ , "Cannot dereference non-pointer type.");
    }

  } break;
  case '+' : {
    if( $$.isReference ) {// (+m[a][b]) is not an lvalue. we must dereference
      if( rSym.type.isPointer() ) {
	DataType elementType = rSym.type;
	elementType.pointers--;
	if( elementType.isPointer() ) {
	  throw syntax_error(@$ , "Pointer arithmetic not supported yet." );
	}
	if( elementType!=MM_CHAR_TYPE and elementType!=MM_INT_TYPE and elementType!=MM_DOUBLE_TYPE ) {
	  throw syntax_error(@$ , "Invalid operand.");
	}
	std::pair<size_t,size_t> retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_R_DEREF,retSymbol.id,rSym.id));// ret = *x
	$$.symbol = retRef;
      } else if( rSym.type.isProperMatrix() ){
	DataType elementType = MM_DOUBLE_TYPE;
	std::pair<size_t,size_t> retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
	translator.emit(Taco(OP_RXC,retSymbol.id,rSym.id,auxSymbol.id));// ret = m[off]
	$$.symbol = retRef;
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
      $$.isReference = false;
    } else if( rSym.type.isPointer() ) {
      throw syntax_error(@$ , "Pointer arithmetic not supported yet." );
    } else if( rSym.type == MM_VOID_TYPE or rSym.type == MM_BOOL_TYPE or rSym.type == MM_FUNC_TYPE ) {
      throw syntax_error(@$ , "Invalid type for unary plus.");
    } else { // generate temporary. Potentially copy entire matrices?
	DataType elementType = rSym.type;
	std::pair<size_t,size_t> retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_COPY,retSymbol.id,rSym.id));// ret = x
    }

  } break;
  case '-' : {
    if( $$.isReference ) {//dereference and negate
      if( rSym.type.isPointer() ) {
	DataType elementType = rSym.type;
	elementType.pointers--;
	if( elementType.isPointer() ) {
	  throw syntax_error(@$ , "Pointer arithmetic not supported yet." );
	}
	if( elementType!=MM_CHAR_TYPE and elementType!=MM_INT_TYPE and elementType!=MM_DOUBLE_TYPE ) {
	  throw syntax_error(@$ , "Invalid operand.");
	}
	std::pair<size_t,size_t> retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_R_DEREF,retSymbol.id,rSym.id));// ret = *x
	$$.symbol = retRef;
      } else if( rSym.type.isProperMatrix() ){
	DataType elementType = MM_DOUBLE_TYPE;
	std::pair<size_t,size_t> retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
	translator.emit(Taco(OP_RXC,retSymbol.id,rSym.id,auxSymbol.id));// ret = m[off]
	$$.symbol = retRef;
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
      $$.isReference = false;
      Symbol & retSymbol = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_UMINUS,retSymbol.id,retSymbol.id));
    } else if( rSym.type.isPointer() ) {
      throw syntax_error(@$ , "Pointer arithmetic not supported yet." );
    } else if( rSym.type.isProperMatrix() ) { // can negate matrix
      throw syntax_error(@$ , "Matrix arithmetic not supported yet." );
    } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE or rSym.type == MM_DOUBLE_TYPE ) {
      std::pair<size_t,size_t> retRef = translator.genTemp(rSym.type);
      Symbol & retSymbol = translator.getSymbol(retRef);
      translator.emit(Taco(OP_UMINUS,retSymbol.id,rSym.id));
      $$.symbol = retRef;
    } else {
      throw syntax_error(@$ , "Invalid type for unary minus.");
    }
  } break;
  default: throw syntax_error(@$ , "Unknown unary operator.");
  }

}
;

%type <char> unary_operator;
unary_operator :
 "&" { $$ = '&'; }
|"*" { $$ = '*'; }
|"+" { $$ = '+'; }
|"-" { $$ = '-'; }

%type <Expression> cast_expression;
cast_expression :
unary_expression {
  std::swap($$,$1);
}

%type <Expression> multiplicative_expression;
multiplicative_expression :
cast_expression {
  std::swap($$,$1);
}
|
multiplicative_expression "*" cast_expression {
  Symbol & lSym = translator.getSymbol( $1.symbol );
  Symbol & rSym = translator.getSymbol( $3.symbol );
  
  std::pair<size_t,size_t> LHR , RHR;

  if( $1.isReference ) {
    if( lSym.type.isPointer() ) {
      DataType elementType = lSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE
	  or elementType == MM_DOUBLE_TYPE ) {
	LHR = translator.genTemp(elementType);
	Symbol & LHS = translator.getSymbol(LHR);
	translator.emit(Taco(OP_R_DEREF,LHS.id,lSym.id));// lhs = *lSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else if( lSym.type.isProperMatrix() ) {
      DataType elementType = MM_DOUBLE_TYPE;
      LHR = translator.genTemp(elementType);
      Symbol & LHS = translator.getSymbol(LHR);
      Symbol & auxSymbol = translator.getSymbol($1.auxSymbol);
      translator.emit(Taco(OP_RXC,LHS.id,lSym.id,auxSymbol.id));// lhs = m[off]
    } else {
      throw syntax_error(@$ , "Invalid operand.");      
    }
  } else if( lSym.type == MM_CHAR_TYPE or lSym.type == MM_INT_TYPE or lSym.type == MM_DOUBLE_TYPE ) {
    LHR = $1.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }

  if( $3.isReference ) {
    if( rSym.type.isPointer() ) {
      DataType elementType = rSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE
	  or elementType == MM_DOUBLE_TYPE ) {
	RHR = translator.genTemp(elementType);
	Symbol & RHS = translator.getSymbol(RHR);
	translator.emit(Taco(OP_R_DEREF,RHS.id,rSym.id));// rhs = *rSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else if( rSym.type.isProperMatrix() ) {
      DataType elementType = MM_DOUBLE_TYPE;
      RHR = translator.genTemp(elementType);
      Symbol & RHS = translator.getSymbol(RHR);
      Symbol & auxSymbol = translator.getSymbol($3.auxSymbol);
      translator.emit(Taco(OP_RXC,RHS.id,rSym.id,auxSymbol.id));// rhs = m[off]
    } else {
      throw syntax_error(@$ , "Invalid operand.");
    }
  } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE or rSym.type == MM_DOUBLE_TYPE ) {
    RHR = $3.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }

  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType == MM_VOID_TYPE ) {
    throw syntax_error(@$ , "Invalid operands." );
  }
  
  // TACos for conversion from one basic type to another ?
  std::pair<size_t,size_t> retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  translator.emit(Taco(OP_MULT,retSymbol.id,LHS.id,RHS.id));
  $$.symbol = retRef;

}
|
multiplicative_expression "/" cast_expression {
  Symbol & lSym = translator.getSymbol( $1.symbol );
  Symbol & rSym = translator.getSymbol( $3.symbol );
  std::pair<size_t,size_t> LHR , RHR;
  if( $1.isReference ) {
    if( lSym.type.isPointer() ) {
      DataType elementType = lSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE
	  or elementType == MM_DOUBLE_TYPE ) {
	LHR = translator.genTemp(elementType);
	Symbol & LHS = translator.getSymbol(LHR);
	translator.emit(Taco(OP_R_DEREF,LHS.id,lSym.id));// lhs = *lSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else if( lSym.type.isProperMatrix() ) {
      DataType elementType = MM_DOUBLE_TYPE;
      LHR = translator.genTemp(elementType);
      Symbol & LHS = translator.getSymbol(LHR);
      Symbol & auxSymbol = translator.getSymbol($1.auxSymbol);
      translator.emit(Taco(OP_RXC,LHS.id,lSym.id,auxSymbol.id));// lhs = m[off]
    } else {
      throw syntax_error(@$ , "Invalid operand.");      
    }
  } else if( lSym.type == MM_CHAR_TYPE or lSym.type == MM_INT_TYPE or lSym.type == MM_DOUBLE_TYPE ) {
    LHR = $1.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  if( $3.isReference ) {
    if( rSym.type.isPointer() ) {
      DataType elementType = rSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE
	  or elementType == MM_DOUBLE_TYPE ) {
	RHR = translator.genTemp(elementType);
	Symbol & RHS = translator.getSymbol(RHR);
	translator.emit(Taco(OP_R_DEREF,RHS.id,rSym.id));// rhs = *rSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else if( rSym.type.isProperMatrix() ) {
      DataType elementType = MM_DOUBLE_TYPE;
      RHR = translator.genTemp(elementType);
      Symbol & RHS = translator.getSymbol(RHR);
      Symbol & auxSymbol = translator.getSymbol($3.auxSymbol);
      translator.emit(Taco(OP_RXC,RHS.id,rSym.id,auxSymbol.id));// rhs = m[off]
    } else {
      throw syntax_error(@$ , "Invalid operand.");
    }
  } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE or rSym.type == MM_DOUBLE_TYPE ) {
    RHR = $3.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType == MM_VOID_TYPE ) {
    throw syntax_error(@$ , "Invalid operands." );
  }
  // TACos for conversion from one basic type to another ?
  std::pair<size_t,size_t> retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  translator.emit(Taco(OP_DIV,retSymbol.id,LHS.id,RHS.id));
  $$.symbol = retRef;

}
|
multiplicative_expression "%" cast_expression {
  Symbol & lSym = translator.getSymbol( $1.symbol );
  Symbol & rSym = translator.getSymbol( $3.symbol );
  std::pair<size_t,size_t> LHR , RHR;
  if( $1.isReference ) {
    if( lSym.type.isPointer() ) {
      DataType elementType = lSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE ) {
	LHR = translator.genTemp(elementType);
	Symbol & LHS = translator.getSymbol(LHR);
	translator.emit(Taco(OP_R_DEREF,LHS.id,lSym.id));// lhs = *lSym
      } else { // double
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else {
      throw syntax_error(@$ , "Invalid operand.");      
    }
  } else if( lSym.type == MM_CHAR_TYPE or lSym.type == MM_INT_TYPE ) {
    LHR = $1.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  if( $3.isReference ) {
    if( rSym.type.isPointer() ) {
      DataType elementType = rSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE ) {
	RHR = translator.genTemp(elementType);
	Symbol & RHS = translator.getSymbol(RHR);
	translator.emit(Taco(OP_R_DEREF,RHS.id,rSym.id));// rhs = *rSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else {
      throw syntax_error(@$ , "Invalid operand.");
    }
  } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE ) {
    RHR = $3.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType != MM_CHAR_TYPE and retType != MM_INT_TYPE ) {
    throw syntax_error(@$ , "Invalid operands." );
  }
  // TACos for conversion from one basic type to another ?
  std::pair<size_t,size_t> retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  translator.emit(Taco(OP_MOD,retSymbol.id,LHS.id,RHS.id));
  $$.symbol = retRef;

}
;

%type <Expression> additive_expression;
additive_expression :
multiplicative_expression {
  std::swap($$,$1);
}
|
additive_expression "+" multiplicative_expression {
  Symbol & lSym = translator.getSymbol( $1.symbol );
  Symbol & rSym = translator.getSymbol( $3.symbol );
  
  std::pair<size_t,size_t> LHR , RHR;

  if( $1.isReference ) {
    if( lSym.type.isPointer() ) {
      DataType elementType = lSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE
	  or elementType == MM_DOUBLE_TYPE ) {
	LHR = translator.genTemp(elementType);
	Symbol & LHS = translator.getSymbol(LHR);
	translator.emit(Taco(OP_R_DEREF,LHS.id,lSym.id));// lhs = *lSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else if( lSym.type.isProperMatrix() ) {
      DataType elementType = MM_DOUBLE_TYPE;
      LHR = translator.genTemp(elementType);
      Symbol & LHS = translator.getSymbol(LHR);
      Symbol & auxSymbol = translator.getSymbol($1.auxSymbol);
      translator.emit(Taco(OP_RXC,LHS.id,lSym.id,auxSymbol.id));// lhs = m[off]
    } else {
      throw syntax_error(@$ , "Invalid operand.");      
    }
  } else if( lSym.type == MM_CHAR_TYPE or lSym.type == MM_INT_TYPE or lSym.type == MM_DOUBLE_TYPE ) {
    LHR = $1.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }

  if( $3.isReference ) {
    if( rSym.type.isPointer() ) {
      DataType elementType = rSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE
	  or elementType == MM_DOUBLE_TYPE ) {
	RHR = translator.genTemp(elementType);
	Symbol & RHS = translator.getSymbol(RHR);
	translator.emit(Taco(OP_R_DEREF,RHS.id,rSym.id));// rhs = *rSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else if( rSym.type.isProperMatrix() ) {
      DataType elementType = MM_DOUBLE_TYPE;
      RHR = translator.genTemp(elementType);
      Symbol & RHS = translator.getSymbol(RHR);
      Symbol & auxSymbol = translator.getSymbol($3.auxSymbol);
      translator.emit(Taco(OP_RXC,RHS.id,rSym.id,auxSymbol.id));// rhs = m[off]
    } else {
      throw syntax_error(@$ , "Invalid operand.");
    }
  } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE or rSym.type == MM_DOUBLE_TYPE ) {
    RHR = $3.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  /* TODO : support matrix addition /subtraction */

  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType == MM_VOID_TYPE ) {
    throw syntax_error(@$ , "Invalid operands." );
  }
  
  // TACos for conversion from one basic type to another ?
  std::pair<size_t,size_t> retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  translator.emit(Taco(OP_PLUS,retSymbol.id,LHS.id,RHS.id));
  $$.symbol = retRef;

}
|
additive_expression "-" multiplicative_expression {
  Symbol & lSym = translator.getSymbol( $1.symbol );
  Symbol & rSym = translator.getSymbol( $3.symbol );
  
  std::pair<size_t,size_t> LHR , RHR;

  if( $1.isReference ) {
    if( lSym.type.isPointer() ) {
      DataType elementType = lSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE
	  or elementType == MM_DOUBLE_TYPE ) {
	LHR = translator.genTemp(elementType);
	Symbol & LHS = translator.getSymbol(LHR);
	translator.emit(Taco(OP_R_DEREF,LHS.id,lSym.id));// lhs = *lSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else if( lSym.type.isProperMatrix() ) {
      DataType elementType = MM_DOUBLE_TYPE;
      LHR = translator.genTemp(elementType);
      Symbol & LHS = translator.getSymbol(LHR);
      Symbol & auxSymbol = translator.getSymbol($1.auxSymbol);
      translator.emit(Taco(OP_RXC,LHS.id,lSym.id,auxSymbol.id));// lhs = m[off]
    } else {
      throw syntax_error(@$ , "Invalid operand.");      
    }
  } else if( lSym.type == MM_CHAR_TYPE or lSym.type == MM_INT_TYPE or lSym.type == MM_DOUBLE_TYPE ) {
    LHR = $1.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }

  if( $3.isReference ) {
    if( rSym.type.isPointer() ) {
      DataType elementType = rSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE
	  or elementType == MM_DOUBLE_TYPE ) {
	RHR = translator.genTemp(elementType);
	Symbol & RHS = translator.getSymbol(RHR);
	translator.emit(Taco(OP_R_DEREF,RHS.id,rSym.id));// rhs = *rSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else if( rSym.type.isProperMatrix() ) {
      DataType elementType = MM_DOUBLE_TYPE;
      RHR = translator.genTemp(elementType);
      Symbol & RHS = translator.getSymbol(RHR);
      Symbol & auxSymbol = translator.getSymbol($3.auxSymbol);
      translator.emit(Taco(OP_RXC,RHS.id,rSym.id,auxSymbol.id));// rhs = m[off]
    } else {
      throw syntax_error(@$ , "Invalid operand.");
    }
  } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE or rSym.type == MM_DOUBLE_TYPE ) {
    RHR = $3.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  /* TODO : support matrix addition /subtraction */
  
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType == MM_VOID_TYPE ) {
    throw syntax_error(@$ , "Invalid operands." );
  }
  
  // TACos for conversion from one basic type to another ?
  std::pair<size_t,size_t> retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  translator.emit(Taco(OP_MINUS,retSymbol.id,LHS.id,RHS.id));
  $$.symbol = retRef;

}
;

%type <Expression> shift_expression;
shift_expression :
additive_expression {
  std::swap($$,$1);
}
|
shift_expression "<<" additive_expression {
  Symbol & lSym = translator.getSymbol( $1.symbol );
  Symbol & rSym = translator.getSymbol( $3.symbol );
  std::pair<size_t,size_t> LHR , RHR;
  if( $1.isReference ) {
    if( lSym.type.isPointer() ) {
      DataType elementType = lSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE ) {
	LHR = translator.genTemp(elementType);
	Symbol & LHS = translator.getSymbol(LHR);
	translator.emit(Taco(OP_R_DEREF,LHS.id,lSym.id));// lhs = *lSym
      } else { // double 
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else {
      throw syntax_error(@$ , "Invalid operand.");      
    }
  } else if( lSym.type == MM_CHAR_TYPE or lSym.type == MM_INT_TYPE ) {
    LHR = $1.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  if( $3.isReference ) {
    if( rSym.type.isPointer() ) {
      DataType elementType = rSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE ) {
	RHR = translator.genTemp(elementType);
	Symbol & RHS = translator.getSymbol(RHR);
	translator.emit(Taco(OP_R_DEREF,RHS.id,rSym.id));// rhs = *rSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else {
      throw syntax_error(@$ , "Invalid operand.");
    }
  } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE ) {
    RHR = $3.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType != MM_CHAR_TYPE and retType != MM_INT_TYPE ) {
    throw syntax_error(@$ , "Invalid operands." );
  }
  // TACos for conversion from one basic type to another ?
  std::pair<size_t,size_t> retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  translator.emit(Taco(OP_SHL,retSymbol.id,LHS.id,RHS.id));
  $$.symbol = retRef;

}
|
shift_expression ">>" additive_expression {
  Symbol & lSym = translator.getSymbol( $1.symbol );
  Symbol & rSym = translator.getSymbol( $3.symbol );
  std::pair<size_t,size_t> LHR , RHR;
  if( $1.isReference ) {
    if( lSym.type.isPointer() ) {
      DataType elementType = lSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE ) {
	LHR = translator.genTemp(elementType);
	Symbol & LHS = translator.getSymbol(LHR);
	translator.emit(Taco(OP_R_DEREF,LHS.id,lSym.id));// lhs = *lSym
      } else { // double 
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else {
      throw syntax_error(@$ , "Invalid operand.");      
    }
  } else if( lSym.type == MM_CHAR_TYPE or lSym.type == MM_INT_TYPE ) {
    LHR = $1.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  if( $3.isReference ) {
    if( rSym.type.isPointer() ) {
      DataType elementType = rSym.type; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE ) {
	RHR = translator.genTemp(elementType);
	Symbol & RHS = translator.getSymbol(RHR);
	translator.emit(Taco(OP_R_DEREF,RHS.id,rSym.id));// rhs = *rSym
      } else {
	throw syntax_error(@$ , "Invalid operand.");
      }
    } else {
      throw syntax_error(@$ , "Invalid operand.");
    }
  } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE ) {
    RHR = $3.symbol;
  } else {
    throw syntax_error(@$ , "Invalid operand.");
  }
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType != MM_CHAR_TYPE and retType != MM_INT_TYPE ) {
    throw syntax_error(@$ , "Invalid operands." );
  }
  // TACos for conversion from one basic type to another ?
  std::pair<size_t,size_t> retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  translator.emit(Taco(OP_SHR,retSymbol.id,LHS.id,RHS.id));
  $$.symbol = retRef;

}
;

%type <Expression> relational_expression;
relational_expression :
shift_expression {
  std::swap($$,$1);
}
|
relational_expression "<" shift_expression {
  
}
|
relational_expression ">" shift_expression {
  
}
|
relational_expression "<=" shift_expression {
  
}
|
relational_expression ">=" shift_expression {
  // TODO
}
;

%type <Expression> equality_expression;
equality_expression :
relational_expression {
  std::swap($$,$1);
}
|
equality_expression "==" relational_expression {

}
|
equality_expression "!=" relational_expression {

}
;

%type <Expression> AND_expression;
AND_expression :
equality_expression {
  std::swap($$,$1);
}
|
AND_expression "&" equality_expression {

}
;

%type <Expression> XOR_expression;
XOR_expression :
AND_expression {
  std::swap($$,$1);
}
|
XOR_expression "^" AND_expression {

}
;

%type <Expression> OR_expression;
OR_expression :
XOR_expression {
  std::swap($$,$1);
}
|
OR_expression "|" XOR_expression {

}
;

%type <Expression> logical_AND_expression;
logical_AND_expression :
OR_expression {
  std::swap($$,$1);
}
|
logical_AND_expression "&&" OR_expression {

}
;

%type <Expression> logical_OR_expression;
logical_OR_expression :
logical_AND_expression {
  std::swap($$,$1);
}
|
logical_OR_expression "||" logical_AND_expression {

}
;

%type <Expression> conditional_expression;
conditional_expression :
logical_OR_expression {
  std::swap($$,$1);
}
|
logical_OR_expression "?" expression ":" conditional_expression {
  
}
;

%type <Expression> assignment_expression;
assignment_expression :
conditional_expression {
  std::swap($$,$1);
}
|
unary_expression "=" assignment_expression {
  // TODO write type checker functions.
  // Emit assignment tacos
}
;

%type <Expression> expression;
expression :
assignment_expression {
  std::swap($$,$1);
  /*
  DataType type = MM_INT_TYPE;
  $$.symbol = translator.genTemp(type);
  $$.isReference = false;
  */
}
;

/**********************************************************************/




/**********************************************************************/
/*********************DECLARATION NON-TERMINALS************************/
/**********************************************************************/

/* Empty declarator list not supported */
/* i.e : `int ;' is not syntactically correct */
/* Also since only one type specifier is supported , `declaration_specifiers' is omitted */
declaration :
type_specifier initialized_declarator_list ";" {
  
  translator.typeContext.pop();
}
;

%type <DataType> type_specifier;
type_specifier :
"void" {
  translator.typeContext.push( MM_VOID_TYPE );
}
|
"char" {
  translator.typeContext.push( MM_CHAR_TYPE );
}
|
"int" {
  translator.typeContext.push( MM_INT_TYPE );
}
|
"double" {
  translator.typeContext.push( MM_DOUBLE_TYPE );
}
|
"Matrix" {
  translator.typeContext.push( MM_MATRIX_TYPE );
}
;

initialized_declarator_list :
initialized_declarator {
  
}
|
initialized_declarator_list "," initialized_declarator {

}
;

initialized_declarator :
declarator {
  
}
|
declarator "=" initializer {
  /* TODO : check types and optionally initalize expression */
  // also consider init_decl -> decl = asgn_expr | init_row_list
  
}
;

%type < std::pair<size_t,size_t> > declarator;
declarator :
optional_pointer direct_declarator {
  $$ = $2;
  Symbol & symbol = translator.getSymbol($$);
  
  if( symbol.type.isMalformedType() ) {
    throw syntax_error( @$ , "Invalid type for declaration" );
  }
  //std::cerr << "! " << symbol.id << " : " << symbol.type << std::endl;
  translator.updateSymbolTable($2.first);
  //translator.printSymbolTable();
  
  translator.typeContext.top().pointers -= $1;
}
;

%type < size_t > optional_pointer;
optional_pointer :
%empty {
  $$ = 0;
}
|
optional_pointer "*" {
  translator.typeContext.top().pointers++;
  $$ = $1 + 1;
}
;

%type < std::pair<size_t,size_t> > direct_declarator;
direct_declarator :
/* Variable declaration */
IDENTIFIER {
  try {
    // create a new symbol in current scope
    DataType &  curType = translator.typeContext.top() ;
    SymbolTable & table = translator.currentTable();
    $$ = std::make_pair(translator.currentEnvironment(),
			table.lookup( $1 , curType ));
  } catch ( ... ) {
    /* Already declared in current scope */
    throw syntax_error( @$ , $1 + " has already been declared in this scope." );
  }
}
|
/* Function declaration */
IDENTIFIER "(" {
  /* Create a new environment (to store the parameters and return type) */
  size_t oldEnv = translator.currentEnvironment();
  size_t newEnv = translator.newEnvironment($1);
  SymbolTable & currTable = translator.currentTable();
  currTable.parent = oldEnv;
  DataType &  curType = translator.typeContext.top();
  try {
    currTable.lookup("ret#" , curType );// push return type
  } catch ( ... ) {
    throw syntax_error( @$ , "Internal error." );
  }
} optional_parameter_list ")" {

  size_t currEnv = translator.currentEnvironment();
  SymbolTable & currTable = translator.currentTable();
  currTable.params = $4;
  translator.popEnvironment();
  
  try {
    SymbolTable & outerTable = translator.currentTable();
    DataType symbolType = MM_FUNC_TYPE ;
    $$ = std::make_pair(translator.currentEnvironment()
			,outerTable.lookup( $1 , symbolType ));
    Symbol & newSymbol = translator.getSymbol($$);
    newSymbol.child = currEnv;
  } catch ( ... ) {
    /* Already declared in current scope */
    throw syntax_error( @$ , $1 + " has already been declared in this scope." );
  }
}
|
/* Matrix declaration. Empty dimensions not allowed during declaration. */
direct_declarator "[" expression "]" {
  // only 2-dimensions to be supported
  $$ = $1;

  Symbol & curSymbol = translator.getSymbol($$);
  // dimensions cannot be specified while declaring pointers to matrices
  if( curSymbol.type == MM_MATRIX_TYPE ) {
    
    // store expression value in m[0]
    /* TODO : Evaluate the given expression */
    curSymbol.type.rows = 3; // expression value : must be initialised
    
  } else if( curSymbol.type.rows != 0 and curSymbol.type.cols == 0 ) {
    
    // store expression value in m[4]
    /* TODO : Evaluate the given expression */
    curSymbol.type.cols = 4;
    
  } else {
    throw syntax_error( @$ , "Incompatible type for matrix declaration" );
  }
}
;

%type <int> optional_parameter_list;
optional_parameter_list :
%empty {
  $$ = 0;
}
|
parameter_list {
  $$ = $1;
}
;

%type <int> parameter_list;
parameter_list :
parameter_declaration {
  $$ = 1;
}
|
parameter_list "," parameter_declaration {
  $$ = $1 + 1;
}
;

parameter_declaration :
type_specifier declarator {
  
  translator.typeContext.pop();
}
;

initializer :
expression {
  
}
|
"{" initializer_row_list "}" {
  
}
;

initializer_row_list :
initializer_row {

}
|
initializer_row_list ";" initializer_row {

}
;

initializer_row :
/* Nested brace initializers are not supported : { {2;3} ; 4 } 
   Hence the non-terminal initializer_row does not again produce initializer */
expression {

}
|
initializer_row "," expression {

}
;

/* 
   Also, non-trivial designated initializers not supported.
   i.e int arr[10] = {0,[4]=2}; // ... not supported
   Hence all designator non-terminals are omitted.
*/

/**********************************************************************/




/**********************************************************************/
/***********************STATEMENT NON-TERMINALS************************/
/**********************************************************************/

statement :
compound_statement {
  
}
|
expression_statement {

}
|
selection_statement {

}
|
iteration_statement {

}
|
jump_statement {

}
;

compound_statement :
"{" {
  /* LBrace encountered : push a new symbol table and link it to its parent */
  size_t oldEnv = translator.currentEnvironment();
  DataType voidPointer = MM_VOID_TYPE;
  voidPointer.pointers++;
  size_t newEnv = translator.newEnvironment("");
  std::pair<size_t,size_t> ref = translator.genTemp( oldEnv, voidPointer );
  Symbol & temp = translator.getSymbol(ref);
  translator.currentTable().name = temp.id;
  // TODO : initialize it to this instruction count
  temp.child = newEnv;
  SymbolTable & currTable = translator.currentTable();
  currTable.parent = oldEnv;
  //std::cerr << "NewEnv :: " << temp.id << " : " << temp.child  << std::endl;
  
} optional_block_item_list "}" {
  //std::cerr << "EnvPoP :: " << translator.currentEnvironment() << std::endl;
  
  translator.popEnvironment();
}
;

optional_block_item_list :
%empty
|
optional_block_item_list block_item {

}
;

block_item :
declaration {

}
|
statement {

}
;

expression_statement :
optional_expression ";" {
  
}
;

/* 1 shift-reduce conflict arising out of this rule. Only this one is to be expected. */
selection_statement :
"if" "(" expression ")" statement {

}
|
"if" "(" expression ")" statement "else" statement {

}
;

iteration_statement :
"while" "(" expression ")" statement {

}
|
"do" statement "while" "(" expression ")" ";" {

}
|
"for""("optional_expression";"optional_expression";"optional_expression")"statement {

}
/* Declaration inside for is not supported */
;

jump_statement :
"return" optional_expression ";" {
  
}
;

optional_expression :
%empty
|
expression {

}
;
/**********************************************************************/



/**********************************************************************/
/**********************DEFINITION NON-TERMINALS************************/
/**********************************************************************/

%start translation_unit;

translation_unit :
external_declarations "EOF" {
  // translation completed
  YYACCEPT;
}
;

external_declarations :
%empty
|
external_declarations external_declaration{

};

external_declaration :
declaration {

}
|
function_definition {

}
;

function_definition :
type_specifier function_declarator "{" {
  // Push the same environment back onto the stack
  // to continue declaration within the same scope

  Symbol & symbol = translator.getSymbol($2);
  size_t functionScope = symbol.child;
  // $2->value = address of this function
  translator.environment.push(functionScope);
  translator.emit(Taco(OP_FUNC_START,translator.currentTable().name));

} optional_block_item_list "}" {
  translator.emit(Taco(OP_FUNC_END,translator.currentTable().name));

  translator.environment.pop();
  translator.typeContext.pop(); // corresponding to the type_specifier
}
;

%type < std::pair<size_t,size_t> > function_declarator;
function_declarator :
optional_pointer direct_declarator {
  /* Check if declarator has a function definition inside or not */
  $$ = $2;
  Symbol & symbol = translator.getSymbol($$);
  if( symbol.type != MM_FUNC_TYPE ) {
    throw syntax_error( @$ , " Improper function definition : parameter list not found." );
  }
}

%%

/* Bison parser error . 
   Sends a message to the translator and aborts any further parsing. */
void yy::mm_parser::error (const location_type& loc,const std::string &msg) {
  translator.error(loc,msg);
  throw syntax_error(loc,msg);
}
