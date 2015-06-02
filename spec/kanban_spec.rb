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

    context 'when a task is requeued' do
      let(:id) { backlog.claim }
      before { backlog.requeue id }
      subject { backlog.todo }
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

  describe '#claimed?' do
    context 'when a claim does not exist' do
      subject { backlog.claimed? 0 }
      it { is_expected.to be false }
    end

    context 'when a claim exists' do
      let(:id) { backlog.claim }
      subject { backlog.claimed? id }
      it { is_expected.to be true }
    end

    context 'when a claim has expired' do
      let!(:id) { backlog.claim duration: 1 }
      before { sleep 1.1 }
      subject { backlog.claimed? id }
      it { is_expected.to be false }
    end

    context 'when a claim has been forcibly expired' do
      let(:id) { backlog.claim }
      before { backlog.expire_claim id }
      subject { backlog.claimed? id }
      it { is_expected.to be false }
    end

    context 'when a task has been released' do
      let(:id) { backlog.claim }
      before { backlog.release id }
      subject { backlog.claimed? id }
      it { is_expected.to be false }
    end
  end

  describe '#claim' do
    context 'when there are no pending tasks' do
      before { redis.del "#{backlog.queue}:todo" }
      it 'should block' do
        expect do
          Timeout.timeout(0.1) do
            backlog.claim
          end
        end.to raise_error(Timeout::Error)
      end
    end

    context 'when there are pending tasks' do
      before { backlog.add ({ 'test' => 'data' }) }
      subject { backlog.claim }
      it { is_expected.to be_a Fixnum }
    end
  end

  describe '#doing' do
    let!(:id) { backlog.claim }
    subject { backlog.doing }
    it { is_expected.to include id }

    context 'when a task is released' do
      before { backlog.release id }
      subject { backlog.doing }
      it { is_expected.to_not include id }
    end

    context 'when a task is requeued' do
      before { backlog.requeue id }
      subject { backlog.doing }
      it { is_expected.to_not include id }
    end
  end

  describe '#complete' do
    context 'when task has not been marked complete' do
      subject { backlog.complete 1 }
      it { is_expected.to be true }
    end

    context 'when task has been marked complete' do
      before { backlog.complete 1 }
      subject { backlog.complete 1 }
      it { is_expected.to be false }
    end
  end

  describe '#completed?' do
    context 'when task has not been marked complete' do
      subject { backlog.completed? 2 }
      it { is_expected.to be false }
    end

    context 'when task has been marked complete' do
      before { backlog.complete 3 }
      subject { backlog.completed? 3 }
      it { is_expected.to be true }
    end
  end

  describe '#unworkable' do
    context 'when task has not been marked unworkable' do
      subject { backlog.unworkable 1 }
      it { is_expected.to be true }
    end

    context 'when task has been marked unworkable' do
      before { backlog.unworkable 1 }
      subject { backlog.unworkable 1 }
      it { is_expected.to be false }
    end
  end

  describe '#unworkable?' do
    context 'when task has not been marked unworkable' do
      subject { backlog.unworkable? 2 }
      it { is_expected.to be false }
    end

    context 'when task has been marked unworkable' do
      before { backlog.unworkable 3 }
      subject { backlog.unworkable? 3 }
      it { is_expected.to be true }
    end
  end

  describe '#done?' do
    context 'when task has not been marked either complete or unworkable' do
      subject { backlog.done? 0 }
      it { is_expected.to be false }
    end

    context 'when task has been marked complete' do
      before { backlog.complete 5 }
      subject { backlog.done? 5 }
      it { is_expected.to be true }
    end

    context 'when task has been marked unworkable' do
      before { backlog.unworkable 6 }
      subject { backlog.done? 6 }
      it { is_expected.to be true }
    end
  end

  describe '#release' do
    context 'when task is claimed' do
      let(:id) { backlog.claim }
      subject { backlog.release id }
      it { is_expected.to be true }
    end

    context 'when task was not claimed' do
      subject { backlog.release 0 }
      it { is_expected.to be false }
    end
  end

  describe '#expire_claim' do
    context 'when task was not claimed' do
      subject { backlog.expire_claim 0 }
      it { is_expected.to be false }
    end

    context 'when task was claimed' do
      let(:id) { backlog.claim }
      subject { backlog.expire_claim id }
      it { is_expected.to be true }
    end
  end

  describe '#groom' do
    context 'when a task is claimed' do
      let(:id) { backlog.claim }

      context 'and the claim has expired' do
        before { backlog.expire_claim id }
        subject { backlog.groom }
        it { is_expected.to include id }

        context 'when #groom is called' do
          before { backlog.groom }

          describe '#todo' do
            subject { backlog.todo }
            it { is_expected.to include id }
          end

          describe '#doing' do
            subject { backlog.doing }
            it { is_expected.to_not include id }
          end
        end
      end

      context 'and the task is done' do
        before { backlog.complete id }

        context 'and the claim has expired' do
          before { backlog.expire_claim id }

          subject { backlog.groom }
          it { is_expected.to include id }

          context 'when #groom is called' do
            before { backlog.groom }
            describe '#todo' do
              subject { backlog.todo }
              it { is_expected.to_not include id }
            end

            describe '#doing' do
              subject { backlog.doing }
              it { is_expected.to_not include id }
            end
          end
        end

        context 'and the claim has not expired' do
          subject { backlog.groom }
          it { is_expected.to_not include id }

          context 'when #groom is called' do
            before { backlog.groom }

            describe '#todo' do
              subject { backlog.todo }
              it { is_expected.to_not include id }
            end

            describe '#doing' do
              subject { backlog.doing }
              it { is_expected.to include id }
            end
          end
        end
      end
    end
  end
end
