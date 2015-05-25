require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Backlog" do
  before do
    @backlog = Kanban::Backlog.new
  end

  it "instantiates without error" do
    @backlog.should be_an_instance_of(Kanban::Backlog)
  end

  it "should have a namespace" do
    @backlog.namespace.should == 'default'
  end

  it "should allow namespace configuration at initialization" do
    backlog = Kanban::Backlog.new namespace: 'foo'
    backlog.namespace.should == 'foo'
  end

  it "prefix queue keys with the namespace" do
    @backlog.queue.should start_with? 'default'
  end
end
