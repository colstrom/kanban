require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Backlog" do
  it "instantiates without error" do
    expect(Kanban::Backlog.new).to be_an_instance_of(Kanban::Backlog)
  end
end
