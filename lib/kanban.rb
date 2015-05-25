module Kanban
  class Backlog
    attr_reader :namespace

    def initialize(**options)
      @namespace = options.fetch :namespace, 'default'
    end
  end
end
