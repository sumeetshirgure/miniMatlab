A compiler for miniMatlab.
miniMatlab is a C-like language for performing matrix operations.
minMatlab scripts are written in *.mm files. The syntax is borrowed
from C and has additional features.

Environment :
Targeted only for x86_64 systems.

Usage / requirements :
Compilation of compiler requires `GNU make' :
$ cd path/to/miniMatlab
$ make

This should create a `compile' binary and `mmstd.o' object file.
`mmc' is a helper script. It requires said files.
$ ./mmc -h  	#for usage information

For example : to compile the sample ...
$ ./mmc ./sample.mm -o ./sample.out
$ ./sample.out

Other options include viewing the assembly code generated :
$ ./mmc -S ./sample.mm -o ./sample.asm
