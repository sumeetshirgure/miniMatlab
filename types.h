#ifndef MM_TYPES_H
#define MM_TYPES_H

/* Supposed to be machine dependant constants */
const size_t SIZE_OF_PTR = 4;
const size_t SIZE_OF_CHAR = 1;
const size_t SIZE_OF_BOOL = 1;
const size_t SIZE_OF_INT = 4;
const size_t SIZE_OF_DOUBLE = 8;

/**
   Class for defining data types and their reference level.
   (pointers , typecode) used to refer to basic datatypes:
     (0,0) : void
     (0,1) : Bool
     (0,2) : char
     (0,3) : int
     (0,4) : double
     (0,5) : Matrix (dimensions are stored in memory)
     (0,6) : function
*/
class DataType {
public:
  
  size_t pointers,typecode;
  
  /* Default constructor : creates a void datatype */
  DataType(size_t _pointers = 0,size_t _typecode = 0) :
    pointers(_pointers),typecode(_typecode){}

  DataType(const DataType & dataType) :
    pointers(dataType.pointers),typecode(dataType.typecode){}
  
  /* Default destructor */
  virtual ~DataType() { } ;
  
  /* Returns the size of an object of this datatype */
  size_t getSize() {
    if( isPointer() ){
      return SIZE_OF_PTR;
    }
    if( typecode == 0 ) return 0;
    else if ( typecode == 1 ) return SIZE_OF_BOOL;
    else if ( typecode == 2 ) return SIZE_OF_CHAR;
    else if ( typecode == 3 ) return SIZE_OF_INT;
    else if ( typecode == 4 ) return SIZE_OF_DOUBLE;
    else if ( typecode == 5 ) return SIZE_OF_PTR;
    return 0;
  }
  
  /* Returns is this is a pointer type */
  bool isPointer() {
    return pointers > 0;
  }

  bool operator == (const DataType & type) {
    return pointers == type.pointers and typecode == type.typecode;
  }
  
};

#endif /* ! MM_TYPES_H */
