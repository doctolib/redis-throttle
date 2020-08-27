# frozen_string_literal: true

require "redis/throttle/concurrency"
require "redis/throttle/threshold"

RSpec.describe Redis::Throttle::Threshold do
  subject(:threshold) { described_class.new(:acab, :limit => 13, :period => 12) }

  it { is_expected.to respond_to :bucket }
  it { is_expected.to respond_to :limit }
  it { is_expected.to respond_to :period }

  describe "#==" do
    subject { threshold == other }

    let(:other)  { described_class.new(bucket, :limit => limit, :period => period) }
    let(:bucket) { threshold.bucket }
    let(:limit)  { threshold.limit }
    let(:period) { threshold.period }

    it { is_expected.to be true }

    context "when bucket differs" do
      let(:bucket) { "#{threshold.bucket}x" }

      it { is_expected.to be false }
    end

    context "when limit differs" do
      let(:limit) { threshold.limit + 1 }

      it { is_expected.to be false }
    end

    context "when period differs" do
      let(:period) { threshold.period + 1 }

      it { is_expected.to be false }
    end
  end

  describe "#eql?" do
    it "is an alias of #==" do
      expect(threshold.method(:eql?).original_name).to eq :==
    end
  end

  describe "#<=>" do
    subject { threshold <=> other }

    let(:other)  { described_class.new(bucket, :limit => limit, :period => period) }
    let(:bucket) { threshold.bucket }
    let(:limit)  { threshold.limit }
    let(:period) { threshold.period }

    it { is_expected.to eq 0 }

    context "when bucket differs" do
      let(:bucket) { "#{threshold.bucket}x" }

      it { is_expected.to eq 0 }
    end

    context "when other limit is bigger" do
      let(:limit) { threshold.limit + 1 }

      it { is_expected.to eq(-1) }
    end

    context "when other limit is smaller" do
      let(:limit) { threshold.limit - 1 }

      it { is_expected.to eq 1 }
    end

    context "when period differs" do
      let(:period) { threshold.period + 1 }

      it { is_expected.to eq 0 }
    end

    context "when other is an instance of Concurrency" do
      let(:other) { Redis::Throttle::Concurrency.new(bucket, :limit => limit, :ttl => 123) }

      it { is_expected.to eq(-1) }
    end

    context "when other is neither Concurrency nor Threshold" do
      let(:other) { double }

      it { is_expected.to be_nil }
    end
  end

  describe "#hash" do
    subject { threshold.hash }

    let(:other)  { described_class.new(bucket, :limit => limit, :period => period) }
    let(:bucket) { threshold.bucket }
    let(:limit)  { threshold.limit }
    let(:period) { threshold.period }

    it { is_expected.to eq other.hash }

    context "when bucket differs" do
      let(:bucket) { "#{threshold.bucket}x" }

      it { is_expected.not_to eq other.hash }
    end

    context "when limit differs" do
      let(:limit) { threshold.limit + 1 }

      it { is_expected.not_to eq other.hash }
    end

    context "when period differs" do
      let(:period) { threshold.period + 1 }

      it { is_expected.not_to eq other.hash }
    end
  end
end
