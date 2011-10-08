require "pitchfork/version"

module Pitchfork

  def pitch(collection, options = {}, &block)
    Handler.new(collection, options).pitch(&block)
  end

  class Handler
    attr_accessor :collection

    def initialize(collection, config = {})
      @collection = collection
      @config = config
      @config[:forks] ||= 2 # At most 2 children
      @children = 0
    end

    def pitch(&block)
      collection.each do |data|
        if @child = fork
          @children += 1
        else
          block.call(data) # Do the work!
          exit
        end

        # Stop forking and wait for a child if we've reached the limit
        if @children >= @config[:forks]
          Process.wait
          @children -= 1
        end
      end

      Process.waitall
      collection
    end
  end
end

