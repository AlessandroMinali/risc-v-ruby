require 'optparse'

OPTIONS = {}
OptionParser.new do |opts|
  opts.banner = "Usage: riscv.rb [binary]"

  opts.on("-E", "Run with RV32E") do |v|
    OPTIONS[:embedded] = true
  end
end.parse!