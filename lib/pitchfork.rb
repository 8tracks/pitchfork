require "pitchfork/version"

module Pitchfork
  class PitchforkError < ::StandardError; end
  class MissingBlock < PitchforkError; end

  def self.work(collection, options = {}, &block)
    Handler.new(collection, options).work(&block)
  end

  class Handler
    attr_accessor :collection

    def initialize(collection, config = {})
      @collection = collection
      @config = {:forks => 2, :name => "pitchfork"}.merge(config)
      @callbacks = {}
      @children = {}
      @status = :work
      @master_pid = Process.pid
    end

    def work
      puts "Current pid is: #{@master_pid}"
      register_signals

      procline "Spawning workers ..."
      collection.each do |data|
        break unless work?

        run_callback :before_work

        if @child = fork
          @children[@child] = true
        else
          procline "worker"
          yield data
          exit
        end

        # Stop forking and wait for a child if we've reached the limit
        if @children.size >= @config[:forks]
          procline "Waiting for workers to finish ..."
          pid = Process.wait

          run_callback :after_work

          @children.delete(pid)
        end

        if pause?
          loop do
            break unless pause?
            sleep 3
          end
        end
      end

      Process.waitall
      collection
    end

    def before_work_callback=(cb)
      @callbacks[:before_work] = cb
    end

    def after_work_callback=(cb)
      @callbacks[:after_work] = cb
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

    def run_callback(type)
      if callback = @callbacks[type]
        callback.call($?.exitstatus == 0, $?.exitstatus)
      end
    end

  end
end

