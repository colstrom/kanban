module Kanban
  class Backlog
    attr_reader :namespace, :queue

    def initialize(**options)
      @namespace = options.fetch :namespace, 'default'
      @queue = "#{@namespace}:#{options.fetch :queue, 'tasks'}"
    end
  end
end
