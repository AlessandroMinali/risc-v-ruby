A simple single threaded simulator for RISC-V RV32 ISA

[RISC-V ?](https://en.wikipedia.org/wiki/RISC-V)  
[ISA ?](https://en.wikipedia.org/wiki/Instruction_set_architecture)

## Supports
- RV32I (default)
- RV32E (with `-E`)

## Future Support
- RV32M
- RV32A

## Maybe Support
- RV32F
- RV32D
- RV32Q
- RVZicsr
- RVC

## Usage

1. Install the [riscv-gnu-toolchain](https://github.com/riscv/riscv-gnu-toolchain)
2. run `make && ruby riscv.rb program.bin`

### Sample Program:
```ruby
main:
  addi x29, x0, 5
  addi x30, x0, 37
  add x31, x30, x29
  sw x31, 0(x0)

```

### Sample Output:
```ruby
$ make && ruby riscv.rb program.bin
REGISTERS
x00:          0 x01:          0 x02:          0 x03:          0 
x04:          0 x05:          0 x06:          0 x07:          0 
x08:          0 x09:          0 x10:          0 x11:          0 
x12:          0 x13:          0 x14:          0 x15:          0 
x16:          0 x17:          0 x18:          0 x19:          0 
x20:          0 x21:          0 x22:          0 x23:          0 
x24:          0 x25:          0 x26:          0 x27:          0 
x28:          0 x29:        0x5 x30:       0x25 x31:       0x2a 

MEMORY
         0:       0x2a
```

You can alter `program.s` to change the executed code.

Here is a [RISC-V assembly cheat-sheet](https://www.cl.cam.ac.uk/teaching/1617/ECAD+Arch/files/docs/RISCVGreenCardv8-20151013.pdf)
