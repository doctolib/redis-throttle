# frozen_string_literal: true

%w[4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 5.0].each do |version|
  appraise "redis-rb-#{version}.x" do
    group :test do
      gem "redis", "~> #{version}.0"
    end
  end
end

%w[1.10].each do |version|
  appraise "redis-namespace-#{version}.x" do
    group :test do
      remove_gem "redis"

      gem "redis-namespace", "~> #{version}.0"
    end
  end
end

%w[0.12 0.13 0.14].each do |version|
  appraise "redis-client-#{version}.x" do
    group :test do
      remove_gem "redis"

      gem "redis-client", "~> #{version}.0"
    end
  end
end
