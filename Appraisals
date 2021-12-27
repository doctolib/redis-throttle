# frozen_string_literal: true

%w[4.2 4.3 4.4].each do |redis_gem_version|
  appraise "redis-#{redis_gem_version}.x" do
    gem "redis", "~> #{redis_gem_version}.0"
  end
end
