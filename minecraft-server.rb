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

module Minecraft
  Events = []
  Events << (/.+ joined the game$/)
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
          next if Minecraft::Events.any?{|pattern|pattern =~ response}
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

  def call command, option={}
    p command
    @mutex.synchronize do
      @queue.clear
      @io.puts command
      unless option.key?(:response) && !option[:response]
        return timeout(0.1){@queue.pop}
      end
    end
  rescue
  end

  def find name
    if /^Teleported .+ to (?<x>[\d.-]+),(?<y>[\d.-]+),(?<z>[\d.-]+)/ =~ call("tp #{name} ~0 ~0 ~0")
      {x: x.to_f, y: y.to_f, z: z.to_f}
    end
  rescue
  end

  def move name, pos
    x = pos[:x] || (pos[:dx] ? "~#{pos[:dx]}" : '~0')
    y = pos[:y] || (pos[:dy] ? "~#{pos[:dy]}" : '~0')
    z = pos[:z] || (pos[:dz] ? "~#{pos[:dz]}" : '~0')
    call "tp #{name} #{x} #{y} #{z}", response: false
  end

  def setblock name, pos
    call "setblock #{pos[:x].floor} #{pos[:y].floor} #{pos[:z].floor} #{name}", response: false
  end

  def getblock pos
    response = call "testforblock #{pos[:x].floor} #{pos[:y].floor} #{pos[:z].floor} minecraft:air"
    if /^Successfully/ =~ response
      'Air'
    elsif /^The block at .+ is (?<name>[^ ]+)/ =~ response
      name
    end
  end

  def summon name, pos
    call "summon #{name} #{pos[:x]} #{pos[:y]} #{pos[:z]}", response: false
  end

  def test name, pos, r
    result = call("xp 0 @p[name=#{name},x=#{pos[:x].round},y=#{pos[:y].round},z=#{pos[:z].round},r=#{r.ceil}]")
    !!result.match(/^Given 0 experience to/)
  end

  def stop
    call 'stop', response: false
  end

end


minecraft = Minecraft::CommandExecutor.new command
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
