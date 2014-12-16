require_relative '../spec_helper'

describe LogStash::Outputs::Graphite do

  let(:port) { 4939 }
  let(:config) do <<-CONFIG
     input {
        generator {
          message => "foo=fancy bar=42"
          count => 1
          type => "generator"
        }
      }

      filter {
        kv { }
      }

      output {
        graphite {
          host => "localhost"
          port => #{port}
          metrics => [ "hurray.%{foo}", "%{bar}" ]
        }
      }
  CONFIG
  end

  let(:pipeline) { LogStash::Pipeline.new(config) }
  let(:server)   { Mocks::Server.new(port) }

  before do
    server.start
    pipeline.run
  end

  after do
    server.stop
  end

  context "with a default run" do

    it "generate one element" do
      expect(server.size).to eq(1)
    end

    it "include all metrics" do
      lines = server.pop
      expect(lines).to match(/^hurray.fancy 42.0 \d{10,}\n$/)
    end

  end

  context "if fields_are_metrics => true" do
    context "when metrics_format => ..." do

      context "match one key" do
        let(:config) do <<-CONFIG
          input {
            generator {
              message => "foo=123"
              count => 1
              type => "generator"
            }
          }

          filter {
            kv { }
          }

          output {
            graphite {
                host => "localhost"
                port => #{port}
                fields_are_metrics => true
                include_metrics => ["foo"]
                metrics_format => "foo.bar.sys.data.*"
                debug => true
            }
          }
        CONFIG
        end

        it "generate one element" do
          expect(server.size).to eq(1)
        end

        it "match the generated key" do
          lines = server.pop
          expect(lines).to match(/^foo.bar.sys.data.foo 123.0 \d{10,}\n$/)
        end

      end

      context "match all keys" do

        let(:config) do <<-CONFIG
          input {
            generator {
              message => "foo=123 bar=42"
              count => 1
              type => "generator"
            }
          }

          filter {
            kv { }
          }

          output {
            graphite {
                host => "localhost"
                port => #{port}
                fields_are_metrics => true
                include_metrics => [".*"]
                metrics_format => "foo.bar.sys.data.*"
                debug => true
            }
          }
        CONFIG
        end

        let(:lines) do
          dict = {}
          while(!server.empty?)
            line = server.pop
            key  = line.split(' ')[0]
            dict[key] = line
          end
          dict
        end

        it "match the generated foo key" do
          expect(lines['foo.bar.sys.data.foo']).to match(/^foo.bar.sys.data.foo 123.0 \d{10,}\n$/)
        end

        it "match the generated bar key" do
          expect(lines['foo.bar.sys.data.bar']).to match(/^foo.bar.sys.data.bar 42.0 \d{10,}\n$/)
        end

      end

      context "no match" do

        let(:config) do  <<-CONFIG
          input {
            generator {
              message => "foo=123 bar=42"
              count => 1
              type => "generator"
            }
          }

          filter {
            kv { }
          }

          output {
            graphite {
              host => "localhost"
              port => #{port}
              fields_are_metrics => true
              include_metrics => ["notmatchinganything"]
              metrics_format => "foo.bar.sys.data.*"
              debug => true
            }
          }
        CONFIG
        end

        it "generate no event" do
          expect(server.empty?).to eq(true)
        end
      end

      context "match a key with invalid metric_format" do

        let(:config) do <<-CONFIG
          input {
            generator {
              message => "foo=123"
              count => 1
              type => "generator"
            }
          }

          filter {
            kv { }
          }

          output {
            graphite {
                host => "localhost"
                port => #{port}
                fields_are_metrics => true
                include_metrics => ["foo"]
                metrics_format => "invalidformat"
                debug => true
            }
          }
        CONFIG
        end

        it "match the foo key" do
          lines = server.pop
          expect(lines).to match(/^foo 123.0 \d{10,}\n$/)
        end
      end
    end
  end

  context "fields are metrics = false" do
    context "metrics_format not set" do
      context "match one key with metrics list" do

        let(:config) do <<-CONFIG
          input {
            generator {
              message => "foo=123"
              count => 1
              type => "generator"
            }
          }

          filter {
            kv { }
          }

          output {
            graphite {
                host => "localhost"
                port => #{port}
                fields_are_metrics => false
                include_metrics => ["foo"]
                metrics => [ "custom.foo", "%{foo}" ]
                debug => true
            }
          }
        CONFIG
        end

        it "match the custom.foo key" do
          lines = server.pop
          expect(lines).to match(/^custom.foo 123.0 \d{10,}\n$/)
        end

      end
    end
  end

  context "timestamp_field used is timestamp_new" do
    timestamp_new = (Time.now + 3).to_i
    let(:config) do <<-CONFIG
          input {
            generator {
              message => "foo=123"
              count => 1
              type => "generator"
            }
          }

          filter {
            ruby {
              code => "event['timestamp_new'] = Time.at(#{timestamp_new})"
            }
          }

          output {
            graphite {
                host => "localhost"
                port => #{port}
                timestamp_field => "timestamp_new"
                metrics => ["foo", "1"]
                debug => true
            }
          }
    CONFIG
    end

    it "timestamp matches timestamp_new" do
      lines = server.pop
      expect(lines).to match(/^foo 1.0 #{timestamp_new}\n$/)
    end

  end

end
