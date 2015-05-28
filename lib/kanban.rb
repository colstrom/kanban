require 'redis'
require_relative 'kanban/hash_safety'

module Kanban
  class Backlog
    using HashSafety

    attr_reader :namespace, :queue, :item

    def initialize(backend:, **options)
      @namespace = options.fetch :namespace, 'default'
      @queue = "#{@namespace}:#{options.fetch :queue, 'tasks'}"
      @item = "#{@namespace}:#{options.fetch :item, 'task'}"
      @backend = backend
    end

    def get(id)
      @backend.hgetall "#{@item}:#{id}"
    end

    def next_id
      @backend.incr "#{@queue}:id"
    end

    def todo
      @backend.lrange("#{@queue}:todo", 0, -1).map(&:to_i)
    end

    def add(task)
      fail TypeError if task.keys_contain_symbols?
      id = next_id
      @backend.hmset "#{@item}:#{id}", *task.to_a
      @backend.lpush "#{@queue}:todo", id
      id
    end

    def add!(task)
      safe = task.with_string_keys
      add(safe)
    end

    def claim
      id = @backend.brpoplpush("#{@queue}:todo", "#{@queue}:doing")
      @backend.set "#{@item}:#{id}:claimed", true
      id.to_i
    end
  end
end
