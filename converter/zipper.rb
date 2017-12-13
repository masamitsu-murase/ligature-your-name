
require "bundler"
require "zip"
require "rbconfig"

module Zipper
    class << self
        def zip(input_filename, entry_name, output_filename)
            Zip::OutputStream.open(output_filename) do |zos|
                zos.put_next_entry entry_name
                zos.puts File.open(input_filename, "rb", &:read)
            end
        end
    end
end

if $0 == __FILE__
    Zipper.zip(ARGV[0], ARGV[1], ARGV[2])
end
