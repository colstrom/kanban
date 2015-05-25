require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Backlog" do
  before do
    @backlog = Kanban::Backlog.new backend: Redis.new
  end

  it "instantiates without error" do
    expect(@backlog).to be_an_instance_of(Kanban::Backlog)
  end

  it "should have a namespace" do
    expect(@backlog.namespace).to eq 'default'
  end

  it "should allow namespace configuration at initialization" do
    backlog = Kanban::Backlog.new namespace: 'foo', backend: nil
    expect(backlog.namespace).to eq 'foo'
  end

  it "should prefix queue keys with the namespace" do
    expect(@backlog.queue).to start_with('default')
  end

  it "should prefix item keys with the namespace" do
    expect(@backlog.item).to start_with('default')
  end

  it "should require a backend" do
    expect { Kanban::Backlog.new }.to raise_error(ArgumentError)
  end

  it "should be able to get a task" do
    expect(@backlog.get(0)).to be_a Hash
  end
end
