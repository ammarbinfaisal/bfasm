# bfasm

compiles brainf*** code to x86-64 machine code

## usage

```
nasm   -f elf64 asm.s  && gcc -no-pie asm.o
./a.out # reads code from test.bf
```
