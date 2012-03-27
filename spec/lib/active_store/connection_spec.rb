# encoding: UTF-8
require 'spec_helper'

describe ActiveStore::Connection do
  before do
    @connection = ActiveStore::Connection.new(nil, 'test', 30 * 24 * 3600)
  end

  it "it sets and gets values from db" do
    @connection.set "test", "foo" => "boo", "sha" => "bada"
    @connection.get("test").should == {"foo" => "boo", "sha" => "bada"}
  end

  it "sets data as JSON" do
    @connection.set "test", :foo => "boo", :sha => "bada"
    @connection.get_raw("test").should == '{"foo":"boo","sha":"bada"}'
  end

  it "adds data as JSON" do
    @connection.add("test", :foo => "boo", :sha => "bada").should be_true
    @connection.get_raw("test").should == '{"foo":"boo","sha":"bada"}'
  end

  it "get returns nil if the key doesn't exist" do
    @connection.get("asdfgasda").should be_nil
  end

  it "get does not create Time-like objects from Time-like strings" do
    time_str = Time.now.to_s
    date_str = Date.today.to_s
    @connection.set("test", "foo" => time_str, "bar" => date_str)
    @connection.get("test").should == {
      "foo" => time_str,
      "bar" => date_str
    }
  end

  it "cas data as JSON" do
    @connection.set_raw("test", '{"foo":"boo","sha":"bada"}', 1)
    @connection.cas "test" do |data|
      data.should == {"foo" => "boo", "sha" => "bada"}
      data["shi"] = "bidi"
      data
    end
    @connection.get_raw("test").should == '{"foo":"boo","sha":"bada","shi":"bidi"}'
  end

  it "gets data as JSON" do
    @connection.set_raw("test", '{"foo":"boo","sha":"bada"}', 1)
    @connection.get("test").should == {"foo" => "boo", "sha" => "bada"}
  end

  it "Works with increment" do
    @connection.set("test", 10)
    @connection.incr("test").should == 11
  end

  it "Works with strings" do
    @connection.set("test", "some value")
    @connection.get("test").should == "some value"
  end

  it "supports non-ascii keys" do
    @connection.set("testäöå", "3")
    @connection.get("testäöå").should == "3"
  end

  it "supports spaces in keys" do
    @connection.set(" foo\n", "2")
    @connection.get(" foo\n").should == "2"
  end

  describe "#store" do
    it "returns a Dalli::Client" do
      @connection.store = nil
      @connection.store.should be_instance_of(Dalli::Client)
    end

    it "raises an exception when it cannot connect" do
      connection = ActiveStore::Connection.new("localhost:1234", "test", 0)
      expect {connection.store}.to raise_error
      # Tests that we clear the memoization to try again
      expect {connection.store}.to raise_error
    end
  end
end
