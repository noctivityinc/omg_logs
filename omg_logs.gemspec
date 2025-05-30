require_relative "lib/omg_logs/version"

Gem::Specification.new do |spec|
  spec.name        = "omg_logs"
  spec.version     = OmgLogs::VERSION
  spec.authors     = ["Josh Lippiner"]
  spec.email       = ["jlippiner@noctivity.com"]
  spec.homepage    = "https://github.com/noctivityinc/omg_logs"
  spec.summary     = "OMG Logs - Enhanced Rails development logging"
  spec.description = "A comprehensive Rails logging enhancement gem that provides beautiful, filtered, and structured logging for development environments"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.require_paths = ["lib"]

  # Ruby version requirement
  spec.required_ruby_version = ">= 2.7.0"

  # Rails dependency
  spec.add_dependency "rails", ">= 6.0", "< 8.0"

  # Logging dependencies
  spec.add_dependency "lograge", "~> 0.12"
  spec.add_dependency "colorize", "~> 0.8"
  spec.add_dependency "amazing_print", "~> 1.4"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
