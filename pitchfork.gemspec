# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pitchfork/version"

Gem::Specification.new do |s|
  s.name        = "pitchfork"
  s.version     = Pitchfork::VERSION
  s.authors     = ["Peter Bui, 8tracks"]
  s.email       = ["peter@paydrotalks.com"]
  s.homepage    = ""
  s.summary     = %q{Easy way to run parallel tasks with Unix fork}
  s.description = %q{Easy way to run parallel tasks with Unix fork}

  # s.rubyforge_project = "pitchfork"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
