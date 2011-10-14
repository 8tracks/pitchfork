require "pitchfork/version"

module Pitchfork
  class PitchforkError < ::StandardError; end
  class MissingBlock < PitchforkError; end

  def self.pitch(collection, options = {}, &block)
    Handler.new(collection, options).pitch(&block)
  end

  class Handler
    attr_accessor :collection

    def initialize(collection, config = {})
      @collection = collection
      @config = {:forks => 2, :name => "pitchfork"}.merge(config)
      @children = {}
      @status = :work
      @master_pid = Process.pid
    end

    def pitch(&block)
      puts "Current pid is: #{@master_pid}"
      register_signals

      procline "Spawning workers ..."
      collection.each do |data|
        break unless work?

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
      trap('STOP')  { pause! }
      trap('CONT')  { restart! }
    end

    def shutdown
      @status = :quit
      procline "Shutting down ..."
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
      puts "changing procline"
      @status = :pause
    end

    def restart!
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
  end
end

