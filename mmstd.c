/* C implementation of the miniMatlab standard library */
#include <stdio.h>
#include <stdlib.h>

int printStr(char *string)
{ return printf("%s",string); }

int printInt(int value)
{ return printf("%d",value); }

int printDouble(double value)
{ return printf("%lf",value); }

int readInt(int *addr)
{ return !scanf("%d",addr); }

int readDouble(double *addr)
{ return !scanf("%lf",addr); }

int rows(void *ptr)
{ return ((int*)ptr)[0]; }

int cols(void *ptr)
{ return ((int*)ptr)[1]; }

int printMat(void *ptr) {
  int ret = 0 , r = rows(ptr) , c = cols(ptr) , i , j;
  double *mat = (double*)ptr; ++mat;
  for( i = 0 ; i < r ; ++i ) {
    for( j = 0 ;  j < c ; ++j , ++mat )
      ret += printf("%10.4lf ",*mat);
    ret += printf("\n");
  }
  return ret;
}

void matMult(void *ret,void *lx,void *rx) {
  int u = rows(lx) , v = cols(lx) , w = cols(rx);
  
  if( v != rows(rx) ) abort();
  if( rows(ret) != u || cols(ret) != w ) abort();
  
  double *z = (double*)ret; z++;
  double *x = (double*)lx; x++;
  double *y = (double*)rx; y++;
    
  int i , j , k;
  for( i = 0 ; i < u ; i++ ) {
    for( j = 0 ; j < w ; j++ ) {
      double *xp = x + i * v , *yp = y + j;
      double val = 0.0;
      for( k = 0 ; k < v ; k++ ) {
	// fprintf(stderr,"%lf,%lf\n",*xp,*yp);
	val += (*xp) * (*yp);
	xp++; yp += w;
      }
      *z = val;
      z++;
    }
  }
}
