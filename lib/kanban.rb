require 'contracts'
require 'redis'
require_relative 'kanban/hash_safety'

module Kanban
  class Backlog
    using HashSafety
    include ::Contracts::Core
    include ::Contracts::Builtin

    attr_reader :namespace, :queue, :item

    def initialize(backend:, **options)
      @namespace = options.fetch :namespace, 'default'
      @queue = "#{@namespace}:#{options.fetch :queue, 'tasks'}"
      @item = "#{@namespace}:#{options.fetch :item, 'task'}"
      @backend = backend
    end

    Contract Num => Hash
    def get(id)
      @backend.hgetall "#{@item}:#{id}"
    end

    Contract None => Num
    def next_id
      @backend.incr "#{@queue}:id"
    end

    Contract None => ArrayOf[Num]
    def todo
      @backend.lrange("#{@queue}:todo", 0, -1).map(&:to_i)
    end

    Contract HashOf[String, Any] => Num
    def add(task)
      id = next_id
      @backend.hmset "#{@item}:#{id}", *task.to_a
      @backend.lpush "#{@queue}:todo", id
      id
    end

    Contract Hash => Num
    def add!(task)
      safe = task.with_string_keys
      add(safe)
    end

    Contract Maybe[({ duration: Num })] => Num
    def claim(duration: 3)
      id = @backend.brpoplpush("#{@queue}:todo", "#{@queue}:doing")
      @backend.set "#{@item}:#{id}:claimed", true, ex: duration
      id.to_i
    end

    Contract Num => Bool
    def claimed?(id)
      @backend.exists "#{@item}:#{id}:claimed"
    end

    Contract None => ArrayOf[Num]
    def doing
      @backend.lrange("#{@queue}:doing", 0, -1).map(&:to_i)
    end

    Contract Num => Bool
    def complete(id)
      @backend.setbit("#{@queue}:completed", id, 1).zero?
    end

    Contract Num => Bool
    def completed?(id)
      @backend.getbit("#{@queue}:completed", id) == 1
    end

    Contract Num => Bool
    def unworkable(id)
      @backend.setbit("#{@queue}:unworkable", id, 1).zero?
    end

    Contract Num => Bool
    def unworkable?(id)
      @backend.getbit("#{@queue}:unworkable", id) == 1
    end

    Contract Num => Bool
    def done?(id)
      completed?(id) || unworkable?(id)
    end

    Contract Num => Bool
    def release(id)
      expire_claim id
      @backend.lrem("#{@queue}:doing", 0, id) > 0
    end

    Contract Num => Bool
    def expire_claim(id)
      @backend.expire "#{@item}:#{id}:claimed", 0
    end

    Contract Num => Bool
    def requeue(id)
      release id
      @backend.lpush("#{@queue}:todo", id) > 0
    end

    Contract None => ArrayOf[Num]
    def groom
      doing.map do |id|
        next if claimed? id
        if done? id
          id if release id
        else
          id if requeue id
        end
      end.compact
    end
  end
end
