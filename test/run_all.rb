Dir.glob("./test/**/*_test.rb").each do |test_file|
  require test_file
end
