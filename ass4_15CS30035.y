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

/* Expect only 1 shift/reduce conflict on "else" token. */
%expect 1;

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
  
  /* Helper functions to get dereferenced symbols for scalars
   * Only used when Expression is known to be non-matrix type. */
  SymbolRef
    getScalarBinaryOperand(mm_translator & ,
			   yy::mm_parser & ,
			   const yy::location & ,
			   Expression & );
  SymbolRef
    getIntegerBinaryOperand(mm_translator & ,
			    yy::mm_parser & ,
			    const yy::location & ,
			    Expression & );

  /* Checks if the given symbol has type equal to given type on not.
     If not, then converts / throws accordingly. */
  SymbolRef typeCheck(SymbolRef, // symbol
		      DataType &,// type
		      bool, // convert?
		      mm_translator &,
		      yy::mm_parser &,
		      const yy::location & );

  /* Emits opcodes for performing a scalar binary operation */
  void emitScalarBinaryOperation(char ,
				 mm_translator &,
				 yy::mm_parser &,
				 Expression & ,
				 Expression & ,
				 Expression & ,
				 const yy::location &,
				 const yy::location &,
				 const yy::location & );

  /* For bitwise / modulo operations */
  void emitIntegerBinaryOperation(char ,
				  mm_translator &,
				  yy::mm_parser &,
				  Expression &,
				  Expression &,
				  Expression &,
				  const yy::location &,
				  const yy::location &,
				  const yy::location & );
  
  /* For comparison operations */
  void emitConditionOperation(char ,
			      mm_translator &,
			      yy::mm_parser &,
			      Expression &,
			      Expression &,
			      Expression &,
			      const yy::location &,
			      const yy::location &,
			      const yy::location & );
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
  $$.auxSymbol = $$.symbol;
  $$.isReference = true;
}
|
INTEGER_CONSTANT {
  DataType intType = MM_INT_TYPE;
  SymbolRef ref = translator.genTemp(intType);
  Symbol & temp = translator.getSymbol(ref);
  temp.value.intVal = $1;
  temp.isInitialized = true;
  $$.symbol = ref;
  translator.emit(Taco(OP_COPY,temp.id,std::to_string($1)));
}
|
FLOATING_CONSTANT {
  DataType doubleType = MM_DOUBLE_TYPE;
  SymbolRef ref = translator.genTemp(doubleType);
  Symbol & temp = translator.getSymbol(ref);
  temp.value.doubleVal = $1;
  temp.isInitialized = true;
  $$.symbol = ref;
  translator.emit(Taco(OP_COPY,temp.id,std::to_string($1)));
}
|
CHARACTER_CONSTANT {
  DataType charType = MM_CHAR_TYPE;
  SymbolRef ref = translator.genTemp(charType);
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
  SymbolRef ref = translator.genTemp(charPointerType);
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
/* Store element offset. Turn on reference flag.
    Empty expressions not allowed, exactly two indices are required. */
postfix_expression "[" expression "]" "[" expression "]" {
  
  if( translator.isMatrixReference($1) ) {
    throw syntax_error(@1,"Syntax error.");
  }
  
  Symbol & lSym = translator.getSymbol($1.symbol);
  std::swap($$,$1);
  if( lSym.type.isStaticMatrix() ) {// simple matricks
    DataType addressType = MM_INT_TYPE;
    SymbolRef tempRef = translator.genTemp(addressType);
    Symbol & temp = translator.getSymbol(tempRef);
    Symbol & LHS = translator.getSymbol($$.symbol);
    Symbol & rowIndex = translator.getSymbol($3.symbol);
    Symbol & colIndex = translator.getSymbol($6.symbol);
    if( rowIndex.type != MM_INT_TYPE or colIndex.type != MM_INT_TYPE ) {
      throw syntax_error(@$ , "Non-integral index for matrix " + LHS.id + "." );
    }
    translator.emit(Taco(OP_MULT,temp.id,rowIndex.id,std::to_string(LHS.type.cols)));
    translator.emit(Taco(OP_PLUS,temp.id,temp.id,colIndex.id));
    translator.emit(Taco(OP_MULT,temp.id,temp.id,std::to_string(SIZE_OF_DOUBLE)));
    translator.emit(Taco(OP_PLUS,temp.id,temp.id,std::to_string(2*SIZE_OF_INT)));
    $$.auxSymbol = tempRef;
    $$.isReference = true;
  } else if( lSym.type.isMatrix() ) {
    DataType addressType = MM_INT_TYPE;
    SymbolRef tempRef = translator.genTemp(addressType);
    SymbolRef temp2Ref = translator.genTemp(addressType);
    Symbol & temp = translator.getSymbol(tempRef);
    Symbol & temp2 = translator.getSymbol(temp2Ref);
    Symbol & LHS = translator.getSymbol($$.symbol);
    Symbol & rowIndex = translator.getSymbol($3.symbol);
    Symbol & colIndex = translator.getSymbol($6.symbol);
    if( rowIndex.type != MM_INT_TYPE or colIndex.type != MM_INT_TYPE ) {
      throw syntax_error(@$ , "Non-integral index for matrix " + LHS.id + "." );
    }
    translator.emit(Taco(OP_RXC,temp2.id,LHS.id, std::to_string(SIZE_OF_INT) ));//t2 = m[4] (# of columns)
    translator.emit(Taco(OP_MULT,temp.id,rowIndex.id,temp2.id));
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
  throw syntax_error(@$,"TODO.");
}
|
postfix_expression inc_dec_op { // inc_dec_op generates ++ or --
  std::swap($$,$1);
  DataType baseType = translator.getSymbol($$.symbol).type;
  if( $$.isReference ) {
    if( translator.isSimpleReference($$) ) {
      if(baseType == MM_CHAR_TYPE or baseType == MM_INT_TYPE or baseType == MM_DOUBLE_TYPE) {// basic types
	SymbolRef retRef = translator.genTemp(baseType);
	Symbol & ret = translator.getSymbol(retRef);
	Symbol & LHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_COPY,ret.id,LHS.id));// value before incrementation / decrementation
	if( $2 == '+' ) translator.emit(Taco(OP_PLUS,LHS.id,LHS.id,"1"));
	else translator.emit(Taco(OP_MINUS,LHS.id,LHS.id,"1"));
	$$.symbol = retRef;
      } else if( baseType.isPointer() ) {
	DataType elementType = baseType; elementType.pointers--;
	SymbolRef retRef = translator.genTemp(baseType);
	Symbol & ret = translator.getSymbol(retRef);
	Symbol & LHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_COPY,ret.id,LHS.id));// value before incrementation / decrementation
	if( $2 == '+' ) translator.emit(Taco(OP_PLUS,LHS.id,LHS.id,std::to_string(elementType.getSize())));
	else translator.emit(Taco(OP_MINUS,LHS.id,LHS.id,std::to_string(elementType.getSize())));
	$$.symbol = retRef;
      } else {// matrix or other types
	throw syntax_error(@1,"Invalid operand.");
      }
    } else if( translator.isMatrixReference($$) ) {// matrix element
      DataType returnType = MM_DOUBLE_TYPE;
      SymbolRef retRef = translator.genTemp(returnType);
      SymbolRef newRef = translator.genTemp(returnType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
      Symbol & LHS = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_RXC,retSymbol.id,LHS.id,auxSymbol.id));// ret = m[off]
      Symbol & newSymbol = translator.getSymbol(newRef);
      if( $2 == '+' ) translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,"1"));// temp = ret+1
      else translator.emit(Taco(OP_MINUS,newSymbol.id,retSymbol.id,"1"));// temp = ret-1
      translator.emit(Taco(OP_LXC,LHS.id,auxSymbol.id,newSymbol.id));//copy back : m[off] = temp
      $$.symbol = retRef;
      $$.isReference = false;
    } else if( translator.isPointerReference($$) ) {
      SymbolRef newRef = translator.genTemp(baseType);
      Symbol & newSymbol = translator.getSymbol(newRef);// stores new value
      Symbol & retSymbol = translator.getSymbol($$.symbol);// return value
      Symbol & pointerId = translator.getSymbol($$.auxSymbol);// pointer id
      if( baseType.isPointer() ) {
	DataType elementType = baseType; elementType.pointers--;
	if( $2 == '+' )
	  translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,std::to_string(elementType.getSize())));// new = ret+sz
	else
	  translator.emit(Taco(OP_MINUS,newSymbol.id,retSymbol.id,std::to_string(elementType.getSize())));// new = ret-sz
      } else if( baseType == MM_CHAR_TYPE or baseType == MM_INT_TYPE or baseType == MM_DOUBLE_TYPE ) {// basic types
	if( $2 == '+' ) translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,"1"));// new = ret+1
	else translator.emit(Taco(OP_MINUS,newSymbol.id,retSymbol.id,"1"));// new = ret-1
      } else {
	throw syntax_error(@1 , "Invalid operand.");
      }
      translator.emit(Taco(OP_L_DEREF,pointerId.id,newSymbol.id));//copy back : *ptr = new
    } else {
      throw syntax_error(@1,"Invalid operand.");
    }
    $$.isReference = false;
  } else {
    throw syntax_error(@1,"Invalid operand.");
  }
}
|
postfix_expression ".'" {
  /* TODO : Support matrix transposition */
  throw syntax_error(@$, "Matrix transpose not supported yet.");
}
;

%type <char> inc_dec_op;
inc_dec_op : "++" { $$ = '+'; } | "--" { $$ = '-'; } ;

%type < std::vector<Expression> > optional_argument_list argument_list;
optional_argument_list : %empty { } | argument_list { std::swap($$,$1); } ;
argument_list : expression { $$.push_back($1); } | argument_list "," expression { swap($$,$1); $$.push_back($3); } ;

%type <Expression> unary_expression;
unary_expression : postfix_expression { std::swap($$,$1); } // copy
|
inc_dec_op unary_expression { // prefix increment operator
  std::swap($$,$2);
  DataType baseType = translator.getSymbol($$.symbol).type;
  if( $$.isReference ) {
    if( translator.isSimpleReference($$) ) {
      if(baseType == MM_CHAR_TYPE or baseType == MM_INT_TYPE or baseType == MM_DOUBLE_TYPE) {// basic types
	SymbolRef retRef = translator.genTemp(baseType);
	Symbol & ret = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	if( $1 == '+' ) translator.emit(Taco(OP_PLUS,ret.id,RHS.id,"1"));
	else translator.emit(Taco(OP_MINUS,ret.id,RHS.id,"1"));
	translator.emit(Taco(OP_COPY,RHS.id,ret.id));// value after incrementation / decrementation
	$$.symbol = retRef;
      } else if( baseType.isPointer() ) {
	DataType elementType = baseType; elementType.pointers--;
	SymbolRef retRef = translator.genTemp(baseType);
	Symbol & ret = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	if( $1 == '+' ) translator.emit(Taco(OP_PLUS,ret.id,RHS.id,std::to_string(elementType.getSize())));
	else translator.emit(Taco(OP_MINUS,ret.id,RHS.id,std::to_string(elementType.getSize())));
	translator.emit(Taco(OP_COPY,RHS.id,ret.id));// value before incrementation / decrementation
	$$.symbol = retRef;
      } else {// matrix or other types
	throw syntax_error(@2,"Invalid operand.");
      }
    } else if( translator.isMatrixReference($$) ) {// matrix element
      DataType returnType = MM_DOUBLE_TYPE;
      SymbolRef retRef = translator.genTemp(returnType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
      Symbol & RHS = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_RXC,retSymbol.id,RHS.id,auxSymbol.id));// ret = m[off]
      if( $1 == '+' ) translator.emit(Taco(OP_PLUS,retSymbol.id,retSymbol.id,"1"));// ret = ret+1
      else translator.emit(Taco(OP_MINUS,retSymbol.id,retSymbol.id,"1"));// ret = ret-1
      translator.emit(Taco(OP_LXC,RHS.id,auxSymbol.id,retSymbol.id));//copy back : m[off] = temp
      $$.symbol = retRef;
      $$.isReference = false;
    } else if( translator.isPointerReference($$) ) {
      Symbol & retSymbol = translator.getSymbol($$.symbol);// return value
      Symbol & pointerId = translator.getSymbol($$.auxSymbol);// pointer id
      if( baseType.isPointer() ) {
	DataType elementType = baseType; elementType.pointers--;
	if( $1 == '+' )
	  translator.emit(Taco(OP_PLUS,retSymbol.id,retSymbol.id,std::to_string(elementType.getSize())));// ret = ret+sz
	else
	  translator.emit(Taco(OP_MINUS,retSymbol.id,retSymbol.id,std::to_string(elementType.getSize())));// ret = ret-sz
      } else if( baseType == MM_CHAR_TYPE or baseType == MM_INT_TYPE or baseType == MM_DOUBLE_TYPE ) {// basic types
	if( $1 == '+' ) translator.emit(Taco(OP_PLUS,retSymbol.id,retSymbol.id,"1"));// ret = ret+1
	else translator.emit(Taco(OP_MINUS,retSymbol.id,retSymbol.id,"1"));// ret = ret-1
      } else {
	throw syntax_error(@2 , "Invalid operand.");
      }
      translator.emit(Taco(OP_L_DEREF,pointerId.id,retSymbol.id));//copy back : *ptr = new
    } else {
      throw syntax_error(@1,"Invalid operand.");
    }
    $$.isReference = false;
  } else {
    throw syntax_error(@1,"Invalid operand.");
  }
  
}
|
unary_operator unary_expression {
  std::swap($$,$2);// copy all
  DataType rType = translator.getSymbol($$.symbol).type;
  switch($1) {
  case '&' : {
    if( $$.isReference ) {
      if( translator.isSimpleReference($$) ) { // just take reference
	if( rType.isMatrix() ) {
	  throw syntax_error(@2,"Invalid matrix operand.");
	}
	DataType pointerType = rType; pointerType.pointers++;
	SymbolRef retRef = translator.genTemp(pointerType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_REFER,retSymbol.id,RHS.id));
	$$.symbol = retRef;
      } else if( translator.isMatrixReference($$) ) {
	DataType pointerType = MM_DOUBLE_TYPE; pointerType.pointers++;
	SymbolRef retRef = translator.genTemp(pointerType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
	translator.emit(Taco(OP_PLUS,retSymbol.id,RHS.id,auxSymbol.id));// base + offset
	$$.symbol = retRef;
      } else if( translator.isPointerReference($$) ) {
	$$.symbol = $$.auxSymbol; // take back pointer
      } else {
	throw syntax_error(@2,"Invalid operand.");
      }
    } else {
      throw syntax_error(@$,"Attempting to take reference of non-l-value.");
    }
    $$.isReference = false;
  } break;
    
  case '*' : {
    if( rType.isPointer() ) {
      DataType elementType = rType; elementType.pointers--;
      SymbolRef retRef = translator.genTemp(elementType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      Symbol & RHS = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_R_DEREF,retSymbol.id,RHS.id));
      $$.auxSymbol = $$.symbol;
      $$.symbol = retRef;
      $$.isReference = true;
    } else {
      throw syntax_error(@$,"Attempting to dereference non-pointer type.");
    }
  } break;
    
  case '+' : {
    if( $$.isReference ) {
      if( translator.isSimpleReference($$) ) {
	SymbolRef retRef = translator.genTemp(rType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	// Dynoge
	translator.emit(Taco(OP_COPY,retSymbol.id,RHS.id));//copies entire matrices
	$$.symbol = retRef;
      } else if( translator.isMatrixReference($$) ) {
	DataType elementType = MM_DOUBLE_TYPE;
	SymbolRef retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
	Symbol & RHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_RXC,retSymbol.id,RHS.id,auxSymbol.id));// ret = m[off]
	$$.symbol = retRef;
      } else if( translator.isPointerReference($$) ) {//for pointer reference, just lower flag
      } else {
	throw syntax_error(@2,"Invalid operand.");
      }
      $$.isReference = false;
    }
  } break;
    
  case '-' : {
    if( $$.isReference ) {
      if( translator.isSimpleReference($$) ) {
	SymbolRef retRef = translator.genTemp(rType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	// Dynoge
	translator.emit(Taco(OP_UMINUS,retSymbol.id,RHS.id));//copy-negates entire matrices
	$$.symbol = retRef;
      } else if( translator.isMatrixReference($$) ) {
	DataType elementType = MM_DOUBLE_TYPE;
	SymbolRef retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
	Symbol & RHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_RXC,retSymbol.id,RHS.id,auxSymbol.id));// ret = m[off]
	$$.symbol = retRef;
      } else if( translator.isPointerReference($$) ) {//for pointer reference, just lower flag
      } else {
	throw syntax_error(@2,"Invalid operand.");
      }
      Symbol & retSymbol = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_UMINUS,retSymbol.id,retSymbol.id));
      $$.isReference = false;
    } else if( rType.isPointer() ) {
      throw syntax_error(@$ , "Unary minus on pointer not allowed." );
    } else {
      SymbolRef retRef = translator.genTemp(rType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      Symbol & RHS = translator.getSymbol($$.symbol);
      // Dynoge
      translator.emit(Taco(OP_UMINUS,retSymbol.id,RHS.id));//
      $$.symbol = retRef;
    }
  } break;
  default: throw syntax_error(@$ , "Unknown unary operator.");
  }
  
} ;

%type <char> unary_operator;
unary_operator : "&" { $$ = '&'; } |"*" { $$ = '*'; } |"+" { $$ = '+'; } |"-" { $$ = '-'; } ;

/// Type casting not supported yet...
%type <Expression> cast_expression;
cast_expression : unary_expression { std::swap($$,$1); }

%type <Expression> multiplicative_expression;
multiplicative_expression :
cast_expression {
  std::swap($$,$1);
} | multiplicative_expression mul_div_op cast_expression { // mul_div_op produces `*' or `/'
  // TODO : possible matrix/scalar , matrix/matrix multiplication.. and same for rhs
  // Dynoge
  emitScalarBinaryOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);
} | multiplicative_expression "%" cast_expression {
  emitIntegerBinaryOperation('%',translator,*this,$$,$1,$3,@$,@1,@3);
} ;

%type <char> mul_div_op;
mul_div_op : "*" { $$ = '*'; } | "/" { $$ = '/'; }

%type <Expression> additive_expression;
additive_expression :
multiplicative_expression {
  std::swap($$,$1);
} | additive_expression add_sub_op multiplicative_expression { // add_sub op produces `+' or `-'
  // TODO : possible matrix addition / subtraction
  // Dynoge
  emitScalarBinaryOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);
} ;

%type <char> add_sub_op;
add_sub_op : "+" { $$ = '+'; } | "-" { $$ = '-'; } ;

%type <Expression> shift_expression;
shift_expression : additive_expression { std::swap($$,$1); }
| shift_expression bit_shift_op additive_expression {emitIntegerBinaryOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);} ;

%type <char> bit_shift_op;
bit_shift_op : "<<" { $$ = '<'; } | ">>" { $$ = '>'; } ;

%type <Expression> relational_expression equality_expression;
relational_expression : shift_expression { std::swap($$,$1); }
| relational_expression rel_op shift_expression {emitConditionOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);} ;
equality_expression : relational_expression { std::swap($$,$1); }
| equality_expression eq_op relational_expression {emitConditionOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);} ;

%type <char> rel_op eq_op;
rel_op : "<" { $$ = '<'; } | ">" { $$ = '>'; } | "<=" { $$ ='('; } | ">=" { $$ = ')'; } ;
eq_op : "==" { $$ = '='; } | "!=" { $$ = '!'; } ;

%type <Expression> AND_expression XOR_expression OR_expression;
AND_expression : equality_expression { std::swap($$,$1); }
| AND_expression "&" equality_expression {emitIntegerBinaryOperation('&',translator,*this,$$,$1,$3,@$,@1,@3);} ;
XOR_expression : AND_expression { std::swap($$,$1); }
| XOR_expression "^" AND_expression {emitIntegerBinaryOperation('^',translator,*this,$$,$1,$3,@$,@1,@3);} ;
OR_expression : XOR_expression { std::swap($$,$1);}
| OR_expression "|" XOR_expression {emitIntegerBinaryOperation('|',translator,*this,$$,$1,$3,@$,@1,@3);} ;

%type <unsigned int> instruction_mark;
instruction_mark : %empty { $$ = translator.nextInstruction(); } ;

%type <Expression> logical_AND_expression;
logical_AND_expression :
OR_expression {
  std::swap($$,$1);
} | logical_AND_expression "&&" instruction_mark OR_expression {
  Symbol & lSym = translator.getSymbol($1.symbol);
  if( lSym.type != MM_BOOL_TYPE ) throw syntax_error(@1,"Non boolean operand.");
  Symbol & rSym = translator.getSymbol($4.symbol);
  if( rSym.type != MM_BOOL_TYPE ) throw syntax_error(@4,"Non boolean operand.");
  translator.patchBack($1.trueList,$3);
  std::swap($$.trueList,$4.trueList);// constant time
  $$.falseList.splice($$.falseList.end(),$1.falseList);
  $$.falseList.splice($$.falseList.end(),$4.falseList);
  DataType retType = MM_BOOL_TYPE;
  SymbolRef retRef = translator.genTemp(retType);
  $$.symbol = retRef;
} ;

%type <Expression> logical_OR_expression;
logical_OR_expression :
logical_AND_expression {
  std::swap($$,$1);
} | logical_OR_expression "||" instruction_mark logical_AND_expression {
  Symbol & lSym = translator.getSymbol($1.symbol);
  if( lSym.type != MM_BOOL_TYPE ) throw syntax_error(@1,"Non boolean operand.");
  Symbol & rSym = translator.getSymbol($4.symbol);
  if( rSym.type != MM_BOOL_TYPE ) throw syntax_error(@4,"Non boolean operand.");
  translator.patchBack($1.falseList,$3);
  std::swap($$.falseList,$4.falseList);// constant time
  $$.trueList.splice($$.trueList.end(),$1.trueList);
  $$.trueList.splice($$.trueList.end(),$4.trueList);
  DataType retType = MM_BOOL_TYPE;
  SymbolRef retRef = translator.genTemp(retType);
  $$.symbol = retRef;
} ;

%type <unsigned int> insert_jump;
insert_jump : %empty {
  translator.emit(Taco(OP_GOTO));
  $$ = translator.nextInstruction();
} ;

/* Cannot nest question statements */
%type <Expression> conditional_expression;
conditional_expression :
logical_OR_expression {
  std::swap($$,$1);
} | logical_OR_expression instruction_mark "?" expression insert_jump ":" expression {
  Symbol & lSym = translator.getSymbol($1.symbol);
  if( lSym.type != MM_BOOL_TYPE ) throw syntax_error(@1,"Non boolean question.");
  translator.patchBack($1.trueList,$2); // on the mark
  translator.patchBack($1.falseList,$5); // after the jump
  translator.patchBack($5-1,translator.nextInstruction());
  DataType retType = MM_VOID_TYPE;
  SymbolRef retRef = translator.genTemp(retType);
  $$.symbol = retRef;
} ;

%type <Expression> assignment_expression;
assignment_expression :
conditional_expression { std::swap($$,$1); } |
unary_expression "=" assignment_expression {
  std::swap($$,$1);
  if( $$.isReference ) {
    if( translator.isSimpleReference($$) ) {
      DataType lType = translator.getSymbol($$.symbol).type;
      if( lType.isMatrix() ) {// RHS must be matrix
	/* TODO : support matrix assignment */
	// Dynoge
	throw syntax_error(@1,"Matrix operations not supported yet.");
      } else if( lType == MM_CHAR_TYPE or lType == MM_INT_TYPE or lType == MM_DOUBLE_TYPE ) {
	SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
	Symbol & RHS = translator.getSymbol(RHR);
	if( RHS.type != lType ) { // convert
	  RHR = typeCheck(RHR,lType,true,translator,*this,@3);
	}
	Symbol & CRHS = translator.getSymbol(RHR);
	Symbol & CLHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_COPY,CLHS.id,CRHS.id));// LHS = RHS
      } else if( lType.isPointer() ) {
	Symbol & RHS = translator.getSymbol($3.symbol);
	if( RHS.type == lType ) {
	  Symbol & auxSym = translator.getSymbol($$.auxSymbol);
	  translator.emit(Taco(OP_L_DEREF,auxSym.id,RHS.id));
	} else {
	  throw syntax_error(@$,"Operand mismatch.");
	}
      } else {
	throw syntax_error(@1,"Invalid operand.");
      }
    } else if( translator.isMatrixReference($$) ) {
      SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
      Symbol & RHS = translator.getSymbol(RHR);
      if( RHS.type != MM_DOUBLE_TYPE ) {
	DataType doubleType = MM_DOUBLE_TYPE;
	RHR = typeCheck(RHR,doubleType,true,translator,*this,@3);
      }
      Symbol & CRHS = translator.getSymbol(RHR);
      Symbol & CLHS = translator.getSymbol($$.symbol);
      Symbol & auxSym = translator.getSymbol($$.auxSymbol);
      translator.emit(Taco(OP_LXC,CLHS.id,auxSym.id,CRHS.id));// m[off] = RHS
    } else if( translator.isPointerReference($$) ) {
      DataType lType = translator.getSymbol($$.symbol).type;
      if( lType.isPointer() ) {
	Symbol & RHS = translator.getSymbol($3.symbol);
	if( RHS.type == lType ) {
	  Symbol & auxSym = translator.getSymbol($$.auxSymbol);
	  translator.emit(Taco(OP_L_DEREF,auxSym.id,RHS.id));
	} else {
	  throw syntax_error(@$,"Operand mismatch.");
	}
      } else if( lType == MM_CHAR_TYPE or lType == MM_INT_TYPE or lType == MM_DOUBLE_TYPE ) {
	SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
	Symbol & RHS = translator.getSymbol(RHR);
	if( RHS.type != lType ) {// convert to lType
	  RHR = typeCheck(RHR,lType,true,translator,*this,@3);
	}
	Symbol & CRHS = translator.getSymbol(RHR);
	Symbol & auxSym = translator.getSymbol($$.auxSymbol);
	translator.emit(Taco(OP_L_DEREF,auxSym.id,CRHS.id));// *ptr = RHS
      } else {
	throw syntax_error(@1,"Invalid operand.");
      }
    }
  } else {
    throw syntax_error(@1,"Assignment to non-l-value.");
  }
  
} ;

%type <Expression> expression;
expression :
assignment_expression { std::swap($$,$1); } ;

/**********************************************************************/




/**********************************************************************/
/*********************DECLARATION NON-TERMINALS************************/
/**********************************************************************/

/* Empty declarator list not supported i.e : `int ;' is not syntactically correct */
/* Also since only one type specifier is supported , `declaration_specifiers' is omitted */
declaration : type_specifier initialized_declarator_list ";" {translator.typeContext.pop();} ;

%type <DataType> type_specifier;
type_specifier :
  "void" { translator.typeContext.push( MM_VOID_TYPE ); }
| "char" { translator.typeContext.push( MM_CHAR_TYPE ); }
|  "int" { translator.typeContext.push( MM_INT_TYPE );  }
|"double" {translator.typeContext.push( MM_DOUBLE_TYPE);}
|"Matrix" {translator.typeContext.push( MM_MATRIX_TYPE);} ;

initialized_declarator_list :
initialized_declarator | initialized_declarator_list "," initialized_declarator ;

initialized_declarator :
declarator { } | declarator "=" initializer {
  /*TODO : maintain initial values over expression symbols */
  // check types and optionally initalize expression */
} ;

%type < SymbolRef > declarator;
declarator :
optional_pointer direct_declarator {
  $$ = $2;
  Symbol & symbol = translator.getSymbol($$);
  /* TODO : If it is a function declaration in a global scope let it pass. */
  if( translator.currentEnvironment() == 0 and symbol.type == MM_FUNC_TYPE ) {
    throw syntax_error( @$ , "Function declaration not supported yet." );
  } else if( symbol.type.isIllegalDecalaration() ) {
    throw syntax_error( @$ , "Invalid type for declaration." );
  }
  translator.updateSymbolTable($2.first);
  translator.typeContext.top().pointers -= $1;
} ;

%type <unsigned int> optional_pointer;
optional_pointer : %empty { $$ = 0; } |
optional_pointer "*" {
  if( translator.typeContext.top() == MM_MATRIX_TYPE ) {
    throw syntax_error(@$, "Matrices cannot have pointers.");
  }
  translator.typeContext.top().pointers++;
  $$ = $1 + 1;
} ;

%type < SymbolRef > direct_declarator;
direct_declarator :
/* Variable declaration */
IDENTIFIER {
  try {
    // create a new symbol in current scope
    DataType &  curType = translator.typeContext.top() ;
    SymbolTable & table = translator.currentTable();
    if(translator.parameterDeclaration) {
      $$ = std::make_pair(translator.currentEnvironment(),table.lookup($1,curType,SymbolType::PARAM));
    } else {
      $$ = std::make_pair(translator.currentEnvironment(),table.lookup($1,curType,SymbolType::LOCAL));
    }
  } catch ( ... ) {
    /* Already declared in current scope */
    throw syntax_error( @$ , $1 + " has already been declared in this scope." );
  }
  
}
|
/* Function declaration */
IDENTIFIER "(" {
  /* Create a new environment (to store the parameters and return type) */
  if(translator.parameterDeclaration) {
    throw syntax_error( @$ , "Syntax error." ); 
  }
  translator.parameterDeclaration = true;
  
  unsigned int oldEnv = translator.currentEnvironment();
  unsigned int newEnv = translator.newEnvironment($1);
  SymbolTable & currTable = translator.currentTable();
  currTable.parent = oldEnv;
  DataType &  curType = translator.typeContext.top();
  try {
    currTable.lookup("ret#" , curType , SymbolType::RETVAL );// push return type
  } catch ( ... ) {
    throw syntax_error( @$ , "Unexpected error. Debug compiler." );
  }
} optional_parameter_list ")" {
  unsigned int currEnv = translator.currentEnvironment();
  SymbolTable & currTable = translator.currentTable();
  currTable.params = $4;
  
  translator.parameterDeclaration = false;
  translator.popEnvironment();
  try {
    SymbolTable & outerTable = translator.currentTable();
    DataType symbolType = MM_FUNC_TYPE ;
    $$ = std::make_pair(translator.currentEnvironment() ,outerTable.lookup($1,symbolType,SymbolType::LOCAL));
    Symbol & newSymbol = translator.getSymbol($$);
    newSymbol.child = currEnv;
  } catch ( ... ) {/* Already declared in current scope */
    throw syntax_error( @$ , $1 + " has already been declared in this scope." );
  }
  
}
|
/* Matrix declaration. Empty dimensions not allowed during declaration. Exactly two dimensions are needed. */
IDENTIFIER "[" expression "]" "[" expression "]" {  // only 2-dimensions to be supported
  
  // TODO : based on the static values of expressions $3 and $6 , find out if matrix is static or dynamic
  
  DataType &  curType = translator.typeContext.top() ;
  if(curType != MM_MATRIX_TYPE) {
    throw syntax_error(@$,"Incompatible type for matrix declaration.");
  }
  
  if(translator.parameterDeclaration) {
    throw syntax_error(@$,"Dimensions cannot be specified while declaring parameters.");
  }
  
  try {
    // create a new symbol in current scope
    SymbolTable & table = translator.currentTable();
    $$ = std::make_pair(translator.currentEnvironment(),table.lookup($1,curType,SymbolType::LOCAL));//
    Symbol & curSymbol = translator.getSymbol($$);
    curSymbol.type.rows = 4; // store expression value in m[0]
    curSymbol.type.cols = 3; // store expression value in m[4]
    /* TODO : Support dynamically linked matrices as well. */
    
  } catch ( ... ) {/* Already declared in current scope */
    throw syntax_error( @$ , $1 + " has already been declared in this scope." );
  }

} ;

%type <unsigned int> optional_parameter_list;
optional_parameter_list :
%empty { $$ = 0; } | parameter_list { $$ = $1; } ;

%type <unsigned int> parameter_list;
parameter_list : parameter_declaration { $$ = 1; }
| parameter_list "," parameter_declaration { $$ = $1 + 1; } ;

parameter_declaration :
type_specifier declarator { translator.typeContext.pop(); } ;

%type <Expression> initializer;
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
/* TODO : If expression is not initialized , throw error */
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

%type <AddressList> statement;
statement :
  compound_statement { std::swap($$,$1); }
| selection_statement { std::swap($$,$1); }
| iteration_statement { std::swap($$,$1); }
| jump_statement      { std::swap($$,$1); }
| expression_statement { } ;

%type <AddressList> compound_statement;
compound_statement :
"{" {
  /* LBrace encountered : push a new symbol table and link it to its parent */
  unsigned int oldEnv = translator.currentEnvironment();
  DataType voidType = MM_VOID_TYPE; // 
  unsigned int newEnv = translator.newEnvironment("");
  SymbolRef ref = translator.genTemp( oldEnv, voidType );
  Symbol & temp = translator.getSymbol(ref);
  translator.currentTable().name = temp.id; // What TODO with this?
  temp.child = newEnv;
  SymbolTable & currTable = translator.currentTable();
  currTable.parent = oldEnv;
} optional_block_item_list "}" {
  std::swap($$,$3);
  translator.popEnvironment();
} ;

%type <AddressList> optional_block_item_list;
optional_block_item_list :
%empty { } |
block_item_list { std::swap($$,$1); } ;

%type <AddressList> block_item_list;
block_item_list : block_item {
  translator.patchBack($1,translator.nextInstruction());
} |
block_item_list instruction_mark block_item {
  translator.patchBack($1,$2);
  std::swap($$,$3);
}

%type <AddressList> block_item;
block_item : declaration { } | statement { std::swap($$,$1); } ;

expression_statement :
optional_expression ";" { // patch back all jumps to the next instruction
  translator.patchBack($1.trueList,translator.nextInstruction());
  translator.patchBack($1.falseList,translator.nextInstruction());
} ;

/* 1 shift-reduce conflict arising out of this rule. Only this one is to be expected. */
%type <AddressList> selection_statement;
selection_statement :
"if" "(" expression ")" instruction_mark statement {
  Symbol & boolExp = translator.getSymbol($3.symbol);
  if( boolExp.type != MM_BOOL_TYPE ) {
    throw syntax_error(@3,"Not a boolean expression.");
  }
  translator.patchBack($3.trueList,$5);
  std::swap($$,$3.falseList);
  $$.splice($$.end(),$6);
}
|
"if" "(" expression ")" instruction_mark statement "else" insert_jump statement {
  Symbol & boolExp = translator.getSymbol($3.symbol);
  if( boolExp.type != MM_BOOL_TYPE ) {
    throw syntax_error(@3,"Not a boolean expression.");
  }
  translator.patchBack($3.trueList,$5);
  translator.patchBack($3.falseList,$8);
  std::swap($$,$6);$$.push_back($8-1);
  $$.splice($$.end(),$9);
}
;

%type <AddressList> iteration_statement;
iteration_statement :
"while" "(" instruction_mark expression ")" instruction_mark statement {
  Symbol & boolExp = translator.getSymbol($4.symbol);
  if( boolExp.type != MM_BOOL_TYPE ) {
    throw syntax_error(@4,"Not a boolean expression.");
  }
  unsigned int loopInstruction = translator.nextInstruction();
  translator.emit(Taco(OP_GOTO));
  translator.patchBack(loopInstruction,$3); // primary loop
  translator.patchBack($7,$3); // shortcut loop
  translator.patchBack($4.trueList,$6); // iterate
  std::swap($$,$4.falseList); // terminate
}
|
"do" instruction_mark statement "while" "(" instruction_mark expression ")" ";" {
  Symbol & boolExp = translator.getSymbol($7.symbol);
  if( boolExp.type != MM_BOOL_TYPE ) {
    throw syntax_error(@7,"Not a boolean expression.");
  }
  translator.patchBack($7.trueList,$2); // primary loop
  translator.patchBack($3,$6);
  std::swap($$,$7.falseList); // terminate
}
|
"for" "("
optional_expression ";"              // initializer expression
instruction_mark expression ";"      // nonempty invariant expression
instruction_mark optional_expression // variant expression
")" instruction_mark statement {
  Symbol & boolExp = translator.getSymbol($6.symbol);
  if( boolExp.type != MM_BOOL_TYPE ) {
    throw syntax_error(@6,"Not a boolean expression.");
  }
  unsigned int loopInstruction = translator.nextInstruction();
  translator.emit(Taco(OP_GOTO));
  
  translator.patchBack(loopInstruction,$5); // primary loop
  translator.patchBack($12,$5); // shortcut loop
  
  translator.patchBack($3.trueList,$5); //
  translator.patchBack($3.falseList,$5); // link totally
  
  translator.patchBack($6.trueList,$8); // iterate

  translator.patchBack($9.trueList,$11); //
  translator.patchBack($9.falseList,$11); // link totally
  
  std::swap($$,$6.falseList); // terminate
}
/* Declaration inside for is not supported */
;

%type <AddressList> jump_statement;
jump_statement :
"return" optional_expression ";" {
  
}
;

%type <Expression> optional_expression;
optional_expression : %empty { } | expression { std::swap($$,$1); } ;

/**********************************************************************/



/**********************************************************************/
/**********************DEFINITION NON-TERMINALS************************/
/**********************************************************************/

%start translation_unit;

translation_unit :
external_declarations "EOF" {
  // TODO : post-translation processing / optimizations
  // translation completed
  YYACCEPT;
}
;

external_declarations :
%empty | external_declarations external_declaration { };

external_declaration :
declaration { } | function_definition { } ;

function_definition :
type_specifier function_declarator "{" {
  // Push the same environment back onto the stack
  // to continue declaration within the same scope
  Symbol & symbol = translator.getSymbol($2);
  unsigned int functionScope = symbol.child;
  // $2->value = address of this function
  translator.environment.push(functionScope);
  translator.emit(Taco(OP_FUNC_START,translator.currentTable().name));
} optional_block_item_list "}" {
  translator.patchBack($5,translator.nextInstruction());
  translator.emit(Taco(OP_FUNC_END,translator.currentTable().name));
  // TODO : "sort out" the current environment for generation of stack frame
  translator.environment.pop();
  translator.typeContext.pop(); // corresponding to the type_specifier
} ;

%type < SymbolRef > function_declarator;
function_declarator :
optional_pointer direct_declarator {
  $$ = $2;
  Symbol & symbol = translator.getSymbol($$);
  if( symbol.type != MM_FUNC_TYPE ) {
    throw syntax_error( @$ , " Improper function definition : parameter list not found." );
  }
}
;
/**********************************************************************/

%%

/* Bison parser error . 
   Sends a message to the translator and aborts any further parsing. */
void yy::mm_parser::error (const location_type& loc,const std::string &msg) {
  translator.error(loc,msg);
  throw syntax_error(loc,msg);
}

SymbolRef getScalarBinaryOperand(mm_translator & translator,
				 yy::mm_parser& parser,
				 const yy::location& loc,
				 Expression & expr
				 ) {
  SymbolRef ret ;
  DataType rType = translator.getSymbol(expr.symbol).type;
  if( expr.isReference ) {
    if( translator.isSimpleReference(expr) ) {
      if( rType.isMatrix() ) {
	parser.error(loc, "Unknown error. Debug compiler.");
      }
      ret = expr.symbol;
    } else if( translator.isPointerReference(expr) ) {
      if( rType == MM_CHAR_TYPE or rType == MM_INT_TYPE or rType == MM_DOUBLE_TYPE ) {
	ret = expr.symbol;
      } else { // non scalar operand
        parser.error(loc , "Operand not allowed.");
      }
    } else if( translator.isMatrixReference(expr) ) { // matrix element
      DataType elementType = MM_DOUBLE_TYPE;
      ret = translator.genTemp(elementType);
      Symbol & retSymbol = translator.getSymbol(ret);
      Symbol & rhs = translator.getSymbol(expr.symbol);
      Symbol & auxSymbol = translator.getSymbol(expr.auxSymbol);
      translator.emit(Taco(OP_RXC,retSymbol.id,rhs.id,auxSymbol.id));// rhs = m[off]
    } else {
      parser.error(loc , "Invalid operand.");
    }
  } else if( rType == MM_CHAR_TYPE or rType == MM_INT_TYPE or rType == MM_DOUBLE_TYPE ) {
    ret = expr.symbol;
  } else { // non scalar operand
    parser.error(loc , "Invalid operand.");
  }
  return ret;
}

SymbolRef getIntegerBinaryOperand(mm_translator & translator,
				  yy::mm_parser& parser,
				  const yy::location& loc,
				  Expression & expr
				  ) {
  SymbolRef ret ;
  DataType rType = translator.getSymbol(expr.symbol).type;
  if( expr.isReference ) {
    if( translator.isSimpleReference(expr) ) {
      if( rType.isMatrix() or rType == MM_DOUBLE_TYPE ) {
        parser.error(loc, "Non integral operand not allowed.");
      }
      ret = expr.symbol;
    } else if( translator.isPointerReference(expr) ) {
      if( rType == MM_CHAR_TYPE or rType == MM_INT_TYPE ) {
	ret = expr.symbol;
      } else { // non scalar operand
        parser.error(loc , "Operand not allowed.");
      }
    } else if( translator.isMatrixReference(expr) ) { // matrix element
      parser.error(loc , "Non integral operand not allowed.");
    } else {
      parser.error(loc , "Invalid operand.");
    }
  } else if( rType == MM_CHAR_TYPE or rType == MM_INT_TYPE ) {
    ret = expr.symbol;
  } else { // non scalar operand
    parser.error(loc , "Invalid operand.");
  }
  return ret;
}

SymbolRef typeCheck(SymbolRef ref,
		    DataType & type,
		    bool convert,
		    mm_translator & translator,
		    yy::mm_parser & parser,
		    const yy::location & loc
		    ) {
  Symbol & symbol = translator.getSymbol( ref );
  if( symbol.type != type ) {
    if( convert ) {
      SymbolRef ret = translator.genTemp(type);
      Symbol & retSymbol = translator.getSymbol(ret);
      Symbol & rhs = translator.getSymbol( ref );
      if( type == MM_CHAR_TYPE ) translator.emit(Taco(OP_CONV_TO_CHAR,retSymbol.id,rhs.id));
      if( type == MM_INT_TYPE ) translator.emit(Taco(OP_CONV_TO_INT,retSymbol.id,rhs.id));
      if( type == MM_DOUBLE_TYPE ) translator.emit(Taco(OP_CONV_TO_DOUBLE,retSymbol.id,rhs.id));
      return ret;
    } else {
      parser.error(loc , "Cannot convert into requested type.");
    }
  }
  return ref;
}

void emitScalarBinaryOperation(char opChar ,
			       mm_translator &translator,
			       yy::mm_parser &parser,
			       Expression & retExp,
			       Expression & lExp,
			       Expression & rExp,
			       const yy::location &loc,
			       const yy::location &lLoc,
			       const yy::location &rLoc
			       ) {
  SymbolRef LHR , RHR;
  LHR = getScalarBinaryOperand(translator,parser,lLoc,lExp); // get lhs
  RHR = getScalarBinaryOperand(translator,parser,rLoc,rExp); // get rhs
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType == MM_VOID_TYPE ) {
    parser.error(loc , "Invalid operands." );
  }
  LHR = typeCheck(LHR,retType,true,translator,parser,lLoc);
  RHR = typeCheck(RHR,retType,true,translator,parser,rLoc);
  SymbolRef retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  Symbol & CLHS = translator.getSymbol(LHR);
  Symbol & CRHS = translator.getSymbol(RHR);
  if( opChar == '*' ) translator.emit(Taco(OP_MULT,retSymbol.id,CLHS.id,CRHS.id));
  else if( opChar == '/' ) translator.emit(Taco(OP_DIV,retSymbol.id,CLHS.id,CRHS.id));
  else if( opChar == '+' ) translator.emit(Taco(OP_PLUS,retSymbol.id,CLHS.id,CRHS.id));
  else if( opChar == '-' ) translator.emit(Taco(OP_MINUS,retSymbol.id,CLHS.id,CRHS.id));
  retExp.symbol = retRef;
}

void emitIntegerBinaryOperation(char opChar,
				mm_translator &translator,
				yy::mm_parser &parser,
				Expression &retExp,
				Expression &lExp,
				Expression &rExp,
				const yy::location &loc,
				const yy::location &lLoc,
				const yy::location &rLoc
				) {
  SymbolRef LHR , RHR;
  LHR = getIntegerBinaryOperand(translator,parser,lLoc,lExp);
  RHR = getIntegerBinaryOperand(translator,parser,rLoc,rExp);
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType != MM_CHAR_TYPE and retType != MM_INT_TYPE ) {
    parser.error(loc , "Invalid operands." );
  }
  LHR = typeCheck(LHR,retType,true,translator,parser,lLoc);
  RHR = typeCheck(RHR,retType,true,translator,parser,rLoc);
  SymbolRef retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  Symbol & CLHS = translator.getSymbol(LHR);
  Symbol & CRHS = translator.getSymbol(RHR);
  if( opChar == '%' ) translator.emit(Taco(OP_MOD,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '<' ) translator.emit(Taco(OP_SHL,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '>' ) translator.emit(Taco(OP_SHR,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '&' ) translator.emit(Taco(OP_BIT_AND,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '^' ) translator.emit(Taco(OP_BIT_XOR,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '|' ) translator.emit(Taco(OP_BIT_OR,retSymbol.id,CLHS.id,CRHS.id));
  retExp.symbol = retRef;
}

void emitConditionOperation(char opChar,
			    mm_translator &translator,
			    yy::mm_parser &parser,
			    Expression &retExp,
			    Expression &lExp,
			    Expression &rExp,
			    const yy::location &loc,
			    const yy::location &lLoc,
			    const yy::location &rLoc
			    ) {
  SymbolRef LHR , RHR;
  LHR = getScalarBinaryOperand(translator,parser,lLoc,lExp); // get lhs
  RHR = getScalarBinaryOperand(translator,parser,rLoc,rExp); // get rhs
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType commonType = mm_translator::maxType(LHS.type,RHS.type);
  if( commonType != MM_CHAR_TYPE and commonType != MM_INT_TYPE and commonType != MM_DOUBLE_TYPE ) {
    parser.error(loc , "Invalid operands." );
  }
  LHR = typeCheck(LHR,commonType,true,translator,parser,lLoc);
  RHR = typeCheck(RHR,commonType,true,translator,parser,rLoc);
  DataType retType = MM_BOOL_TYPE;
  SymbolRef retRef = translator.genTemp(retType);
  Symbol & retSymbol = translator.getSymbol(retRef);
  Symbol & CLHS = translator.getSymbol(LHR);
  Symbol & CRHS = translator.getSymbol(RHR);
  retExp.symbol = retRef;
  retExp.trueList.push_back(translator.nextInstruction());
  switch( opChar ){
  case '<': translator.emit(Taco(OP_LT,"",CLHS.id,CRHS.id)); break;
  case '>': translator.emit(Taco(OP_GT,"",CLHS.id,CRHS.id)); break;
  case '(': translator.emit(Taco(OP_LTE,"",CLHS.id,CRHS.id)); break;
  case ')': translator.emit(Taco(OP_GTE,"",CLHS.id,CRHS.id)); break;
  case '=': translator.emit(Taco(OP_EQ,"",CLHS.id,CRHS.id)); break;
  case '!': translator.emit(Taco(OP_NEQ,"",CLHS.id,CRHS.id)); break;
  default : parser.error(loc,"Unknown relational operator.");
  }
  retExp.falseList.push_back(translator.nextInstruction());
  translator.emit(Taco(OP_GOTO,""));
}
