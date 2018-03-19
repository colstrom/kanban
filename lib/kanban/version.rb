module Kanban
  VERSION = $LOADED_FEATURES
              .map { |f| f.match %r{/kanban-(?<version>[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+(\.pre)?)} }
              .compact
              .map { |gem| gem['version'] }
              .uniq
              .first
end
