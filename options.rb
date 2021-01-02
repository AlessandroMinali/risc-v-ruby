# frozen_string_literal: true

require 'optparse'

OPTIONS = {} # rubocop:disable Style/MutableConstant
OptionParser.new do |opts|
  opts.banner = 'Usage: riscv.rb -Eh BINARY_FILE'

  opts.on('-E', 'Run with RV32E') do
    OPTIONS[:embedded] = true
  end

  # opts.on('-mBITS', '--mode=BITS', 'Run in BITS mode (default: 64)') do |v|
  #   raise 'Must include BITS for mode.' unless [32, 64, 128].include?(v.to_i)

  #   OPTIONS[:mode] = v.to_i
  # end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!
