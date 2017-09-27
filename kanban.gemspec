Gem::Specification.new do |gem|
  gem.name        = 'kanban'
  gem.version     = `git describe --tags --abbrev=0`.chomp
  gem.licenses    = 'MIT'
  gem.authors     = ['Chris Olstrom']
  gem.email       = 'chris@olstrom.com'
  gem.homepage    = 'https://github.com/colstrom/kanban'
  gem.summary     = 'Agile Workflow for Ruby Programs'

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_runtime_dependency 'contracts', '~> 0.16', '>= 0.16.0'
  gem.add_runtime_dependency 'redis', '~> 4.0', '>= 4.0.0'
  gem.add_development_dependency 'bundler', '~> 1.15', '>= 1.15.0'
  gem.add_development_dependency 'rake', '~> 12.1', '>= 12.1.0'
  gem.add_development_dependency 'reek', '~> 4.7', '>= 4.7.0'
  gem.add_development_dependency 'roodi', '~> 5.0', '>= 5.0.0'
  gem.add_development_dependency 'rspec', '~> 3.6', '>= 3.6.0'
  gem.add_development_dependency 'simplecov', '~> 0.15', '>= 0.15.0'
  gem.add_development_dependency 'yard', '~> 0.9', '>= 0.9.0'
end
