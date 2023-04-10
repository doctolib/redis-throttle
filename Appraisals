# frozen_string_literal: true

%w[4.1 4.2 4.3 4.4 4.5 4.6].each do |version|
  appraise "redis-rb-#{version}.x" do
    group :test do
      gem "redis", "~> #{version}.0"
    end
  end
end

%w[1.10].each do |version|
  appraise "redis-namespace-#{version}.x" do
    group :test do
      gem "redis-namespace", "~> #{version}.0"
    end
  end
end
