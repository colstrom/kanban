require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Backlog" do
  it "instantiates without error" do
    Kanban::Backlog.new.should be_an_instance_of(Kanban::Backlog)
  end
end
