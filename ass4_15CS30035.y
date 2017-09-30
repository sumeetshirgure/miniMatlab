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
/* Dereference matrix element. Empty expression not allowed. */
postfix_expression "[" expression "]" {
  
}
|
/* Function call */
postfix_expression "(" optional_argument_list ")" {
  
}
|
postfix_expression "++" {
  Symbol & lSym = translator.getSymbol($1.symbol);
  std::swap($$,$1); // copy everything
  
  if( lSym.type.isPointer() ) {
    /* TODO : support pointer arithmetic */
    throw syntax_error( @$ , "Pointer arithmetic not supported yet.");
  } else {
    DataType & type = lSym.type;
    if( type == MM_CHAR_TYPE or type == MM_INT_TYPE or type == MM_DOUBLE_TYPE) {
      std::pair<size_t,size_t> tempRef = translator.genTemp(type);
      Symbol & temp = translator.getSymbol(tempRef);
      
      if( $$.isReference ) {// first dereference then assign
	Symbol & auxSym = translator.getSymbol($1.auxSymbol);
	translator.emit(Taco(OP_RXC,temp.id,lSym.id,auxSym.id));// tmp = base[idx];
	std::pair<size_t,size_t> tempRef2 = translator.genTemp(type);
	Symbol & temp2 = translator.getSymbol(tempRef2);
	translator.emit(Taco(OP_PLUS,temp2.id,temp.id,"1"));// t2 = t + 1;
	translator.emit(Taco(OP_LXC,lSym.id,auxSym.id,temp2.id));// base[idx] = t2;
	$$.isReference = false;
      } else {
	translator.emit(Taco(OP_COPY,temp.id,lSym.id));
	translator.emit(Taco(OP_PLUS,lSym.id,lSym.id,"1"));
      }
      
      $$.symbol = tempRef;
      // this expression now refers to the value before incrementation
    } else {
      throw syntax_error( @$ , "Invalid type for postfix increment operator.");
    }
  }
  
}
|
postfix_expression "--" {
  Symbol & lSym = translator.getSymbol($1.symbol);
  std::swap($$,$1); // copy everything
  
  if( lSym.type.isPointer() ) {
    /* TODO : support pointer arithmetic */
    throw syntax_error( @$ , "Pointer arithmetic not supported yet.");
  } else {
    DataType & type = lSym.type;
    if( type == MM_CHAR_TYPE or type == MM_INT_TYPE or type == MM_DOUBLE_TYPE) {
      std::pair<size_t,size_t> tempRef = translator.genTemp(type);
      Symbol & temp = translator.getSymbol(tempRef);
      
      if( $$.isReference ) {// first dereference then assign
	Symbol & auxSym = translator.getSymbol($1.auxSymbol);
	translator.emit(Taco(OP_RXC,temp.id,lSym.id,auxSym.id));// tmp = base[idx];
	std::pair<size_t,size_t> tempRef2 = translator.genTemp(type);
	Symbol & temp2 = translator.getSymbol(tempRef2);
	translator.emit(Taco(OP_MINUS,temp2.id,temp.id,"1"));// t2 = t - 1;
	translator.emit(Taco(OP_LXC,lSym.id,auxSym.id,temp2.id));// base[idx] = t2;
	$$.isReference = false;
      } else {
	translator.emit(Taco(OP_COPY,temp.id,lSym.id));
	translator.emit(Taco(OP_MINUS,lSym.id,lSym.id,"1"));
      }
      $$.symbol = tempRef;
      // this expression now refers to the value before decrementation
    } else {
      throw syntax_error( @$ , "Invalid type for postfix decrement operator.");
    }
  }
  
}
|
postfix_expression ".'" {
  /* TODO : Support matrix transposition */
  throw syntax_error(@$, "Matrix transpose not supported yet.");
}
;

optional_argument_list : %empty
| argument_list {
  
}
;

argument_list :
assignment_expression {
  
}
|
argument_list "," assignment_expression {

}
;

unary_expression :
postfix_expression {

}
|
"++" unary_expression {

}
|
"--" unary_expression {

}
|
unary_operator postfix_expression {

}
;

unary_operator :
"&" { /* get reference */ }
|"*" { /* dereference */ }
|"+" { /* unary plus */ }
|"-" { /* unary minus */  }

cast_expression : unary_expression { }

multiplicative_expression :
cast_expression {

}
|
multiplicative_expression "*" cast_expression {

}
|
multiplicative_expression "/" cast_expression {

}
|
multiplicative_expression "%" cast_expression {

}
;

additive_expression :
multiplicative_expression {

}
|
additive_expression "+" multiplicative_expression {

}
|
additive_expression "-" multiplicative_expression {

}
;

shift_expression :
additive_expression {

}
|
shift_expression "<<" additive_expression {

}
|
shift_expression ">>" additive_expression {

}
;

relational_expression :
shift_expression {

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
  
}
;

equality_expression :
relational_expression {

}
|
equality_expression "==" relational_expression {

}
|
equality_expression "!=" relational_expression {

}
;

AND_expression :
equality_expression {

}
|
AND_expression "&" equality_expression {

}
;

XOR_expression :
AND_expression {

}
|
XOR_expression "^" AND_expression {

}
;

OR_expression :
XOR_expression {

}
|
OR_expression "|" XOR_expression {

}
;

logical_AND_expression :
OR_expression {

}
|
logical_AND_expression "&&" OR_expression {

}
;

logical_OR_expression :
logical_AND_expression {

}
|
logical_OR_expression "||" logical_AND_expression {

}
;

conditional_expression :
logical_OR_expression {

}
|
logical_OR_expression "?" expression ":" conditional_expression {
  
}
;

assignment_expression :
conditional_expression {

}
|
unary_expression "=" assignment_expression {

}
;

%type <Expression> expression;
expression :
assignment_expression {
  
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
    throw syntax_error( @$ , "Incompatible type for matrix declaration" );
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
    
  } else if( curSymbol.type.rows != 0 ) {
    
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
