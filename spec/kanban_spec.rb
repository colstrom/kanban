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
end
