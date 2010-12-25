require 'yard'
require 'rake/clean'

CLEAN.include('doc/', '*.gem')

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/ical2rem.rb']
  t.options = ['--main', 'README.markdown', '--markup', 'markdown']
end
