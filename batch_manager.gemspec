lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'batch_manager/version'

Gem::Specification.new do |s|
  s.name          = 'batch_manager'
  s.version       = BatchManager::VERSION
  s.authors       = ['Dominic Sayers']
  s.email         = ['dominic@sayers.cc']
  s.summary       = 'Manage long-running jobs'
  s.homepage      = 'https://github.com/dominicsayers/batch_manager'
  s.license       = 'MIT'

  s.files = `git ls-files lib LICENSE`.split($RS)
  s.require_paths = ['lib']

  s.add_runtime_dependency 'actionview'
  s.add_runtime_dependency 'activesupport'
end
