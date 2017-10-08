#include "types.h"

DataType::DataType(const DataType & type) :
  pointers(type.pointers) , rows(type.rows) , cols(type.cols) { }

DataType::~DataType() { }

bool DataType::isPointer() {
  return pointers > 0 ;
}

unsigned int DataType::getSize() {
  if( isPointer() )
    return SIZE_OF_PTR;
  if( rows == 0 ) {
    if( cols == 0 ) return SIZE_OF_PTR;
    if( cols == 1 ) return 0;
    if( cols == 2 ) return SIZE_OF_CHAR;
    if( cols == 3 ) return SIZE_OF_INT;
    if( cols == 4 ) return SIZE_OF_DOUBLE;
    return 0;
  }
  return 2 * SIZE_OF_INT + rows * cols * SIZE_OF_DOUBLE ;
}

bool DataType::operator==(const DataType & type) {
  return pointers == type.pointers and rows == type.rows and cols == type.cols ;
}

bool DataType::operator!=(const DataType & type) {
  return pointers != type.pointers or rows != type.rows or cols != type.cols ;
}

bool DataType::isStaticMatrix() {
  return pointers==0 and rows != 0 and cols != 0 ;
}

bool DataType::isMatrix() {
  return isStaticMatrix() or (rows==0 and cols==0 and pointers==0);
}

bool DataType::isIllegalDecalaration() {
  if( cols == 0 and rows != 0 ) return true;
  if( rows == 0 and cols == 0 and pointers == 0 ) return false; // dynamic matrices
  if( rows == 0 and (cols > 4 or cols < 2) ) return true;
  return false;
}

std::ostream & operator << (std::ostream & out , const DataType & type) {
  if( type.rows == 0 ){
    switch ( type.cols ) {
    case 0: out << "Mtrx";   break;
    case 1: out << "void";   break;
    case 2: out << "char";   break;
    case 3: out << "int";    break;
    case 4: out << "dbl";    break;
    case 5: out << "fnct";   break;
    default: out << " ! Unknown type "; break;
    }
  } else {
    out << "M(" << type.rows << "," << type.cols << ")";
  }
  for( int level = 0; level < type.pointers ; level++ )
    out << '*';
  return out;
}
