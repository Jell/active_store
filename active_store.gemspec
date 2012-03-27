# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "active_store/version"

Gem::Specification.new do |s|
  s.name        = "active_store"
  s.version     = ActiveStore::VERSION
  s.authors     = ["Petter Remen", "Jean-Louis Giordano"]
  s.email       = ["petter@icehouse.se", "jean-louis@icehouse.se"]
  s.homepage    = ""
  s.summary     = %q{A active record-like wrapper for memcached protocol}
  s.description = %q{}

  s.rubyforge_project = "active_store"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  s.add_development_dependency "rake"
  s.add_runtime_dependency "dalli"
  s.add_runtime_dependency "activesupport"
end
