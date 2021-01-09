# int fib(int n) {
#   if (n < 2)
#     return n;
#   else
#     return (fib(n-1) + fib(n-2));
# }
#
# int main() {
#   return fib(10);
# }
main:
  addi sp, sp, -4
  sw ra, 0(sp)

  addi a0, x0, 10
  jal fib         # fib(10)

  lw ra, 0(sp)
  addi sp, sp, 4
  ret
fib:
  addi sp, sp, -12
  sw ra, 8(sp)
  sw s0, 4(sp)
  sw s1, 0(sp)

  mv s0, a0       # local n
  mv s1, x0       # local var for sum
base:
  addi t0, x0, 2
  blt s0, t0, end # if (n < 2) { return n }
else:
  addi a0, s0, -1 # n - 1
  jal fib         # fib(n - 1)
  add s1, s1, a0  # result of fib(n - 1)
  addi a0, s0, -2 # n - 2
  jal fib         # fib(n - 2)
  add a0, s1, a0  # return fib(n-1) + fib(n - 2)
end:
  lw ra, 8(sp)
  lw s0, 4(sp)
  lw s1, 0(sp)
  addi sp, sp, 12
  ret
