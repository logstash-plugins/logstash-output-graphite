module Mocks
  class Server

    def initialize
      @queue = Array.new
    end

    def size
      @queue.length
    end

    def pop
      @queue.pop
    end

    def stop
    end

    def empty?
      @queue.empty?
    end

    def puts(data)
      data.split("\n").each do |line|
        @queue << "#{line}\n"
      end
    end
  end
end
