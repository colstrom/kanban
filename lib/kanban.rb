module Kanban
  class Backlog
    attr_reader :namespace, :queue, :item

    def initialize(**options)
      @namespace = options.fetch :namespace, 'default'
      @queue = "#{@namespace}:#{options.fetch :queue, 'tasks'}"
      @item = "#{@namespace}:#{options.fetch :item, 'task'}"
    end
  end
end
