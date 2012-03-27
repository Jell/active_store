require 'spec_helper'

describe ActiveStore::Base do
  before do
    class ItemStore < ActiveStore::Base
      define_attributes :a1, :a2
      self.namespace = "item"
      self.default_ttl = 0
      self.connection_string = nil
    end
  end

  describe ".connection_string" do
    it "defaults to Base value if nil" do
      ActiveStore::Base.connection_string = "some_string"
      ItemStore.connection_string.should == "some_string"
      ItemStore.connection_string = "some other string"
      ActiveStore::Base.connection_string.should == "some_string"
      ItemStore.connection_string.should == "some other string"
    end
  end
  describe ".namespace" do
    it "forces a new connection" do
      connection = ItemStore.connection
      ItemStore.namespace = "item"
      ItemStore.connection.should_not be_eql connection
    end
    it "sends itself as a parameter to Connection.new" do
      ItemStore.connection.namespace.should == "item"
      ItemStore.namespace = "foo"
      ItemStore.connection.namespace.should == "foo"
    end
    it "defaults to the name of the class" do
      ItemStore.namespace = nil
      ItemStore.namespace.should == 'ItemStore'
    end
  end

  describe ".default_ttl" do
    it "forces a new connection" do
      connection = ItemStore.connection
      ItemStore.default_ttl = 2
      ItemStore.connection.should_not be_eql connection
    end
    it "sends itself as a parameter to Connection.new" do
      ItemStore.connection.default_ttl.should == 0
      ItemStore.default_ttl = 2
      ItemStore.connection.default_ttl.should == 2
    end
    it "defaults to 30 days" do
      ItemStore.default_ttl = nil
      ItemStore.default_ttl.should == 30 * 24 * 3600
    end
  end

  it "lists attibute names" do
    ItemStore.attributes.should include :a1, :a2
  end

  it "provides accessors for its attributes" do
    item = ItemStore.new
    item.a1.should be_nil
    (item.a1 = "new_value").should == "new_value"
    item.a1.should == "new_value"
  end

  describe ".define_attributes" do
    it "should add id and created_at in attributes" do
      ItemStore.attributes.should include :id, :created_at
    end
    it "should add id and created_at in its instance accessors" do
      ItemStore.new.methods.map(&:to_sym).should include :id, :id=, :created_at, :created_at=
    end
  end

  describe "#initialize" do
    it "initializes given attributes" do
      params = { :a1 => "one", :a2 => "two" }
      item = ItemStore.new params
      item.attributes[:a1].should == params[:a1]
      item.attributes[:a2].should == params[:a2]
    end
    it "initializes attributes even when the params keys are strings" do
      params = { "a1" => "one", "a2" => "two" }
      item = ItemStore.new params
      item.attributes[:a1].should == params["a1"]
      item.attributes[:a2].should == params["a2"]
    end
    it "doesn't require attributes" do
      ItemStore.new.a1.should be_nil
    end
    it "sets created_at if not given in params" do
      ItemStore.new.created_at.should be_within(1).of(Time.now)
    end
    it "sets created_at if given" do
      ItemStore.new(:created_at => "some time").created_at.should == "some time"
    end
    it "can set attribute to false" do
      item = ItemStore.new "a1" => false
      item.attributes[:a1].should == false
    end
  end

  describe "#==" do
    it "returns true if all attributes are the same" do
      params = { :a1 => "one", :a2 => "two" }
      (ItemStore.new(params) == ItemStore.new(params)).should be_true
    end
    it "returns false any of the attributes are different" do
      params1 = { :a1 => "one", :a2 => "two"}
      params2 = { :a1 => "different", :a2 => "two" }
      (ItemStore.new(params1) == ItemStore.new(params2)).should be_false
    end
  end

  describe "#update_attribute" do
    it "updates given attribute and saves" do
      item = ItemStore.new :id => "myid"
      item.update_attribute(:a1, "new_value").should be_true
      item.reload.a1.should be_true
    end
    it "returns false if id is missing" do
      item = ItemStore.new
      item.update_attribute(:a1, "new_value").should be_false
    end
    it "raises if attribute is missing" do
      item = ItemStore.new
      expect { item.update_attribute :apa, true }.to raise_exception(NoMethodError)
    end
  end

  describe "#update_attributes" do
    it "updates all given attributes" do
      item = ItemStore.new :id => "myid"
      item.update_attributes(:a1 => "one", :a2 => "two").should == true
      item.reload
      item.a1.should == "one"
      item.a2.should == "two"
    end
    it "returns false if id is missing" do
      item = ItemStore.new
      item.update_attributes(:a1 => "new_value").should be_false
    end
  end

  describe ".cas_update" do
    context "when the given id does not exist" do
      it "returns nil" do
        ItemStore.cas_update("nonexistent").should be_nil
      end
      it "should not run the block" do
        ItemStore.cas_update("nonexistent") do
          true.should be_false
        end
      end
    end
    context "when the record has been updated before CAS set operation" do
      it "returns false" do
        ItemStore.create :id => "existent", :a1 => "foo"
        ItemStore.cas_update("existent") do |item|
          same_item = ItemStore.find("existent")
          same_item.a1 = "bar"
          same_item.save
          item.a1 = "baz"
        end.should be_false
      end
      it "doesn't modify the record" do
        ItemStore.create :id => "existent", :a1 => "foo"
        ItemStore.cas_update("existent") do |item|
          same_item = ItemStore.find("existent")
          same_item.a1 = "bar"
          same_item.save
          item.a1 = "baz"
        end
        ItemStore.find("existent").a1.should == "bar"
      end
    end
    context "otherwise" do
      it "returns true" do
        ItemStore.create :id => "existent"
        ItemStore.cas_update("existent") do |item|
          item.a1 = "baz"
        end.should be_true
      end
      it "updates the record" do
        ItemStore.create :id => "existent"
        ItemStore.cas_update("existent") do |item|
          item.a1 = "baz"
        end
        ItemStore.find("existent").a1.should == "baz"
      end
    end
  end

  describe "cas_update_or_create" do
    it "tries to update the record using cas_update" do
      proc_mock = Proc.new {}
      ItemStore.should_receive(:cas_update).with("old", ItemStore.default_ttl, &proc_mock).and_return(true)
      ItemStore.cas_update_or_create("old", &proc_mock)
    end

    it "creates the record create_with_block if the CAS operation fails due to missing record" do
      proc_mock = Proc.new {}
      ItemStore.stub!(:cas_update).and_return(nil)
      ItemStore.should_receive(:create_with_block).with("old", ItemStore.default_ttl, &proc_mock)
      ItemStore.cas_update_or_create("old", &proc_mock)
    end

    it "returns false if update_cas returns false" do
      proc_mock = Proc.new {}
      ItemStore.stub!(:cas_update).and_return(false)
      ItemStore.cas_update_or_create("foo", &proc_mock).should be_false
    end

    it "returns false if create_with_block returns false" do
      proc_mock = Proc.new {}
      ItemStore.stub!(:cas_update).and_return(nil)
      ItemStore.stub!(:create_with_block).and_return(false)
      ItemStore.cas_update_or_create("foo", &proc_mock).should be_false
    end

    it "returns true if the record was successfully created" do
      ItemStore.cas_update_or_create("foo") {}.should be_true
    end

    it "returns true if the record was successfully modified" do
      ItemStore.create(:id => "foo")
      ItemStore.cas_update_or_create("foo") {}.should be_true
    end

  end

  describe "stm_update_or_create" do
    it "performs a cas_update_or_create" do
      to_run = Proc.new(){}
      ItemStore.should_receive(:cas_update_or_create) do |id, &block|
        id.should == :some_id
        block.should == to_run
        true
      end
      ItemStore.stm_update_or_create(:some_id, &to_run).should be_true
    end
    it "performs a cas_update_or_create until success" do
      ItemStore.should_receive(:cas_update_or_create).exactly(3).times.and_return(false, false, true)
      ItemStore.stm_update_or_create(:some_id){}.should be_true
    end
  end

  describe "#create_with_block" do
    it "creates a new record if it doesn't exist" do
      ItemStore.create_with_block("foo") do |item|
        item.a1 = "bar"
      end
      ItemStore.find("foo").a1.should == "bar"
    end

    context "if the record already exists" do
      before do
        ItemStore.create(:id => "foo", :a1 => "bar")
      end

      it "returns false" do
        ItemStore.create_with_block("foo") {}.should be_false
      end

      it "doesn't update the record" do
        ItemStore.create_with_block("foo") do |item|
          item.a1 = "baz"
        end
        ItemStore.find("foo").a1.should == "bar"
      end
    end
  end

  describe "#reload" do
    it "reloads attributes from db" do
      item = ItemStore.new :id => "myid"
      ItemStore.connection.set("myid", :a1 => "new value")
      item.reload
      item.a1.should == "new value"
    end
    it "raises if no id is set" do
      expect { ItemStore.new.reload }.to raise_exception(ActiveStore::Base::NoIdError)
    end
    it "raises if no id is empty string" do
      expect { ItemStore.new(:id => "").reload }.to raise_exception(ActiveStore::Base::NoIdError)
    end
  end

  describe "#save" do
    it "saves attribute do db" do
      ItemStore.find("myid").should be_nil
      item = ItemStore.new :id =>"myid", :a1 => "one", :a2 => "two"
      item.save.should be_true
      item.created_at.should_not be_nil
      ItemStore.find("myid").should == item
    end
    it "returns false if id is nil" do
      item = ItemStore.new :id => nil
      item.save.should be_false
    end
    it "saves with a given ttl" do
      item = ItemStore.new :id => "myid", :a1 => "one", :a2 => "two"
      ItemStore.connection.should_receive(:set).with(anything, anything, 2 * 24 * 3600)
      item.save(2 * 24 * 3600)
    end
    it "saves with default ttl if not specified otherwise" do
      item = ItemStore.new :id => "myid", :a1 => "one", :a2 => "two"
      ItemStore.connection.should_receive(:set).with(anything, anything, ItemStore.default_ttl)
      item.save
    end
  end

  describe "#save!" do
    it "calls save" do
      item = ItemStore.new :id => "myid"
      item.should_receive(:save).and_return(true)
      item.save!
    end
    it "it returns true on successfull save" do
      item = ItemStore.new :id => "myid"
      item.save!.should be_true
    end
    it "raises if id is nil" do
      item = ItemStore.new :id => nil
      expect { item.save! }.to raise_exception(ActiveStore::Base::NoIdError)
    end
    it "saves with a given ttl" do
      item = ItemStore.new :id => "myid"
      ItemStore.connection.should_receive(:set).with(anything, anything, 2 * 24 * 3600)
      item.save!(2 * 24 * 3600)
    end
    it "saves with default ttl if not specified otherwise" do
      item = ItemStore.new :id => "myid"
      ItemStore.connection.should_receive(:set).with(anything, anything, ItemStore.default_ttl)
      item.save!
    end
  end

  describe ".create" do
    it "creates an item and saves it" do
      item = ItemStore.create :id => "myid", :a1 => "one", :a2 => "two"
      ItemStore.find("myid").should == item
    end
    it "returns the created campaign" do
      ItemStore.create(:id => "myid").should be_a(ItemStore)
    end
  end

  describe ".find" do
    it "returns nil for nil" do
      ItemStore.find(nil).should == nil
    end
    it "returns nil for empty string" do
      ItemStore.find("").should == nil
    end
    it "returns nil if no match" do
      ItemStore.find("no_match").should == nil
    end
    it "returns item if match" do
      item = ItemStore.create :id => "match"
      ItemStore.find("match").should == item
    end
  end

  describe ".find_or_initialize_by_id" do
    it "returns found dossier if present" do
      ItemStore.should_receive(:find).with("some_id").and_return("found_dossier")
      ItemStore.find_or_initialize_by_id("some_id").should == "found_dossier"
    end
    it "initializes a new dossier if none is present" do
      ItemStore.should_receive(:find).with("some_id").and_return(nil)
      ItemStore.find_or_initialize_by_id("some_id").id.should == "some_id"
    end
  end

end

