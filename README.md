# kanban
Because your code totally needed an Agile workflow.

Description
===========
Kanban provides tools to model task flow in distributed apps.

Create a Backlog
----------------
```ruby
require 'redis'
require 'kanban'

backlog = Kanban::Backlog.new backend: Redis.new
```

Add some tasks to your shiny new Backlog
----------------------------------------
```ruby
task = { 'foo' => 'bar' }
5.times { backlog.add task }
```

(Elsewhere) Stake a claim on a task from the backlog
----------------------------------------------------
```ruby
task_id = backlog.claim  # Will block until there is a task, if the backlog is empty or all tasks are being worked.
details = backlog.get task_id
```

Mark a task as complete (or unworkable)
---------------------------------------
```ruby
backlog.complete task_id
# or backlog.unworkable task_id
backlog.done? task_id  # => true
```

Claims expire after awhile (default 3 seconds), and become eligible to be worked by something else.
