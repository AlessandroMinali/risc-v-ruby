# frozen_string_literal: true

def b2h(str)
  str.to_i(2).to_s(16)
end

def signed(num)
  [num].pack('L').unpack1('l')
end

def unsigned(num)
  num & (2**XLEN - 1)
end

# load
def l(size, rs1, imm, sign: false)
  address = REG.fetch(rs1) + imm
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
  address = REG.fetch(rs1) + imm
  valid_memory?(address, size)

  r2 = REG.fetch(rs2)
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

def dump_registers
  REG.each.with_index do |i, index|
    print format("x%02<reg>d: %##{(XLEN / 3.25).round}<val>x ", reg: index, val: i)
    print "\n" if ((index + 1) % 4).zero?
  end
end

def dump_memory # rubocop:disable Metrics/AbcSize
  size = XLEN / 8
  MEM.each_slice(size).with_index do |i, index|
    next if i.nil?

    i += Array.new(size - i.size) { 0 } if i.size < size
    i.map!(&:to_i)
    value = i[0] | i[1] << 8 | i[2] << 16 | i[3] << 24 if size >= 4
    value |= i[4] << 32 | i[5] << 40 | i[6] << 48 | i[7] << 56 if size == 8

    print format("%##{(XLEN / 3.25).round}<mem>x: %##{(XLEN / 3.25).round}<val>x ", mem: index * size, val: value)
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
