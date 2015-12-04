# encoding: utf-8

require_relative '../spec_helper'

describe LogStash::Outputs::Graphite do

  let(:port) { 4939 }
  let(:server) { subject.socket }

  before :each do
    subject.register
    subject.receive(event)
  end

  context "with a default run" do

    subject { LogStash::Outputs::Graphite.new("host" => "localhost", "port" => port, "metrics" => [ "hurray.%{foo}", "%{bar}" ]) }
    let(:event) { LogStash::Event.new("foo" => "fancy", "bar" => 42) }

    it "generate one element" do
      expect(server.size).to eq(1)
    end

    it "include all metrics" do
      line = server.pop
      expect(line).to match(/^hurray.fancy 42.0 \d{10,}\n$/)
    end
  end

  context "if fields_are_metrics => true" do
    context "when metrics_format => ..." do
      subject { LogStash::Outputs::Graphite.new("host" => "localhost",
                                                      "port" => port,
                                                      "fields_are_metrics" => true,
                                                      "include_metrics" => ["foo"],
                                                      "metrics_format" => "foo.%{@host}.sys.data.*") }

      let(:event) { LogStash::Event.new("foo" => "123", "@host" => "testhost") }
      let(:expected_metric_prefix) { "foo.#{event['@host']}.sys.data" }

      context "match one key" do
        it "should generate one element" do
          expect(server.size).to eq(1)
        end

        it "should match the generated key" do
          line = server.pop
          expect(line).to match(/^#{expected_metric_prefix}.foo 123.0 \d{10,}\n$/)
        end
      end

      context "when matching a nested hash" do
        let(:event) { LogStash::Event.new("foo" => {"a" => 3, "c" => {"d" => 2}}, "@host" => "myhost") }

        it "should create the proper formatted lines" do
          lines = [server.pop, server.pop].sort # Put key 'a' first
          expect(lines[0]).to match(/^#{expected_metric_prefix}.foo.a 3 \d{10,}\n$/)
          expect(lines[1]).to match(/^#{expected_metric_prefix}.foo.c.d 2 \d{10,}\n$/)
        end
      end
    end

    context "match all keys" do

      subject { LogStash::Outputs::Graphite.new("host" => "localhost",
                                                      "port" => port,
                                                      "fields_are_metrics" => true,
                                                      "include_metrics" => [".*"],
                                                      "metrics_format" => "foo.bar.sys.data.*") }

      let(:event) { LogStash::Event.new("foo" => "123", "bar" => "42") }

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

      subject { LogStash::Outputs::Graphite.new("host" => "localhost",
                                                      "port" => port,
                                                      "fields_are_metrics" => true,
                                                      "include_metrics" => ["notmatchinganything"],
                                                      "metrics_format" => "foo.bar.sys.data.*") }

      let(:event) { LogStash::Event.new("foo" => "123", "bar" => "42") }

      it "generate no event" do
        expect(server.empty?).to eq(true)
      end
    end

    context "match a key with invalid metric_format" do

      subject { LogStash::Outputs::Graphite.new("host" => "localhost",
                                                      "port" => port,
                                                      "fields_are_metrics" => true,
                                                      "include_metrics" => ["foo"],
                                                      "metrics_format" => "invalidformat") }

      let(:event) { LogStash::Event.new("foo" => "123") }

      it "match the foo key" do
        line = server.pop
        expect(line).to match(/^foo 123.0 \d{10,}\n$/)
      end
    end
  end

  context "fields are metrics = false" do
    context "metrics_format not set" do
      context "match one key with metrics list" do

        subject { LogStash::Outputs::Graphite.new("host" => "localhost",
                                                        "port" => port,
                                                        "fields_are_metrics" => false,
                                                        "include_metrics" => ["foo"],
                                                        "metrics" => [ "custom.foo", "%{foo}" ]) }

        let(:event) { LogStash::Event.new("foo" => "123") }

        it "match the custom.foo key" do
          line = server.pop
          expect(line).to match(/^custom.foo 123.0 \d{10,}\n$/)
        end

        context "when matching a nested hash" do
          let(:event) { LogStash::Event.new("custom.foo" => {"a" => 3, "c" => {"d" => 2}}) }

          it "should create the proper formatted lines" do
            lines = [server.pop, server.pop].sort # Put key 'a' first
            expect(lines[0]).to match(/^custom.foo.a 3 \d{10,}\n$/)
            expect(lines[1]).to match(/^custom.foo.c.d 2 \d{10,}\n$/)
          end
        end
      end
    end
  end

  context "timestamp_field used is timestamp_new" do

    let(:timestamp_new) { (Time.now + 3).to_i }

    subject { LogStash::Outputs::Graphite.new("host" => "localhost",
                                                    "port" => port,
                                                    "timestamp_field" => "timestamp_new",
                                                    "metrics" => ["foo", "1"]) }

    let(:event) { LogStash::Event.new("foo" => "123", "timestamp_new" => timestamp_new) }

    it "timestamp matches timestamp_new" do
      line = server.pop
      expect(line).to match(/^foo 1.0 #{timestamp_new}\n$/)
    end
  end

  describe "dotifying a hash" do
    let(:event) { LogStash::Event.new( "metrics" => hash) }
    let(:dotified) { LogStash::Outputs::Graphite.new().send(:dotify, hash) }

    context "with a complex hash" do
      let(:hash) { {:a => 2, :b => {:c => 3, :d => 4, :e => {:f => 5}}} }

      it "should dottify correctly" do
        expect(dotified).to eql({"a" => 2, "b.c" => 3, "b.d" => 4, "b.e.f" => 5})
      end
    end

    context "with a simple hash" do
      let(:hash) { {:a => 2, 5 => 4} }

      it "should do nothing more than stringify the keys" do
        expect(dotified).to eql("a" => 2, "5" => 4)
      end
    end

    context "with an array value" do
      let(:hash) { {:a => 2, 5 => 4, :c => [1,2,3]} }

      it "should ignore array values" do
        expect(dotified).to eql("a" => 2, "5" => 4)
      end
    end
  end
end
