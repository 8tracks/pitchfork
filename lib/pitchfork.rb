require "pitchfork/version"

module Pitchfork
  class PitchforkError < ::StandardError; end
  class MissingBlock < PitchforkError; end
  class InvalidHook < PitchforkError; end

  HOOKS = [
    :start,       # In parent, before looping through collection
    :before_fork, # In parent, inside loop, before calling `fork`
    :parent_fork, # In parent, after fork
    :child_fork,  # In child, after fork
    :work_done,   # In parent, after child exits
    :complete     # In parent, after looping through the collection
  ]

  def self.work(collection, options = {}, &block)
    Handler.new(collection, options).work(&block)
  end

  class Handler
    attr_accessor :collection

    def initialize(collection, config = {})
      @collection = collection
      @config = {:forks => 2, :name => "pitchfork"}.merge(config)
      @hooks = {}
      @children = {}
      @status = :work
      @master_pid = Process.pid
    end

    def work
      puts "Current pid is: #{@master_pid}"
      register_signals

      procline "Spawning workers ..."
      run_hook :start

      collection.each do |data|
        break unless work?

        run_hook :before_fork

        if @child = fork
          run_hook :parent_fork
          @children[@child] = true
        else
          procline "worker"
          run_hook :child_fork
          yield data
          exit
        end

        # Stop forking and wait for a child if we've reached the limit
        if @children.size >= @config[:forks]
          procline "Waiting for workers to finish ..."
          pid = Process.wait
          run_hook :work_done, $?.exitstatus == 0, $?.exitstatus
          @children.delete(pid)
        end

        if pause?
          loop do
            break unless pause?
            sleep 3
          end
        end
      end

      remaining = Process.waitall
      remaining.each do |pid,status|
        run_hook :work_done, status.exitstatus == 0, status.exitstatus
      end

      run_hook :complete
      collection
    end

    def on(type, hook)
      raise InvalidHook.new(<<-ERRMSG) unless HOOKS.include?(type)
        Pitchfork hook ':#{type}' does not exist.
        Valid hooks are: #{HOOKS.collect {|c| ":#{c}"}.join(", ")}
      ERRMSG

      @hooks[type] = hook
    end

    def work?
      @status == :work
    end

    def pause?
      @status == :pause
    end

    def quit?
      @status == :quit
    end

    def register_signals
      trap('TERM')  { shutdown! }
      trap('INT')   { shutdown! }
      trap('QUIT')  { shutdown }
      trap('USR2')  { pause! }
      trap('CONT')  { restart! }
    end

    def shutdown
      procline "Shutting down ..."
      @status = :quit
    end

    def shutdown!
      shutdown

      @children.keys.each do |pid|
        if system("ps -p #{pid}")
          Process.kill("KILL", pid) rescue nil
        end
      end
    end

    def pause!
      procline "Paused processing"
      @status = :pause
    end

    def restart!
      procline "Restarting ..."
      @status = :work
    end

    def master?
      Process.pid == @master_pid
    end

    def child?
      !master?
    end

    def procline(msg)
      line = "#{@config[:name]}: "
      line << "[#{@children.size}] " if master?
      line << msg
      $0 = line
    end

    def run_hook(type, *args)
      if hook = @hooks[type]
        if type == :work_done
          hook.call(*args)
        else
          hook.call
        end
      end
    end
  end
end

