all: masm

masm: masm.d program.d instruction.d register.d util.d
	dmd -unittest masm.d program.d instruction.d register.d util.d

clean:
	rm masm *.o *.lst
