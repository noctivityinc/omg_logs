# spec/spec_helper.rb
require 'bundler/setup'
require 'omg_logs'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# spec/omg_logs_spec.rb
require 'spec_helper'

RSpec.describe OmgLogs do
  it "has a version number" do
    expect(OmgLogs::VERSION).not_to be nil
  end

  describe ".configuration" do
    it "returns a configuration object" do
      expect(OmgLogs.configuration).to be_a(OmgLogs::Configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      expect { |b| OmgLogs.configure(&b) }.to yield_with_args(OmgLogs.configuration)
    end
  end
end
