# frozen_string_literal: true

redis_versions     = %w[4.2 4.3 4.4]
namespace_versions = %w[1.6 1.7 1.8]

redis_versions.product(namespace_versions).each do |(redis_version, namespace_version)|
  appraise "redis-#{redis_version}.x redis-namespace-#{namespace_version}.x" do
    gem "redis", "~> #{redis_version}.0"

    group :test do
      gem "redis-namespace", "~> #{namespace_version}.0"
    end
  end
end
