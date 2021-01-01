# frozen_string_literal: true

class InvalidRegister < RuntimeError; end
class InvalidMemory < RuntimeError; end
class InvalidJump < RuntimeError; end
class InvalidOp < RuntimeError
  def initialize(opcode, funct3, funct7)
    msg = format('Unsupported op: %#<op>x, funct3: %#<funct3>x, funct7: %#<funct7>x', op: opcode,
                                                                                      funct3: funct3,
                                                                                      funct7: funct7)
    super(msg)
  end
end

def b2h(str)
  str.to_i(2).to_s(16)
end

def signed(num)
  [num].pack('L').unpack1('l')
end

def unsigned(num)
  num & ILEN
end

def dump_registers
  REGS.each.with_index do |i, index|
    print format('x%02<reg>d: %#10<val>x ', reg: index, val: i)
    print "\n" if ((index + 1) % 4).zero?
  end
end

def dump_memory
  MEM.each_slice(4).with_index do |i, index|
    next if i.nil?

    i += Array.new(4 - i.size) { 0 } if i.size < 4
    value = i[0] | i[1] << 8 | i[2] << 16 | i[3] << 24

    print format('%#10<mem>x: %#10<val>x ', mem: index * 4, val: value)
    print "\n" if ((index + 1) % 4).zero?
  end
end

def valid_memory?(address, size)
  raise InvalidMemory, "0x#{address} must be lass than #{MAX_MEM}" unless address < MAX_MEM

  unless (address % (size / 8)).zero? # rubocop:disable Style/GuardClause
    raise InvalidMemory,
          "0x#{address} is not #{size / 8} byte aligned for #{size} bit access"
  end
end

# load
def l(size, rs1, imm, sign: false)
  address = REGS.fetch(rs1) + imm
  valid_memory?(address, size)

  case size
  when 8
    value = MEM[address]
    sign ? signed(value << 24) >> 24 : value
  when 16
    value = MEM[address] | (MEM[address + 1] << 8)
    sign ? signed(value << 16) >> 16 : value
  when 32
    MEM[address] | (MEM[address + 1] << 8) | (MEM[address + 2] << 16) | (MEM[address + 3] << 24)
  else
    raise InvalidMemory, "Unsupported size: #{size} bits"
  end
end

# store
def s(size, rs2, rs1, imm)
  address = REGS.fetch(rs1) + imm
  valid_memory?(address, size)

  r2 = REGS.fetch(rs2)
  case size
  when 8
    MEM[address] = r2 & 0xff
  when 16
    MEM[address] = r2 & 0xff
    MEM[address + 1] = (r2 >> 8) & 0xff
  when 32
    MEM[address] = r2 & 0xff
    MEM[address + 1] = (r2 >> 8) & 0xff
    MEM[address + 2] = (r2 >> 16) & 0xff
    MEM[address + 3] = (r2 >> 24) & 0xff
  else
    raise InvalidMemory, "Unsupported size: #{size}"
  end
end

program = IO.read(ARGV[0])
program_end = program.length
pc = 0

REGS = Array.new(32) { 0 }
# interface for fixed array
def REGS.set(index, value)
  return unless fetch(index) { raise InvalidRegister, "x#{index}" }

  self[index] = (value & ILEN)
end
MEM = [] # rubocop:disable Style/MutableConstant
def MEM.[](index)
  super || 0
end
MAX_MEM = 0x8000_0000
XLEN = 32
ILEN = 2**XLEN - 1

while pc < program_end
  old_pc = pc
  instruction = program[pc...pc + 4].unpack1('l<')

  opcode = instruction & 0x7f
  rd = (instruction >> 7) & 0x1f
  rs1 = (instruction >> 15) & 0x1f
  rs2 = (instruction >> 20) & 0x1f
  funct3 = (instruction >> 12) & 0x7
  funct7 = (instruction >> 25) & 0x7f

  imm = unsigned(signed(instruction & 0xfff0_0000) >> 20)

  case opcode
  when 0x3
    case funct3
    when 0x0
      # LB
      REGS.set(rd, l(8, rs1, imm, sign: true))
    when 0x1
      # LH
      REGS.set(rd, l(16, rs1, imm, sign: true))
    when 0x2
      # LW
      REGS.set(rd, l(32, rs1, imm))
    when 0x4
      # LBU
      REGS.set(rd, l(8, rs1, imm))
    when 0x5
      # LHU
      REGS.set(rd, l(16, rs1, imm))
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x13
    case funct3
    when 0x0
      # ADDI
      REGS.set(rd, imm + REGS.fetch(rs1))
    when 0x1
      case funct7
      when 0x0
        # SLLI
        shamt = imm & 0x1f
        REGS.set(rd, REGS.fetch(rs1) << shamt)
      else
        raise InvalidOp.new(opcode, funct3, funct7)
      end
    when 0x2
      # SLTI
      REGS.set(rd, signed(REGS.fetch(rs1)) < signed(imm) ? 1 : 0)
    when 0x3
      # SLTIU
      REGS.set(rd, REGS.fetch(rs1) < imm ? 1 : 0)
    when 0x4
      # XORI
      REGS.set(rd, REGS.fetch(rs1) ^ imm)
    when 0x5
      shamt = imm & 0x1f
      case funct7
      when 0x0
        # SRLI
        REGS.set(rd, REGS.fetch(rs1) >> shamt)
      when 0x20
        # SRAI
        REGS.set(rd, signed(REGS.fetch(rs1)) >> shamt)
      else
        raise InvalidOp.new(opcode, funct3, funct7)
      end
    when 0x6
      # ORI
      REGS.set(rd, REGS.fetch(rs1) | imm)
    when 0x7
      # ANDI
      REGS.set(rd, REGS.fetch(rs1) & imm)
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x17
    # AUIPC
    REGS.set(rd, pc + (instruction & 0xffff_f000))
  when 0x23
    imm = (imm & 0xfe0) | rd
    case funct3
    when 0x0
      # SB
      s(8, rs2, rs1, imm)
    when 0x1
      # SH
      s(16, rs2, rs1, imm)
    when 0x2
      # SW
      s(32, rs2, rs1, imm)
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x33
    case [funct3, funct7]
    when [0x0, 0x0]
      # ADD
      REGS.set(rd, REGS.fetch(rs1) + REGS.fetch(rs2))
    when [0x0, 0x20]
      # SUB
      REGS.set(rd, REGS.fetch(rs1) - REGS.fetch(rs2))
    when [0x1, 0x0]
      # SLL
      shamt = REGS.fetch(rs2) & 0x1f
      REGS.set(rd, REGS.fetch(rs1) << shamt)
    when [0x2, 0x0]
      # SLT
      REGS.set(rd, signed(REGS.fetch(rs1)) < signed(REGS.fetch(rs2)) ? 1 : 0)
    when [0x3, 0x0]
      # SLTU
      REGS.set(rd, REGS.fetch(rs1) < REGS.fetch(rs2) ? 1 : 0)
    when [0x4, 0x0]
      # XOR
      REGS.set(rd, REGS.fetch(rs1) ^ REGS.fetch(rs2))
    when [0x5, 0x0]
      # SRL
      shamt = REGS.fetch(rs2) & 0x1f
      REGS.set(rd, REGS.fetch(rs1) >> shamt)
    when [0x5, 0x20]
      # SRA
      shamt = REGS.fetch(rs2) & 0x1f
      REGS.set(rd, signed(REGS.fetch(rs1)) >> shamt)
    when [0x6, 0x0]
      # OR
      REGS.set(rd, REGS.fetch(rs1) | REGS.fetch(rs2))
    when [0x7, 0x0]
      # AND
      REGS.set(rd, REGS.fetch(rs1) & REGS.fetch(rs2))
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x37
    # LUI
    REGS.set(rd, instruction & 0xffff_f000)
  when 0x63
    imm = ((instruction >> 19) & 0xffff_e000) |
          ((instruction & 0x800) << 4) |
          ((instruction >> 20) & 0x7e0) |
          ((instruction >> 7) & 0x1e)
    case funct3
    when 0x0
      # BEQ
      pc += imm if REGS.fetch(rs1) == REGS.fetch(rs2)
    when 0x1
      # BNE
      pc += imm if REGS.fetch(rs1) != REGS.fetch(rs2)
    when 0x4
      # BLT
      pc += imm if signed(REGS.fetch(rs1)) < signed(REGS.fetch(rs2))
    when 0x5
      # BGE
      pc += imm if signed(REGS.fetch(rs1)) >= signed(REGS.fetch(rs2))
    when 0x6
      # BLTU
      pc += imm if REGS.fetch(rs1) < REGS.fetch(rs2)
    when 0x7
      # BGEU
      pc += imm if REGS.fetch(rs1) >= REGS.fetch(rs2)
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x67
    case funct3
    when 0x0
      # JALR
      REGS.set(rd, pc + 4)
      pc = (imm + REGS.fetch(rs1)) & ~1
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x6f
    # JAL
    imm = ((instruction >> 11) & 0xffc0_0000) |
          (instruction & 0xf_f000) |
          ((instruction >> 9) & 0x800) |
          ((instruction >> 20) & 0x7fe0)

    REGS.set(rd, pc + 4)
    pc += imm
  else
    raise InvalidOp.new(opcode, funct3, funct7)
  end

  raise InvalidJump unless (pc % 4).zero?

  REGS[0] = 0 # hardwire the reg
  pc += 4 if old_pc == pc
end

puts 'REGISTERS'
dump_registers
puts "\nMEMORY"
dump_memory
puts
