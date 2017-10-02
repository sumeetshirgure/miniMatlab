#ifndef MM_TYPES_H
#define MM_TYPES_H

#include <iostream>

/* Supposed to be machine dependant constants */
const size_t SIZE_OF_PTR = 4;
const size_t SIZE_OF_CHAR = 1;
const size_t SIZE_OF_BOOL = 1;
const size_t SIZE_OF_INT = 4;
const size_t SIZE_OF_DOUBLE = 8;

/**
   Class for defining data types and their reference level.
   (rows , cols) are also used to refer to basic datatypes :
     (0,0) : Matrix_0 (implicit)
     (*,0) : Matrix_1 (implicit)
     (*,*) : Matrix
     (0,1) : void
     (0,2) : Bool (implicit)
     (0,3) : char
     (0,4) : int
     (0,5) : double
     (0,6) : function type (for symbol table)
*/
class DataType {
public:
  
  size_t pointers,rows,cols;
  
  /* Default constructor : should create a void datatype */
  DataType(size_t _pointers = 0, size_t _rows = 0, size_t _cols = 1) :
    pointers(_pointers) , rows(_rows) , cols(_cols) { }

  /* Default copy constructor */
  DataType(const DataType &) ;
  
  /* Default destructor */
  virtual ~DataType() ;
  
  /* Returns is this is a pointer type */
  bool isPointer() ;
    
  /* Returns the size of an object of this datatype */
  size_t getSize() ;
  
  /* Checks if two type are the same */
  bool operator == (const DataType &) ;
  
  /* Checks if two type are not the same */
  bool operator != (const DataType &) ;
  
  /* Checks if base type is void */
  bool isVoidType();

  /* Checks if base type is Bool */
  bool isBoolType();

  /* Checks if base type is char */
  bool isCharType();

  /* Checks if base type is int */
  bool isIntType();
  
  /* Checks if base type is double */
  bool isDoubleType();

  /* Checks if type is proper matrix */
  bool isProperMatrix();
  
  /* Checks if type definition is malformed */
  bool isMalformedType();
};

/* Print the type */
std::ostream& operator << (std::ostream&,const DataType &);

/* Basic datatype constants */
const DataType MM_MATRIX_TYPE  (0,0,0);
const DataType MM_VOID_TYPE    (0,0,1);
const DataType MM_BOOL_TYPE    (0,0,2); // implicit
const DataType MM_CHAR_TYPE    (0,0,3);
const DataType MM_INT_TYPE     (0,0,4);
const DataType MM_DOUBLE_TYPE  (0,0,5);
const DataType MM_FUNC_TYPE    (0,0,6);


#endif /* ! MM_TYPES_H */
