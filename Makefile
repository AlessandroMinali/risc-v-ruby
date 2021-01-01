program.bin: program.s
	riscv64-unknown-elf-gcc -Wl,-Ttext=0x0 -nostdlib -o program program.s
	riscv64-unknown-elf-objcopy -O binary program program.bin

clean:
	rm -f program
	rm -f program.bin