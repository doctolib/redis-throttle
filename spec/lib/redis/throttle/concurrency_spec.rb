# frozen_string_literal: true

require "redis/throttle/concurrency"
require "redis/throttle/rate_limit"

RSpec.describe Redis::Throttle::Concurrency do
  subject(:concurrency) { described_class.new(:acab, :limit => 13, :ttl => 12) }

  it { is_expected.to respond_to :bucket }
  it { is_expected.to respond_to :limit }
  it { is_expected.to respond_to :ttl }

  describe "#==" do
    subject { concurrency == other }

    let(:other)  { described_class.new(bucket, :limit => limit, :ttl => ttl) }
    let(:bucket) { concurrency.bucket }
    let(:limit)  { concurrency.limit }
    let(:ttl)    { concurrency.ttl }

    it { is_expected.to be true }

    context "when bucket differs" do
      let(:bucket) { "#{concurrency.bucket}x" }

      it { is_expected.to be false }
    end

    context "when limit differs" do
      let(:limit) { concurrency.limit + 1 }

      it { is_expected.to be false }
    end

    context "when ttl differs" do
      let(:ttl) { concurrency.ttl + 1 }

      it { is_expected.to be false }
    end
  end

  describe "#eql?" do
    it "is an alias of #==" do
      expect(concurrency.method(:eql?).original_name).to eq :==
    end
  end

  describe "#<=>" do
    subject { concurrency <=> other }

    let(:other)  { described_class.new(bucket, :limit => limit, :ttl => ttl) }
    let(:bucket) { concurrency.bucket }
    let(:limit)  { concurrency.limit }
    let(:ttl)    { concurrency.ttl }

    it { is_expected.to eq 0 }

    context "when bucket differs" do
      let(:bucket) { "#{concurrency.bucket}x" }

      it { is_expected.to eq 0 }
    end

    context "when other limit is bigger" do
      let(:limit) { concurrency.limit + 1 }

      it { is_expected.to eq(-1) }
    end

    context "when other limit is smaller" do
      let(:limit) { concurrency.limit - 1 }

      it { is_expected.to eq 1 }
    end

    context "when ttl differs" do
      let(:ttl) { concurrency.ttl + 1 }

      it { is_expected.to eq 0 }
    end

    context "when other is an instance of RateLimit" do
      let(:other) { Redis::Throttle::RateLimit.new(bucket, :limit => limit, :period => 123) }

      it { is_expected.to eq 1 }
    end

    context "when other is neither Concurrency nor RateLimit" do
      let(:other) { double }

      it { is_expected.to be_nil }
    end
  end

  describe "#hash" do
    subject { concurrency.hash }

    let(:other)  { described_class.new(bucket, :limit => limit, :ttl => ttl) }
    let(:bucket) { concurrency.bucket }
    let(:limit)  { concurrency.limit }
    let(:ttl)    { concurrency.ttl }

    it { is_expected.to eq other.hash }

    context "when bucket differs" do
      let(:bucket) { "#{concurrency.bucket}x" }

      it { is_expected.not_to eq other.hash }
    end

    context "when limit differs" do
      let(:limit) { concurrency.limit + 1 }

      it { is_expected.not_to eq other.hash }
    end

    context "when ttl differs" do
      let(:ttl) { concurrency.ttl + 1 }

      it { is_expected.not_to eq other.hash }
    end
  end
end
