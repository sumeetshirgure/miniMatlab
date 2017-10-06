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
  
  /* Helper functions to get dereferenced symbols */
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
/* Dereference matrix element. Empty expression not allowed.
   exactly two addresses are required */
postfix_expression "[" expression "]" "[" expression "]" {
  Symbol & lSym = translator.getSymbol($1.symbol);
  std::swap($$,$1);
  
  if( !$$.isReference and lSym.type.isProperMatrix() ) {// simple matricks
    DataType addressType = MM_INT_TYPE;
    SymbolRef tempRef = translator.genTemp(addressType);
    Symbol & temp = translator.getSymbol(tempRef);
    
    Symbol & rowIndex = translator.getSymbol($3.symbol);
    Symbol & colIndex = translator.getSymbol($6.symbol);
    if( rowIndex.type != MM_INT_TYPE or colIndex.type != MM_INT_TYPE ) {
      throw syntax_error(@$ , "Non-integral index for matrix " + lSym.id + "." );
    }

    /* Edit this to take dimension from memory instead of symbol table.? */
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
	/* TODO : check if paramList[idx] is a reference. If so, create a copy. */
	// In case of pointers, do internal reassignment.
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
    SymbolRef retRef = translator.genTemp(symTable.table[0].type);
    Symbol & retVal = translator.getSymbol(retRef);
    translator.emit(Taco(OP_CALL,retVal.id,lSym.id,std::to_string(paramList.size())));
    $$.symbol = retRef;
    $$.isReference = false;
  }

}
|
postfix_expression inc_dec_op { // inc_dec_op generates ++ or --
  std::swap($$,$1); // copy everything
  Symbol & lSym = translator.getSymbol($$.symbol);
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
      SymbolRef retRef = translator.genTemp(elementType);
      SymbolRef newRef = translator.genTemp(elementType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      Symbol & LHS = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_R_DEREF,retSymbol.id,LHS.id));// ret = *v
      Symbol & newSymbol = translator.getSymbol(newRef);
      if( $2 == '+' )
	translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,"1"));// temp = ret+1
      else
	translator.emit(Taco(OP_MINUS,newSymbol.id,retSymbol.id,"1"));// temp = ret-1
      translator.emit(Taco(OP_L_DEREF,LHS.id,newSymbol.id));//copy back : *v = temp
      $$.symbol = retRef;// returns ret
    } else if( lSym.type.isProperMatrix() ) { // reference to matrix element
      DataType elementType = MM_DOUBLE_TYPE;
      SymbolRef retRef = translator.genTemp(elementType);
      SymbolRef newRef = translator.genTemp(elementType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
      Symbol & LHS = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_RXC,retSymbol.id,LHS.id,auxSymbol.id));// ret = m[off]
      Symbol & newSymbol = translator.getSymbol(newRef);
      if( $2 == '+' )
	translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,"1"));// temp = ret+1
      else
	translator.emit(Taco(OP_MINUS,newSymbol.id,retSymbol.id,"1"));// temp = ret-1
      translator.emit(Taco(OP_LXC,LHS.id,auxSymbol.id,newSymbol.id));//copy back : m[off] = temp
      $$.symbol = retRef;
      $$.isReference = false;
    } else {
      throw syntax_error(@$, "Invalid operand." );
    }
  } else if( type == MM_CHAR_TYPE or type == MM_INT_TYPE or type == MM_DOUBLE_TYPE ) {
    if( translator.isTemporary($$.symbol) ) {
      throw syntax_error(@$, "Invalid operand." );
    }
    SymbolRef tempRef = translator.genTemp(type);
    Symbol & temp = translator.getSymbol(tempRef);
    Symbol & LHS = translator.getSymbol($$.symbol);
    translator.emit(Taco(OP_COPY,temp.id,LHS.id));
    if( $2 == '+' ) translator.emit(Taco(OP_PLUS,LHS.id,LHS.id,"1"));
    else translator.emit(Taco(OP_MINUS,LHS.id,LHS.id,"1"));
    $$.symbol = tempRef;
  } else if( lSym.type.isPointer() ) {
    /* TODO : support pointer arithmetic */
    throw syntax_error( @$ , "Pointer arithmetic not supported yet.");
  } else {
    throw syntax_error(@$, "Invalid operand." );
  } // this expression now refers to the value before incrementation

}
|
postfix_expression ".'" {
  /* TODO : Support matrix transposition */
  throw syntax_error(@$, "Matrix transpose not supported yet.");
}
;

%type <char> inc_dec_op;
inc_dec_op : "++" { $$ = '+'; } | "--" { $$ = '-'; } ;

%type < std::vector<Expression> > optional_argument_list;
optional_argument_list : %empty { } | argument_list { std::swap($$,$1); } ;

%type < std::vector<Expression> > argument_list;
argument_list :
expression { $$.push_back($1); } | argument_list "," expression { swap($$,$1); $$.push_back($3); } ;

%type <Expression> unary_expression;
unary_expression :
postfix_expression {
  std::swap($$,$1); // copy everything
}
|
inc_dec_op unary_expression { // ++ / -- unary expression
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
	SymbolRef retRef = translator.genTemp(rSym.type);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_COPY,retSymbol.id,rSym.id));
	$$.symbol = retRef;
      } else if( rSym.type.isProperMatrix() ) { // reference to matrix element
	DataType pointerType = MM_DOUBLE_TYPE;
	pointerType.pointers++;
	SymbolRef retRef = translator.genTemp(pointerType);
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
      SymbolRef retRef = translator.genTemp(pointerType);
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
	SymbolRef retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_R_DEREF,retSymbol.id,rSym.id));
	$$.symbol = retRef;
	// $$.isReference = true; // Not a reference
      } else {
	$$.isReference = true;//  turn reference flag on for possible dereferencing
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
	SymbolRef retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_R_DEREF,retSymbol.id,rSym.id));// ret = *x
	$$.symbol = retRef;
      } else if( rSym.type.isProperMatrix() ){
	DataType elementType = MM_DOUBLE_TYPE;
	SymbolRef retRef = translator.genTemp(elementType);
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
    } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE or rSym.type == MM_DOUBLE_TYPE ) {
      SymbolRef retRef = translator.genTemp(rSym.type);
      Symbol & retSymbol = translator.getSymbol(retRef);
      translator.emit(Taco(OP_COPY,retSymbol.id,rSym.id));
      $$.symbol = retRef;
    } else if( rSym.type.isProperMatrix() ) {
      throw syntax_error(@$ , "Unary plus on matrices not supported yet.");
    } else {
      throw syntax_error(@$ , "Invalid type for unary plus.");
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
	SymbolRef retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	translator.emit(Taco(OP_R_DEREF,retSymbol.id,rSym.id));// ret = *x
	$$.symbol = retRef;
      } else if( rSym.type.isProperMatrix() ){
	DataType elementType = MM_DOUBLE_TYPE;
	SymbolRef retRef = translator.genTemp(elementType);
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
    } else if( rSym.type == MM_CHAR_TYPE or rSym.type == MM_INT_TYPE or rSym.type == MM_DOUBLE_TYPE ) {
      SymbolRef retRef = translator.genTemp(rSym.type);
      Symbol & retSymbol = translator.getSymbol(retRef);
      translator.emit(Taco(OP_UMINUS,retSymbol.id,rSym.id));
      $$.symbol = retRef;
    } else if( rSym.type.isProperMatrix() ) { // can negate matrix
      throw syntax_error(@$ , "Unary minus on matrices not supported yet." );
    } else {
      throw syntax_error(@$ , "Invalid type for unary minus.");
    }
  } break;
  default: throw syntax_error(@$ , "Unknown unary operator.");
  }

}
;

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
  // TODO : if getSymbol($1.symbol) is proper matrix ...
  //   possible matrix/scalar , matrix/matrix multiplication.. and same for rhs
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
  // TODO : if getSymbol($1.symbol) is proper matrix ...
  //   possible matrix addition / subtraction
  emitScalarBinaryOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);
} ;

%type <char> add_sub_op;
add_sub_op : "+" { $$ = '+'; } | "-" { $$ = '-'; } ;

%type <Expression> shift_expression;
shift_expression :
additive_expression {
  std::swap($$,$1);
}
|
shift_expression bit_shift_op additive_expression { // bit_shift_op produces `<<' or `>>'
  emitIntegerBinaryOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);
}
;

%type <char> bit_shift_op;
bit_shift_op : "<<" { $$ = '<'; } | ">>" { $$ = '>'; } ;

%type <Expression> relational_expression;
relational_expression :
shift_expression {
  std::swap($$,$1);
} | relational_expression rel_op shift_expression {// rel_op produces one of `<' `<=' `>' `>='
  emitConditionOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);
} ;

%type <char> rel_op;
rel_op : "<" { $$ = '<'; } | ">" { $$ = '>'; } | "<=" { $$ ='('; } | ">=" { $$ = ')'; };

%type <Expression> equality_expression;
equality_expression :
relational_expression {
  std::swap($$,$1);
} | equality_expression eq_op relational_expression { // eq_op produces `==' or `!='
  emitConditionOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);
} ;

%type <char> eq_op;
eq_op : "==" { $$ = '='; } | "!=" { $$ = '!'; } ;

%type <Expression> AND_expression;
AND_expression :
equality_expression {
  std::swap($$,$1);
} | AND_expression "&" equality_expression {
  emitIntegerBinaryOperation('&',translator,*this,$$,$1,$3,@$,@1,@3);
} ;

%type <Expression> XOR_expression;
XOR_expression :
AND_expression {
  std::swap($$,$1);
} | XOR_expression "^" AND_expression {
  emitIntegerBinaryOperation('^',translator,*this,$$,$1,$3,@$,@1,@3);
} ;

%type <Expression> OR_expression;
OR_expression :
XOR_expression {
  std::swap($$,$1);
} | OR_expression "|" XOR_expression {
  emitIntegerBinaryOperation('|',translator,*this,$$,$1,$3,@$,@1,@3); 
} ;

%type <unsigned int> instruction_mark;
instruction_mark : %empty { $$ = translator.nextInstruction(); } ;

%type <Expression> logical_AND_expression;
logical_AND_expression :
OR_expression {
  std::swap($$,$1);
} | logical_AND_expression "&&" instruction_mark OR_expression {
  Symbol & lSym = translator.getSymbol($1.symbol);
  if( lSym.type != MM_BOOL_TYPE ) throw syntax_error(@$,"Invalid operand.");
  Symbol & rSym = translator.getSymbol($4.symbol);
  if( rSym.type != MM_BOOL_TYPE ) throw syntax_error(@$,"Invalid operand.");
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
  if( lSym.type != MM_BOOL_TYPE ) throw syntax_error(@$,"Invalid operand.");
  Symbol & rSym = translator.getSymbol($4.symbol);
  if( rSym.type != MM_BOOL_TYPE ) throw syntax_error(@$,"Invalid operand.");
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

%type <Expression> conditional_expression;
conditional_expression :
logical_OR_expression {
  std::swap($$,$1);
} | logical_OR_expression instruction_mark "?" expression insert_jump ":" expression {
  Symbol & lSym = translator.getSymbol($1.symbol);
  if( lSym.type != MM_BOOL_TYPE ) throw syntax_error(@$,"Invalid operand.");
  translator.patchBack($1.trueList,$2); // on the mark
  translator.patchBack($1.falseList,$5); // after the jump
  translator.patchBack($5-1,translator.nextInstruction());
  DataType retType = MM_VOID_TYPE;
  SymbolRef retRef = translator.genTemp(retType);
  $$.symbol = retRef;
} ;

%type <Expression> assignment_expression;
assignment_expression :
conditional_expression {
  std::swap($$,$1);
} | unary_expression "=" assignment_expression {
  /* TODO : support matrix assignment */
  Symbol & lSym = translator.getSymbol($1.symbol);
  Symbol & rSym = translator.getSymbol($3.symbol);
  
  if( $1.isReference ) {
    if( lSym.type.isPointer() ) { // pointer reference
      DataType elementType = lSym.type; elementType.pointers--;
      if( elementType.isProperMatrix() ) {
	throw syntax_error( @1, "Matrix assignment not supported yet.");
      }else if( elementType.isPointer() ) { // impossible
	throw syntax_error( @3 , "Invalid operand." );
      }else if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE
		or elementType == MM_DOUBLE_TYPE ) {
	SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
	Symbol & LHS = translator.getSymbol($1.symbol);
	RHR = typeCheck(RHR,elementType,true,translator,*this,@3);
	Symbol & CRHS = translator.getSymbol(RHR);
	Symbol & CLHS = translator.getSymbol($1.symbol);
	translator.emit(Taco(OP_L_DEREF,CLHS.id,CRHS.id)); // *z = temp
      } else {
	throw syntax_error( @1 , "Invalid operand." );
      }
    } else if( lSym.type.isProperMatrix() ) { // matrix element
      SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
      Symbol & RHS = translator.getSymbol(RHR);
      if( RHS.type != MM_DOUBLE_TYPE ) {
	DataType doubleType = MM_DOUBLE_TYPE;
	RHR = typeCheck(RHR,doubleType,true,translator,*this,@3);
      }
      Symbol & auxSym = translator.getSymbol($1.auxSymbol);
      Symbol & CLHS = translator.getSymbol($1.symbol);
      Symbol & CRHS = translator.getSymbol(RHR);
      translator.emit(Taco(OP_LXC,CLHS.id,auxSym.id,CRHS.id));
    } else {
      throw syntax_error(@1,"Invalid operand.");
    }
  } else if ( translator.isTemporary($1.symbol) ) { // rvalue
    throw syntax_error(@1,"Invalid operand. LHS cannot be a temporary.");
  } else { // valid lvalue
    if( lSym.type.isPointer() ) {
      if( lSym.type.rows != 0 or lSym.type.cols == 0 ) {// M(p,q)* or M*
	if( rSym.type.rows == 0 or rSym.type.cols == 0 or rSym.type.pointers!=lSym.type.pointers ) {
	  // rhs is not an equivalent pointer to matrix
	  throw syntax_error(@3,"Invalid operand.");
	}
	lSym.type.rows = rSym.type.rows; lSym.type.cols = rSym.type.cols; // set new dimensions
      } else if( lSym.type != rSym.type ) {
	throw syntax_error(@3,"Invalid operand.");
      }
      translator.emit(Taco(OP_COPY,lSym.id,rSym.id)); // copy address
    } else if( lSym.type.isProperMatrix() ) { // matrix assignment
      throw syntax_error(@1,"Matrix assignment not supported yet.");
    } else if( lSym.type == MM_CHAR_TYPE or lSym.type == MM_INT_TYPE or lSym.type == MM_DOUBLE_TYPE ) {
      SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
      Symbol & RHS = translator.getSymbol(RHR);
      Symbol & LHS = translator.getSymbol($1.symbol);
      if( LHS.type != RHS.type ) {
	RHR = typeCheck(RHR,LHS.type,true,translator,*this,@3);
      }
      Symbol & CRHS = translator.getSymbol(RHR);
      Symbol & CLHS = translator.getSymbol($1.symbol);
      translator.emit(Taco(OP_COPY,CLHS.id,CRHS.id)); // copy value
    }
  }

}
;

%type <Expression> expression;
expression :
assignment_expression { std::swap($$,$1); } ;

/**********************************************************************/




/**********************************************************************/
/*********************DECLARATION NON-TERMINALS************************/
/**********************************************************************/

/* Empty declarator list not supported */
/* i.e : `int ;' is not syntactically correct */
/* Also since only one type specifier is supported , `declaration_specifiers' is omitted */
declaration :
type_specifier initialized_declarator_list ";" {translator.typeContext.pop();}
;

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
declarator {
}
|
declarator "=" initializer {
  /*** TODO : Decide matrix pointer policy ***/
  /*TODO : maintain initial values over expression symbols */
  // check types and optionally initalize expression */
}
;

%type < SymbolRef > declarator;
declarator :
optional_pointer direct_declarator {
  $$ = $2;
  Symbol & symbol = translator.getSymbol($$);
  /* If it is a function declaration let it pass. */
  if( symbol.type.isMalformedType() ) {
    throw syntax_error( @$ , "Invalid type for declaration" );
  }
  translator.updateSymbolTable($2.first);
  translator.typeContext.top().pointers -= $1;
}
;

%type <unsigned int> optional_pointer;
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

%type < SymbolRef > direct_declarator;
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
  unsigned int oldEnv = translator.currentEnvironment();
  unsigned int newEnv = translator.newEnvironment($1);
  SymbolTable & currTable = translator.currentTable();
  currTable.parent = oldEnv;
  DataType &  curType = translator.typeContext.top();
  try {
    currTable.lookup("ret#" , curType );// push return type
  } catch ( ... ) {
    throw syntax_error( @$ , "Internal error." );
  }
} optional_parameter_list ")" {

  unsigned int currEnv = translator.currentEnvironment();
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
    curSymbol.type.rows = 4;// expression value : must be initialised
    
  } else if( curSymbol.type.rows != 0 and curSymbol.type.cols == 0 ) {
    
    // store expression value in m[4]
    /* TODO : Evaluate the given expression */
    curSymbol.type.cols = 3;
    
  } else {
    throw syntax_error( @$ , "Incompatible type for matrix declaration" );
  }
}
;

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
  DataType voidPointer = MM_VOID_TYPE;
  voidPointer.pointers++;
  unsigned int newEnv = translator.newEnvironment("");
  SymbolRef ref = translator.genTemp( oldEnv, voidPointer );
  Symbol & temp = translator.getSymbol(ref);
  translator.currentTable().name = temp.id; // What TODO with this?
  temp.child = newEnv;
  SymbolTable & currTable = translator.currentTable();
  currTable.parent = oldEnv;
} optional_block_item_list "}" {
  std::swap($$,$3);
  translator.popEnvironment();
}
;

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
  // "sort out" the current environment for generation of stack frame
  translator.environment.pop();
  translator.typeContext.pop(); // corresponding to the type_specifier
}
;

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
    if( rType.isPointer() ) {
      DataType elementType = rType; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE or elementType == MM_DOUBLE_TYPE ) {
	ret = translator.genTemp(elementType);
	Symbol & rhs = translator.getSymbol(expr.symbol);
	Symbol & retSymbol = translator.getSymbol(ret);
	translator.emit(Taco(OP_R_DEREF,retSymbol.id,rhs.id));// ret = *rhs
      } else { // non scalar operand
        parser.error(loc , "Invalid operand.");
      }
    } else if( rType.isProperMatrix() ) { // matrix element
      DataType elementType = MM_DOUBLE_TYPE;
      ret = translator.genTemp(elementType);
      Symbol & retSymbol = translator.getSymbol(ret);
      Symbol & rhs = translator.getSymbol(expr.symbol);
      Symbol & auxSymbol = translator.getSymbol(expr.auxSymbol);
      translator.emit(Taco(OP_RXC,retSymbol.id,rhs.id,auxSymbol.id));// lhs = m[off]
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
    if( rType.isPointer() ) {
      DataType elementType = rType; elementType.pointers--;
      if( elementType == MM_CHAR_TYPE or elementType == MM_INT_TYPE ) {
	ret = translator.genTemp(elementType);
	Symbol & rhs = translator.getSymbol(expr.symbol);
	Symbol & retSymbol = translator.getSymbol(ret);
	translator.emit(Taco(OP_R_DEREF,retSymbol.id,rhs.id));// ret = *rhs
      } else { // double
        parser.error(loc , "Invalid operand.");
      }
    } else { // matrix element
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
