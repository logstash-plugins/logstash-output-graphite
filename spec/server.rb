module Mocks
  class Server

    def initialize(port)
      @queue = Queue.new
      @port  = port
    end

    def start
      @server = TCPServer.new("127.0.0.1", @port)
      @queue.clear
      Thread.new do
        client = @server.accept
        while true
          line = client.readline
          @queue << line
        end
      end
      self
    end

    def size
      @queue.length
    end

    def pop
      @queue.pop
    end

    def stop
      @server.close
    end

    def empty?
      @queue.empty?
    end

  end
end
