require 'pry'
require 'socket'
require 'thread'
require_relative 'minecraft/block'
module Minecraft
  class RconClient
    attr_accessor :send_interval
    def initialize host, port
      @send_interval = 0.005
      @mutex = Mutex.new
      @cond = ConditionVariable.new
      @socket = TCPSocket.open(host,port)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      Thread.new{read}
    end

    def authorize password
      return true if authorized?
      packet = Packet.new password, true
      request_packets [packet], 1
      @authorized = !!packet.response
    end

    def call data
      p data
      return unless authorized?
      if data.is_a? Array
        return if data.empty?
        requests data
      else
        requests([data]).first
      end
    end

    def authorized?
      @authorized
    end

    private

    class Packet
      attr_accessor :response
      attr_reader :id, :type, :data
      def initialize data, login=false
        @id = rand(0x100000000)
        @data = data
        @type = login ? 3 : 2
      end
      def size
        4+4+@data.size+2
      end
      def to_byte
        [size,@id,@type,@data,''].pack('VVVa*a2')
      end
    end

    def read
      loop{
        size, id, type = @socket.read(12).unpack 'VVV'
        data = @socket.read(size - 8)[0...-2]
        notify id, data
      }
    rescue Exception => e
      p e
    end

    def notify id, data
      @mutex.synchronize do
        @cond.signal if id == -1
        packet = @waiting[id]
        return unless packet
        packet.response = data
        @waiting.delete id
        @cond.signal if @waiting.empty?
      end
    end

    def request_packets packets, timeout=nil
      @mutex.synchronize do
        @waiting = {}
        packets.each{|packet|
          @waiting[packet.id] = packet
          @socket.write packet.to_byte
          @socket.flush
          sleep send_interval
        }
        @cond.wait(@mutex,timeout)
      end
    end

    private

    def requests array
      packets = array.map{|cmd|Packet.new cmd}
      request_packets packets
      packets.map &:response
    end

  end


  module PointUtil
    def self.conv_position pos
      if Hash === pos
        [pos[:x], pos[:y], pos[:z]]
      else
        pos
      end
    end
  end


  class Client < RconClient
    def initialize host, port
      super host, port
    end


    def find name
      response = call("tp #{name} ~0 ~0 ~0")
      if /^Teleported .+ to (?<x>[\d.-]+),(?<y>[\d.-]+),(?<z>[\d.-]+)/ =~ response
        {x: x.to_f, y: y.to_f, z: z.to_f}
      end
    end

    def move name, pos
      x = pos[:x] || (pos[:dx] ? "~#{pos[:dx]}" : '~0')
      y = pos[:y] || (pos[:dy] ? "~#{pos[:dy]}" : '~0')
      z = pos[:z] || (pos[:dz] ? "~#{pos[:dz]}" : '~0')
      call "tp #{name} #{x} #{y} #{z}"
    end

    def list
      if /There are \d\/\d+ players online:(?<names>.*)/ =~ call('list')
        names.split(/, \n/)
      end
    end

    def summon name, pos
      x,y,z = PointUtil.conv_position(pos)
      call "summon #{name} #{x} #{y} #{z}"
    end

    def getblock position
      getblocks([position]).first
    end

    def getblocks positions
      responses = call positions.map{|pos|
        PointUtil.conv_position(pos)
      }.map{|x, y, z|
        "testforblock #{x.floor} #{y.floor} #{z.floor} minecraft:air"
      }
      responses.map{|response|
        if /^Successfully found the block/ =~ response
          Minecraft::BlockType.new 'Air'
        elsif /^The block at [-\d]+,[-\d]+,[-\d]+ is (?<name>.+) \(expected/ =~ response
          /^minecraft:(?<type>.*)$/ =~ name ||
          /^tile\.(?<type>.*)\.name$/ =~ name ||
          type = name
          Minecraft::BlockType.new type.scan(/[a-zA-Z0-9]+/).map(&:capitalize).join
        end
      }
    end

    def cond_proc arg
      case arg
      when Array
        array = arg.map{|type|Minecraft::BlockType[type]}
        ->(type){array.include? type}
      when Proc
        arg
      else
        obj = Minecraft::BlockType[arg]
        ->(type){type == obj}
      end
    end

    def setblock block, position, options={}
      setblocks(block, [position], options).first
    end

    def setblocks block, positions, options={}
      if options.key?(:if) || options.key?(:unless)
        types = getblocks positions
        if options.key? :if
          cond = cond_proc options[:if]
          positions = positions.zip(types).select{|pos, type|cond[type]}.map(&:first)
        end
        if options.key? :unless 
          cond = cond_proc options[:unless]
          positions = positions.zip(types).reject{|pos, type|cond[type]}.map(&:first)
        end
      end
      p positions
      call positions.map{|pos|
        x,y,z = PointUtil.conv_position(pos)
        "setblock #{x.floor} #{y.floor} #{z.floor} #{block}"
      }
    end

  end
end


include Minecraft
mc=Client.new 'localhost', 25575
mc.authorize 'hoge'
mc.instance_eval{binding.pry}
