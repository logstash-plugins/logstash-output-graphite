require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/graphite"
require_relative "support/server"

class LogStash::Outputs::Graphite
  attr_reader :socket

  def connect
    @socket = Mocks::Server.new
  end
end
