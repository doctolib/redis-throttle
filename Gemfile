# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in redis-throttle.gemspec
gemspec

gem "appraisal"

gem "rake", "~> 12.0"

group :development do
  gem "benchmark-ips"
  gem "guard"
  gem "guard-rspec"
  gem "guard-rubocop"
  gem "pry"
end

group :test do
  gem "redis-namespace"
  gem "rspec"
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rspec"
  gem "simplecov"
  gem "terminal-table"
  gem "timecop"
end