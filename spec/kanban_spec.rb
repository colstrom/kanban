require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'timeout'

describe 'Backlog' do
  before do
    @backlog = Kanban::Backlog.new backend: Redis.new, namespace: 'kanban:test'
  end

  after(:all) do
    redis = Redis.new
    redis.keys('kanban:test:*').each do |key|
      redis.del key
    end
  end

  it 'instantiates without error' do
    expect(@backlog).to be_an_instance_of(Kanban::Backlog)
  end

  it 'should allow namespace configuration at initialization' do
    expect(@backlog.namespace).to eq 'kanban:test'
  end

  it 'should prefix queue keys with the namespace' do
    expect(@backlog.queue).to start_with('kanban:test')
  end

  it 'should prefix item keys with the namespace' do
    expect(@backlog.item).to start_with('kanban:test')
  end

  it 'should require a backend' do
    expect { Kanban::Backlog.new }.to raise_error(ArgumentError)
  end

  it 'should be able to get a task' do
    expect(@backlog.get(0)).to be_a Hash
  end

  it 'shoud provide the next ID to assign to a task' do
    expect(@backlog.next_id).to be_a Fixnum
  end

  it 'should not reuse IDs' do
    expect(@backlog.next_id).to eq (@backlog.next_id - 1)
  end

  it 'should have a list of tasks waiting to be done' do
    expect(@backlog.todo).to be_an Array
  end

  it 'should throw a TypeError if passed a Hash with Symbol keys' do
    task = { foo: 'bar' }
    expect { @backlog.add task }.to raise_error(TypeError)
  end

  it 'should return the ID of a newly added task' do
    task = { 'foo' => 'bar' }
    expect(@backlog.add(task)).to be_a Fixnum
  end

  it 'should allow Symbol keys with add! method' do
    task = { foo: 'bar' }
    expect(@backlog.add!(task)).to be_a Fixnum
  end

  it 'should preserve the task details' do
    task = { 'foo' => 'bar' }
    expect(@backlog.get(@backlog.add(task))).to eq task
  end

  it 'should add new tasks to the list of tasks waiting to be done' do
    task = { 'foo' => 'bar' }
    id = @backlog.add(task)
    expect(@backlog.todo).to include(id)
  end

  it 'should allow a task to be claimed' do
    expect(@backlog.claim).to be_a Fixnum
  end

  it 'should track the claim separately from the queue it is in' do
    id = @backlog.claim
    expect(@backlog.claimed?(id)).to be true
  end

  it 'should allow claims to expire' do
    id = @backlog.claim(duration: 1)
    sleep 1.1
    expect(@backlog.claimed?(id)).to be false
  end

  it 'should block if there are no pending tasks' do
    redis = Redis.new
    redis.del "#{@backlog.queue}:todo"
    expect do
      Timeout.timeout(0.1) do
        @backlog.claim
      end
    end.to raise_error(Timeout::Error)
  end

  it 'should report if a task is claimed' do
    task = { 'test' => 'data' }
    5.times { @backlog.add(task) }
    id = @backlog.claim
    expect(@backlog.claimed?(id)).to be true
    expect(@backlog.claimed?(0)).to be false
  end

  it 'should have a list of tasks being worked on' do
    id = @backlog.claim
    expect(@backlog.doing).to include(id)
  end

  it 'should allow indicating completion of a task only once' do
    expect(@backlog.complete(1)).to be true
    expect(@backlog.complete(1)).to be false
  end

  it 'should check if a task is completed' do
    expect(@backlog.completed?(2)).to be false
    @backlog.complete 2
    expect(@backlog.completed?(2)).to be true
  end

  it 'should allow indicating a task should not be retried' do
    expect(@backlog.unworkable(3)).to be true
    expect(@backlog.unworkable(3)).to be false
  end

  it 'should check if a task is unworkable' do
    expect(@backlog.unworkable?(4)).to be false
    @backlog.unworkable 4
    expect(@backlog.unworkable?(4)).to be true
  end

  it 'should consider a task that is completed or unworkable to be done' do
    expect(@backlog.done?(0)).to be false
    @backlog.complete(5)
    expect(@backlog.done?(5)).to be true
    @backlog.unworkable(6)
    expect(@backlog.done?(6)).to be true
  end
end
