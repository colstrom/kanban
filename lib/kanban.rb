require 'redis'

module Kanban
  class Backlog
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
  end
end
