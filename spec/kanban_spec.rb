require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'timeout'

describe 'Backlog' do
  let(:redis) { Redis.new }
  let(:backlog) { Kanban::Backlog.new backend: redis, namespace: 'kanban:test' }

  before do
    task = { 'test' => 'data' }
    5.times { backlog.add(task) }
  end

  after(:all) do
    redis = Redis.new
    redis.keys('kanban:test:*').each do |key|
      redis.del key
    end
  end

  describe '#new' do
    it 'should require a backend' do
      expect { Kanban::Backlog.new }.to raise_error(ArgumentError)
    end

    subject { backlog }
    it { is_expected.to be_an_instance_of Kanban::Backlog }

    context 'when no optional parameters are given' do
      let(:backlog) { Kanban::Backlog.new backend: redis }

      describe '.namespace' do
        subject { backlog.namespace }
        it { is_expected.to eq 'default' }
      end

      describe '.queue' do
        subject { backlog.queue }
        it { is_expected.to eq 'default:tasks' }
      end

      describe '.item' do
        subject { backlog.item }
        it { is_expected.to eq 'default:task' }
      end
    end

    context 'when :namespace is "testing"' do
      let(:backlog) { Kanban::Backlog.new backend: redis, namespace: 'testing' }

      describe '.namespace' do
        subject { backlog.namespace }
        it { is_expected.to eq 'testing' }
      end
    end

    context 'when :queue is "tests"' do
      let(:backlog) { Kanban::Backlog.new backend: redis, queue: 'tests' }
      describe '.queue' do
        subject { backlog.queue }
        it { is_expected.to eq 'default:tests' }
      end
    end

    context 'when :item is "test"' do
      let(:backlog) { Kanban::Backlog.new backend: redis, item: 'test' }
      describe '.item' do
        subject { backlog.item }
        it { is_expected.to eq 'default:test' }
      end
    end
  end

  describe '#get' do
    context 'when the task does not exist' do
      subject { backlog.get 0 }
      it { is_expected.to be_empty }
    end

    context 'when the task is {"test"=>"data"}' do
      let(:task) { ({ 'test' => 'data' }) }
      let(:id) { backlog.add task }
      subject { backlog.get id }
      it { is_expected.to eq task }
    end
  end

  it 'shoud provide the next ID to assign to a task' do
    expect(backlog.next_id).to be_a Fixnum
  end

  it 'should not reuse IDs' do
    expect(backlog.next_id).to eq (backlog.next_id - 1)
  end

  it 'should have a list of tasks waiting to be done' do
    expect(backlog.todo).to be_an Array
  end

  it 'should throw a ParamContractError if passed a Hash with Symbol keys' do
    task = { foo: 'bar' }
    expect { backlog.add task }.to raise_error(ParamContractError)
  end

  it 'should return the ID of a newly added task' do
    task = { 'foo' => 'bar' }
    expect(backlog.add(task)).to be_a Fixnum
  end

  it 'should allow Symbol keys with add! method' do
    task = { foo: 'bar' }
    expect(backlog.add!(task)).to be_a Fixnum
  end

  it 'should add new tasks to the list of tasks waiting to be done' do
    task = { 'foo' => 'bar' }
    id = backlog.add(task)
    expect(backlog.todo).to include(id)
  end

  it 'should allow a task to be claimed' do
    expect(backlog.claim).to be_a Fixnum
  end

  it 'should track the claim separately from the queue it is in' do
    id = backlog.claim
    expect(backlog.claimed?(id)).to be true
  end

  it 'should allow claims to expire' do
    id = backlog.claim(duration: 1)
    sleep 1.1
    expect(backlog.claimed?(id)).to be false
  end

  it 'should block if there are no pending tasks' do
    redis.del "#{backlog.queue}:todo"
    expect do
      Timeout.timeout(0.1) do
        backlog.claim
      end
    end.to raise_error(Timeout::Error)
  end

  it 'should report if a task is claimed' do
    id = backlog.claim
    expect(backlog.claimed?(id)).to be true
    expect(backlog.claimed?(0)).to be false
  end

  it 'should have a list of tasks being worked on' do
    id = backlog.claim
    expect(backlog.doing).to include(id)
  end

  it 'should allow indicating completion of a task only once' do
    expect(backlog.complete(1)).to be true
    expect(backlog.complete(1)).to be false
  end

  it 'should check if a task is completed' do
    expect(backlog.completed?(2)).to be false
    backlog.complete 2
    expect(backlog.completed?(2)).to be true
  end

  it 'should allow indicating a task should not be retried' do
    expect(backlog.unworkable(3)).to be true
    expect(backlog.unworkable(3)).to be false
  end

  it 'should check if a task is unworkable' do
    expect(backlog.unworkable?(4)).to be false
    backlog.unworkable 4
    expect(backlog.unworkable?(4)).to be true
  end

  it 'should consider a task that is completed or unworkable to be done' do
    expect(backlog.done?(0)).to be false
    backlog.complete(5)
    expect(backlog.done?(5)).to be true
    backlog.unworkable(6)
    expect(backlog.done?(6)).to be true
  end

  it 'should be able to release a task from being in progress' do
    id = backlog.claim
    expect(backlog.release(id)).to be true
    expect(backlog.release(id)).to be false
    expect(backlog.doing).to_not include(id)
  end

  it 'should be able to forcibly expire a claim' do
    expect(backlog.expire_claim(0)).to be false
    id = backlog.claim
    expect(backlog.expire_claim(id)).to be true
    expect(backlog.claimed?(id)).to be false
  end

  it 'should expire any active claims when a task is released' do
    id = backlog.claim
    expect(backlog.claimed?(id)).to be true
    backlog.release(id)
    expect(backlog.claimed?(id)).to be false
  end

  it 'should be able to requeue a task' do
    id = backlog.claim
    expect(backlog.requeue(id)).to be true
    expect(backlog.todo).to include(id)
    expect(backlog.doing).to_not include(id)
  end
end
