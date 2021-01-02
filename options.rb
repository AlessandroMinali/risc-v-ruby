# frozen_string_literal: true

require 'optparse'

OPTIONS = {} # rubocop:disable Style/MutableConstant
OptionParser.new do |opts|
  opts.banner = 'Usage: riscv.rb -Eh FILE.bin'

  opts.on('-E', 'Run in embedded mode (ie. RV32E)') do
    OPTIONS[:embedded] = true
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!
