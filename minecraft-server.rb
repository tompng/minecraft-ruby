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

  def summon name, pos
    call "summon #{name} #{pos[:x]} #{pos[:y]} #{pos[:z]}", response: false
  end

  def test name, pos, r
    result = call("xp 0 @p[name=#{name},x=#{pos[:x].round},y=#{pos[:y].round},z=#{pos[:z].round},r=#{r.ceil}]")
    !!result.match(/^Given 0 experience to/)
  end

  def find2 name, pos
    r=4
    until test name, pos, r
      r*=2
      return nil if r>=1024
    end
    x,y,z=pos[:x],pos[:y],pos[:z]
    5.times{|i|
      p [:t,i,r]
      r2 = r/2
      p2=[-1,1].product([-1,1]).product([-1,1]).map(&:flatten).map{|dx,dy,dz|
        [x+dx*r/2,y+dy*r/2,z+dz*r/2]
      }.find{|x2,y2,z2|
        test name, {x:x2,y:y2,z:z2}, r2
      }
      break unless p2
      r=r2
      x,y,z=p2
    }
    {x:x,y:y,z:z}
  end


  def stop
    call 'stop', response: false
  end

end


minecraft = Minecraft::CommandExecutor.new command
before do
  next unless request.content_type == 'application/json'
  body = HashWithIndifferentAccess.new JSON.parse request.body.read
  define_singleton_method(:body){body}
end

get '/find/:name' do
  minecraft.find(params[:name]).to_json
end

post '/move/:name' do
  minecraft.move(params[:name], body[:position])
end

post '/setblock' do
  body[:blocks].each{|block|
    minecraft.setblock(block[:name], block[:position])
  }
  nil
end

post '/summon' do
  minecraft.summon(body[:name], body[:position])
end

post '/call' do
  minecraft.call(body[:command])
end
