A simple 32-bit single threaded simulator of the base RISC-V R32VI ISA

[RISC-V ?](https://en.wikipedia.org/wiki/RISC-V)  
[ISA ?](https://en.wikipedia.org/wiki/Instruction_set_architecture)

## Usage

1. Install the [riscv-gnu-toolchain](https://github.com/riscv/riscv-gnu-toolchain)
2. run `make && ruby riscv.rb program.bin`

You can alter `program.s` to change the executed code.

Here is a [RISC-V assembly cheat-sheet](https://www.cl.cam.ac.uk/teaching/1617/ECAD+Arch/files/docs/RISCVGreenCardv8-20151013.pdf)
