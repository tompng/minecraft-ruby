require 'net/http'
require 'json'
require_relative 'minecraft/block'
module Minecraft
  class Client
    def initialize host
      @host = host
    end
    def get path
      Net::HTTP.get URI.parse("http://#{@host}#{path}")
    end
    def post path, params
      p params.to_json
      http = Net::HTTP.new *@host.split(':')
      http.post(path, params.to_json, {'Content-Type' => 'application/json'}).body
    end

    #setblock 'minecraft:glass', x:1, y:1, z:1
    def setblock *args
      if args.size == 1
        setblocks [args.first]
      else
        setblocks [args]
      end
    end

    def conv_position pos
      case pos
      when Array
        {x: pos[0], y: pos[1], z: pos[2]}
      when Hash
        {x: pos[:x], y: pos[:y], z: pos[:z]}
      end
    end

    def setblocks blocks
      post '/setblocks', blocks: blocks.map{|args|
        if Hash === args
          args = [args[:name] || args[:block], args[:position], args].compact
        end
        block = args.first
        options = args.last if Hash === args.last
        p options
        data = {
          name: block.to_s,
          position: conv_position(args[1]),
          if: options && BlockType[options[:if]],
          unless: options && BlockType[options[:unless]]
        }
        data.delete :if if data[:if].nil?
        data.delete :unless if data[:unless].nil?
        data
      }
    end

    def getblock *pos
      if pos.size==1
        getblocks([pos.first]).first
      else
        getblocks([pos]).first
      end
    end

    def getblocks positions
      begin
        blocks = JSON.parse post('/getblocks', positions: positions.map{|pos|conv_position(pos)})
        blocks.map{|name|
          Minecraft::BlockType.new name if name
        }
      rescue => e
        []
      end
    end

    #find name: 'tompng' #=> {x: 123.456, y: 62, z: 9.876}
    def find name
      begin
      res = get "/find/#{name}"
      pos = JSON.parse(res)
      {x: pos['x'], y: pos['y'], z: pos['z']} if pos
      rescue
      end
    end


    #move 'tompng', x: 1, y: 62, z: 3
    #move 'tompng', dx: 0, dy: 1, dz: 0
    def move name, pos
      post "/move/#{name}", position: pos
    end

    #summon 'Zombie', x:1, y:100, z:2
    def summon name, pos
      post '/summon', name: name, position: pos
    end

    def call command
      post '/call', command: command
    end

  end
end

require 'pry'
m = Minecraft::Client.new '192.168.1.3:4567'
binding.pry


# loop{
# begin
# pos = m.find(:tompng)
# m.setblocks (-1..1).to_a.product((-1..1).to_a).map{|x,z|
#   {
#     name: Minecraft::Block::Leaves,
#     position: {x: pos[:x]+x, y: [pos[:y]-1, 70].min, z: pos[:z]+z}
#   }
# }
# rescue => e
# sleep 1
# end
# sleep 0.25

# }

module Minecraft
  module Block
    block_types = %w(air stone grass dirt cobblestone planks sapling bedrock flowing_water water flowing_lava lava sand gravel gold_ore iron_ore coal_ore log leaves sponge glass lapis_ore lapis_block dispenser sandstone noteblock bed golden_rail detector_rail sticky_piston web tallgrass deadbush piston piston_head wool piston_extension yellow_flower red_flower brown_mushroom red_mushroom gold_block iron_block double_stone_slab stone_slab brick_block tnt bookshelf mossy_cobblestone obsidian torch fire mob_spawner oak_stairs chest redstone_wire diamond_ore diamond_block crafting_table wheat farmland furnace lit_furnace standing_sign wooden_door ladder rail stone_stairs wall_sign lever stone_pressure_plate iron_door wooden_pressure_plate redstone_ore lit_redstone_ore unlit_redstone_torch redstone_torch stone_button snow_layer ice snow cactus clay reeds jukebox fence pumpkin netherrack soul_sand glowstone portal lit_pumpkin cake unpowered_repeater powered_repeater stained_glass trapdoor monster_egg stonebrick brown_mushroom_block red_mushroom_block iron_bars glass_pane melon_block pumpkin_stem melon_stem vine fence_gate brick_stairs stone_brick_stairs mycelium waterlily nether_brick nether_brick_fence nether_brick_stairs nether_wart enchanting_table brewing_stand cauldron end_portal end_portal_frame end_stone dragon_egg redstone_lamp lit_redstone_lamp double_wooden_slab wooden_slab cocoa sandstone_stairs emerald_ore ender_chest tripwire_hook tripwire emerald_block spruce_stairs birch_stairs jungle_stairs command_block beacon cobblestone_wall flower_pot carrots potatoes wooden_button skull anvil trapped_chest light_weighted_pressure_plate heavy_weighted_pressure_plate unpowered_comparator powered_comparator daylight_detector redstone_block quartz_ore hopper quartz_block quartz_stairs activator_rail dropper stained_hardened_clay stained_glass_pane leaves2 log2 acacia_stairs dark_oak_stairs hay_block carpet hardened_clay coal_block packed_ice double_plant)
    block_types.each{|name|
      const_set name.split('_').map(&:capitalize).join, "minecraft:#{name}"
    }
  end
end

names = Minecraft::Block.constants.map{|name|Minecraft::Block.const_get(name)}
center = {x:180,y:224,z:260}
m.setblocks names.each_with_index.map{|name,i|
  {name: 'minecraft:dirt',
  position: {x: center[:x],y:center[:y],z:center[:z]+i}}
}

m.setblocks names.each_with_index.map{|name,i|
{name: name,
  position: {x: center[:x],y:center[:y]+1,z:center[:z]+i}}
}

out = m.getblocks names.each_with_index.map{|name,i|{x: center[:x],y:center[:y]+1,z:center[:z]+i}}

JSON.parse post('/getblocks', positions: names.each_with_index.map{|name,i|{x: center[:x],y:center[:y]+1,z:center[:z]+i}}.take(10))

Hash[names.map(&:name).zip(out.map(&:name))]
hash={}
outs.zip(names).each{|out,name|
  hash[out] ||= []
  hash[out] << name
}
