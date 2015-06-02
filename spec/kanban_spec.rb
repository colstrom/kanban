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

  describe '#next_id' do
    describe 'should return incrementing values' do
      let!(:last_id) { backlog.next_id }
      subject { backlog.next_id }
      it { is_expected.to be > last_id }
    end
  end

  describe '#todo' do
    context 'when there are no tasks pending' do
      before { redis.del "#{backlog.queue}:todo" }
      subject { backlog.todo }
      it { is_expected.to be_empty }
    end

    context 'when there are tasks pending' do
      let(:task) { ({ 'test' => 'data' }) }
      let!(:id) { backlog.add task }
      subject { backlog.todo }
      it { is_expected.to_not be_empty }
      it { is_expected.to include id }
    end
  end

  describe '#add' do
    context 'when task is a hash with symbol keys' do
      let(:task) { ({ foo: 'bar' }) }
      it 'should raise a ParamContractError' do
        expect { backlog.add task }.to raise_error(ParamContractError)
      end
    end

    context 'when task is a hash with string keys' do
      let(:task) { ({ 'test' => 'data' }) }
      let!(:id) { backlog.next_id + 1}
      subject { backlog.add task }
      it { is_expected.to eq id }
    end
  end

  describe '#add!' do
    context 'when task is a hash with symbol keys' do
      let(:task) { ({ test: 'data' }) }
      let!(:id) { backlog.next_id + 1 }
      subject { backlog.add! task }
      it { is_expected.to eq id }
    end
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
