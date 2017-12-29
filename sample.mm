/* miniMatlab standard library */

/* rows and cols return dimensions of a matrix */
int rows(Matrix m);

int cols(Matrix m);

/* printer functions return the number of characeters printed */
int printStr(char *string);

int printInt(int value);

int printDouble(double value);

int printMat(Matrix m);

/* reader functions exit with zero status code iff reading
   was successful */
int readInt(int *addr);

int readDouble(double *addr);

/*******************************/

int main() {
  
  int r, c, i, j;
  readInt(&r); readInt(&c);
  
  Matrix m[r][c];
  
  for(i=0;i<r;i++)
    for(j=0;j<c;j++) {
      readDouble(&(m[i][j]));
    }
  
  printMat(m*m.'); // '
  
  return 0;
}
