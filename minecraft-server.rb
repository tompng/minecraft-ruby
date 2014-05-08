require 'pry'
require 'timeout'
require 'json'
require 'sinatra'
require 'active_support/core_ext/hash/indifferent_access'

command = 'cd bin;java -Xmx1024M -Xms1024M -jar minecraft_server.1.7.9.jar nogui'

module Minecraft
  refine Hash do
    def to_minecraft
      '[' + map{|key, value|"#{key}=#{value}"}.join(',') + ']'
    end
  end
end


class Minecraft::CommandExecutor
  def initialize command
    @queue = Queue.new
    @mutex = Mutex.new
    @io = IO.popen command, "r+"
    Thread.new{
      begin
        @io.each_line do |line|
          p line
          next unless /^\[..:..:..\] \[Server thread\/INFO\]: (?<response>.+)$/ =~ line.chomp
          notify response
        end
        exit
      rescue => e
        p e
      end
    }
  end

  def notify response
    @queue << response
  end

  def wait_for patterns
    timeout(0.1){
      loop do
        response = @queue.deq
        patterns.each{|pattern, block|
          match = pattern.match response
          if match
            return (block.call response, match if block)
          end
        }
      end
    }
  end

  def call commands, &block
    p commands
    @mutex.synchronize do
      @queue.clear
      @io.puts commands
      return block.call if block
    end
  rescue
  end

  def find name
    call("tp #{name} ~0 ~0 ~0"){
      pattern, result, match = wait_for(
        /^Teleported .+ to (?<x>[\d.-]+),(?<y>[\d.-]+),(?<z>[\d.-]+)/ => ->(text, match){
          {x: match[:x].to_f, y: match[:y].to_f, z: match[:z].to_f}  
        },
        /That player cannot be found/ => nil
      )
    }
  rescue
  end

  def move name, pos
    x = pos[:x] || (pos[:dx] ? "~#{pos[:dx]}" : '~0')
    y = pos[:y] || (pos[:dy] ? "~#{pos[:dy]}" : '~0')
    z = pos[:z] || (pos[:dz] ? "~#{pos[:dz]}" : '~0')
    call "tp #{name} #{x} #{y} #{z}"
  end

  def setblocks blocks
    conds = blocks.select{|block|block[:if]}
    unless conds.empty?
      positions = conds.map{|block|block[:position]}
      blockinfo = Hash[positions.zip(getblocks positions)]
    end
    commands = blocks.map{|block|
      name, pos, = block[:name], block[:position]
      next if block[:if] && blockinfo[pos] != block[:if]
      "setblock #{pos[:x].floor} #{pos[:y].floor} #{pos[:z].floor} #{name}"
    }
    call commands.compact
  end

  def getblocks positions
    commands = positions.map{|pos|
      "testforblock #{pos[:x].floor} #{pos[:y].floor} #{pos[:z].floor} minecraft:air"
    }
    call commands do
      positions.map{
        pattern, response, match = wait_for(
          /^Successfully/ => ->{'Air'},
          /^The block at .+ is (?<name>[^ ]+)/ => ->(text, match){
            match[:name]
          }
        )
      }
    end
  end

  def summon name, pos
    call "summon #{name} #{pos[:x]} #{pos[:y]} #{pos[:z]}", response: false
  end

end


minecraft = Minecraft::CommandExecutor.new command
minecraft.instance_eval{binding.pry}

before do
  return unless request.content_type == 'application/json'
  body = HashWithIndifferentAccess.new JSON.parse request.body.read
  body.each{|key, value|
    params[key] ||= value
  }
end

set :bind, '0.0.0.0'

get '/find/:name' do
  minecraft.find(params[:name]).to_json
end

post '/move/:name' do
  minecraft.move(params[:name], params[:position])
end

post '/setblocks' do
  params[:blocks].each{|block|
    minecraft.setblock(block[:name], block[:position])
  }
  nil
end

post '/getblocks' do
  params[:positions].map{|pos|
    minecraft.getblock pos
  }.to_json
end

post '/summon' do
  minecraft.summon(params[:name], params[:position])
end

post '/call' do
  minecraft.call(params[:command]).to_s
end
