# frozen_string_literal: true

require_relative "./lib/redis/throttle/version"

Gem::Specification.new do |spec|
  spec.name          = "redis-throttle"
  spec.version       = Redis::Throttle::VERSION
  spec.authors       = ["Alexey Zapparov"]
  spec.email         = ["alexey@zapparov.com"]

  spec.summary       = "Redis based threshold and concurrency throttling."
  spec.homepage      = "https://gitlab.com/ixti/redis-throttle"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/v#{spec.version}"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/v#{spec.version}/CHANGES.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").select do |f|
      f.start_with?("lib/") || %w[CHANGES.md LICENSE.txt README.md].include?(f)
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "~> 2.5"

  spec.add_runtime_dependency "redis", "~> 4.0"

  spec.add_development_dependency "bundler", "~> 2.0"
end