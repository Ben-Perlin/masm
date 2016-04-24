# masm [![mit]][license]
[mit]: <http://img.shields.io/:license-MIT-blue.svg?style=plastic>
[license]: https://github.com/felix-hoenikker/masm/blob/master/LICENSE
Assembler for subset of 32 bit MIPS assembly.

Original version used for class

Usage
-----
To install comiler goto "http://dlang.org/download.html" and download the dmg for mac.

To compile, just run "make all"

To get help: ./masm -h
To assemble file: ./masm  -s [start_address] [filename]
To disassemble file: ./masm -d [filename]


Errata:
-------
 - reading file from terminal using standard input does not terminate
 - refuses to open redirrected file, i.e. "./masm <(cat file.asm)"
 
Todo:
----
 - use enum to store opcode and funct & convert to string
