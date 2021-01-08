# frozen_string_literal: true

require_relative 'options'
require_relative 'helpers'
require_relative 'errors'

XLEN = 32
MAX_MEM = 0xffff

# Registers
REG = Array.new(OPTIONS[:embedded] ? 16 : 32) { 0 }
def REG.[]=(index, value)
  return unless fetch(index) { raise InvalidRegister, "x#{index}" }

  super(index, value & (2**XLEN - 1))
end

# Memory
MEM = Array.new(MAX_MEM)
def MEM.[](index)
  super(index % (MAX_MEM + 1)) || 0
end
def MEM.[]=(index, value)
  super(index % (MAX_MEM + 1), value)
end

program = IO.read(ARGV[0])
program_end = program.length
pc = 0

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
      REG[rd] = l(8, rs1, imm, sign: true)
    when 0x1
      # LH
      REG[rd] = l(16, rs1, imm, sign: true)
    when 0x2
      # LW
      REG[rd] = l(32, rs1, imm)
    when 0x4
      # LBU
      REG[rd] = l(8, rs1, imm)
    when 0x5
      # LHU
      REG[rd] = l(16, rs1, imm)
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x13
    case funct3
    when 0x0
      # ADDI
      REG[rd] = imm + REG.fetch(rs1)
    when 0x1
      case funct7
      when 0x0
        # SLLI
        shamt = imm & 0x1f
        REG[rd] = REG.fetch(rs1) << shamt
      else
        raise InvalidOp.new(opcode, funct3, funct7)
      end
    when 0x2
      # SLTI
      REG[rd] = signed(REG.fetch(rs1)) < signed(imm) ? 1 : 0
    when 0x3
      # SLTIU
      REG[rd] = REG.fetch(rs1) < imm ? 1 : 0
    when 0x4
      # XORI
      REG[rd] = REG.fetch(rs1) ^ imm
    when 0x5
      shamt = imm & 0x1f
      case funct7
      when 0x0
        # SRLI
        REG[rd] = REG.fetch(rs1) >> shamt
      when 0x20
        # SRAI
        REG[rd] = signed(REG.fetch(rs1)) >> shamt
      else
        raise InvalidOp.new(opcode, funct3, funct7)
      end
    when 0x6
      # ORI
      REG[rd] = REG.fetch(rs1) | imm
    when 0x7
      # ANDI
      REG[rd] = REG.fetch(rs1) & imm
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x17
    # AUIPC
    REG[rd] = pc + (instruction & 0xffff_f000)
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
      REG[rd] = REG.fetch(rs1) + REG.fetch(rs2)
    when [0x0, 0x1]
      # MUL
      REG[rd] = REG.fetch(rs1) * REG.fetch(rs2)
    when [0x0, 0x20]
      # SUB
      REG[rd] = REG.fetch(rs1) - REG.fetch(rs2)
    when [0x1, 0x0]
      # SLL
      shamt = REG.fetch(rs2) & 0x1f
      REG[rd] = REG.fetch(rs1) << shamt
    when [0x1, 0x1]
      # MULH
      result = signed(REG.fetch(rs1)) * signed(REG.fetch(rs2))
      REG[rd] = result.bit_length > 32 ? (result >> (result.bit_length - 32)) : result
    when [0x2, 0x0]
      # SLT
      REG[rd] = signed(REG.fetch(rs1)) < signed(REG.fetch(rs2)) ? 1 : 0
    when [0x2, 0x1]
      # MULHSU
      result = signed(REG.fetch(rs1)) * REG.fetch(rs2)
      REG[rd] = result.bit_length > 32 ? (result >> (result.bit_length - 32)) : result
    when [0x3, 0x0]
      # SLTU
      REG[rd] = REG.fetch(rs1) < REG.fetch(rs2) ? 1 : 0
    when [0x3, 0x1]
      # MULHU
      result = REG.fetch(rs1) * REG.fetch(rs2)
      REG[rd] = result.bit_length > 32 ? (result >> (result.bit_length - 32)) : result
    when [0x4, 0x0]
      # XOR
      REG[rd] = REG.fetch(rs1) ^ REG.fetch(rs2)
    when [0x4, 0x1]
      # DIV
      r1 = REG.fetch(rs1)
      r2 = REG.fetch(rs2)
      if r2.zero?
        REG[rd] = -1
        break
      elsif r2 == -1 && r1 == unsigned(-2**(XLEN - 1))
        REG[rd] = -2**(XLEN - 1)
        break
      end
      REG[rd] = signed(r1) / signed(r2)
    when [0x5, 0x0]
      # SRL
      shamt = REG.fetch(rs2) & 0x1f
      REG[rd] = REG.fetch(rs1) >> shamt
    when [0x5, 0x1]
      # DIVU
      r2 = REG.fetch(rs2)
      if r2.zero?
        REG[rd] = 2**XLEN - 1
        break
      end
      REG[rd] = REG.fetch(rs1) / r2
    when [0x5, 0x20]
      # SRA
      shamt = REG.fetch(rs2) & 0x1f
      REG[rd] = signed(REG.fetch(rs1)) >> shamt
    when [0x6, 0x0]
      # OR
      REG[rd] = REG.fetch(rs1) | REG.fetch(rs2)
    when [0x6, 0x1]
      # REM
      r1 = REG.fetch(rs1)
      r2 = REG.fetch(rs2)
      if r2.zero?
        REG[rd] = r1
        break
      elsif r2 == -1 && r1 == unsigned(-2**(XLEN - 1))
        REG[rd] = 0
        break
      end
      REG[rd] = signed(r1).remainder(signed(r2))
    when [0x7, 0x0]
      # AND
      REG[rd] = REG.fetch(rs1) & REG.fetch(rs2)
    when [0x7, 0x1]
      # REMU
      r1 = REG.fetch(rs1)
      r2 = REG.fetch(rs2)
      if r2.zero?
        REG[rd] = r1
        break
      end
      REG[rd] = REG.fetch(r1).remainder(REG.fetch(rs2))
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x37
    # LUI
    REG[rd] = instruction & 0xffff_f000
  when 0x63
    imm = (((instruction & 0xf00) >> 7) & ~1) |
          ((instruction & 0x7e000000) >> 20) |
          ((instruction & 0x80) << 4) |
          (signed(instruction & 0x8000_0000) >> 20)

    case funct3
    when 0x0
      # BEQ
      pc += imm if REG.fetch(rs1) == REG.fetch(rs2)
    when 0x1
      # BNE
      pc += imm if REG.fetch(rs1) != REG.fetch(rs2)
    when 0x4
      # BLT
      pc += imm if signed(REG.fetch(rs1)) < signed(REG.fetch(rs2))
    when 0x5
      # BGE
      pc += imm if signed(REG.fetch(rs1)) >= signed(REG.fetch(rs2))
    when 0x6
      # BLTU
      pc += imm if REG.fetch(rs1) < REG.fetch(rs2)
    when 0x7
      # BGEU
      pc += imm if REG.fetch(rs1) >= REG.fetch(rs2)
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x67
    case funct3
    when 0x0
      # JALR
      REG[rd] = pc + 4
      pc = (imm + REG.fetch(rs1)) & ~1
    else
      raise InvalidOp.new(opcode, funct3, funct7)
    end
  when 0x6f
    # JAL
    imm = (((instruction & 0x7fe00000) >> 20) & ~1) |
          ((instruction & 0x100000) >> 9) |
          (instruction & 0xff000) |
          (signed(instruction & 0x8000_0000) >> 11)

    REG[rd] = pc + 4
    pc += imm
  else
    raise InvalidOp.new(opcode, funct3, funct7)
  end

  raise InvalidJump unless (pc % 4).zero?

  REG[0] = 0 # hardwire the reg
  if old_pc == pc
    pc += 4
  elsif pc.zero? # looped back to beginning or program so quit
    break
  end
end

puts 'REGISTERS'
dump_registers
puts "\nMEMORY"
dump_memory
puts
