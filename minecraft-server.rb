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

  def wait_for patterns = nil
    timeout(0.1){
      return @queue.deq if patterns.nil?
      loop do
        response = @queue.deq
        patterns.each{|pattern, block|
          match = pattern.match response
          if match

            return block.is_a?(Proc) ? block.call(match) : block
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
      wait_for(
        /^Teleported .+ to (?<x>[\d.-]+),(?<y>[\d.-]+),(?<z>[\d.-]+)/ => ->(match){
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
    conds = blocks.select{|block|block[:if]||block[:unless]}
    unless conds.empty?
      positions = conds.map{|block|block[:position]}
      blockinfo = Hash[positions.zip(getblocks positions)]
    end
    commands = blocks.map{|block|
      name, pos, = block[:name], block[:position]
      next if block[:if] && blockinfo[pos] != block[:if]
      next if block[:unless] && blockinfo[pos] == block[:unless]
      "setblock #{pos[:x].floor} #{pos[:y].floor} #{pos[:z].floor} #{name}"
    }
    call commands.compact
  end

  def getblocks positions
    positions = positions.map{|pos|
      {
        x: pos[:x].floor,
        y: pos[:y].floor,
        z: pos[:z].floor
      }
    }
    commands = positions.map{|pos|
      "testforblock #{pos[:x]} #{pos[:y]} #{pos[:z]} minecraft:air"
    }
    pos_blocks = {}
    mpos = ->(m){{x: m[:x].to_i, y: m[:y].to_i, z: m[:z].to_i}}
    call commands do
      commands.size.times{
        wait_for(
          /Cannot test for block outside of the world/ => nil,
          /^Successfully found the block at (?<x>-?\d+),(?<y>-?\d+),(?<z>-?\d+)/ => ->(match){
            pos_blocks[mpos[match]] = 'Air'
          },
          /^The block at (?<x>-?\d+),(?<y>-?\d+),(?<z>-?\d+) is (?<name>.+) \(expected/ => ->(match){
            /^minecraft:(?<name>.*)$/ =~ match[:name] ||
            /^tile\.(?<name>.*)\.name$/ =~ match[:name] ||
            name = match[:name]
            pos_blocks[mpos[match]] = name.scan(/[a-zA-Z0-9]+/).map(&:capitalize).join
          }
        )
      }
    end
    positions.map{|pos|pos_blocks[pos]}
  end

  def list
    call 'list' do
      num = wait_for(/There are (?<num>\d)\/\d+ players online:/ => ->(match){match[:num]})
      num.to_i.times.map{wait_for} if num
    end
  end

  def summon name, pos
    call "summon #{name} #{pos[:x]} #{pos[:y]} #{pos[:z]}"
  end

end


minecraft = Minecraft::CommandExecutor.new command
Thread.new{minecraft.instance_eval{binding.pry}}

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
  minecraft.setblocks(params[:blocks])
  nil
end

post '/getblocks' do
  a=minecraft.getblocks(params[:positions]).to_json
end

post '/summon' do
  minecraft.summon(params[:name], params[:position])
end

post '/call' do
  minecraft.call(params[:command]).to_s
end
