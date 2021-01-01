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
