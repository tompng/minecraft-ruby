require 'net/http'
require 'json'
module Minecraft
  class Client
    def initialize host
      @host = host
    end
    def get path
      Net::HTTP.get URI.parse("http://#{@host}#{path}")
    end
    def post path, params
      http = Net::HTTP.new *@host.split(':')
      http.post path, params.to_json, {'Content-Type' => 'application/json'}
    end

    #setblock 'minecraft:glass', x:1, y:1, z:1
    def setblock name, pos
      setblocks [name: name, position: pos]
    end

    def setblocks blocks
      post '/setblock', blocks: blocks
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

  end
end

module Minecraft
  module Block
    block_types = %w(air stone grass dirt cobblestone planks sapling bedrock flowing_water water flowing_lava lava sand gravel gold_ore iron_ore coal_ore log leaves sponge glass lapis_ore lapis_block dispenser sandstone noteblock bed golden_rail detector_rail sticky_piston web tallgrass deadbush piston piston_head wool piston_extension yellow_flower red_flower brown_mushroom red_mushroom gold_block iron_block double_stone_slab stone_slab brick_block tnt bookshelf mossy_cobblestone obsidian torch fire mob_spawner oak_stairs chest redstone_wire diamond_ore diamond_block crafting_table wheat farmland furnace lit_furnace standing_sign wooden_door ladder rail stone_stairs wall_sign lever stone_pressure_plate iron_door wooden_pressure_plate redstone_ore lit_redstone_ore unlit_redstone_torch redstone_torch stone_button snow_layer ice snow cactus clay reeds jukebox fence pumpkin netherrack soul_sand glowstone portal lit_pumpkin cake unpowered_repeater powered_repeater stained_glass trapdoor monster_egg stonebrick brown_mushroom_block red_mushroom_block iron_bars glass_pane melon_block pumpkin_stem melon_stem vine fence_gate brick_stairs stone_brick_stairs mycelium waterlily nether_brick nether_brick_fence nether_brick_stairs nether_wart enchanting_table brewing_stand cauldron end_portal end_portal_frame end_stone dragon_egg redstone_lamp lit_redstone_lamp double_wooden_slab wooden_slab cocoa sandstone_stairs emerald_ore ender_chest tripwire_hook tripwire emerald_block spruce_stairs birch_stairs jungle_stairs command_block beacon cobblestone_wall flower_pot carrots potatoes wooden_button skull anvil trapped_chest light_weighted_pressure_plate heavy_weighted_pressure_plate unpowered_comparator powered_comparator daylight_detector redstone_block quartz_ore hopper quartz_block quartz_stairs activator_rail dropper stained_hardened_clay stained_glass_pane leaves2 log2 acacia_stairs dark_oak_stairs - - - - - hay_block carpet hardened_clay coal_block packed_ice double_plant)
    block_types.each{|name|
      next if name == '-'
      const_set name.split('_').map(&:capitalize).join, "minecraft:#{name}"
    }
  end
end

require 'pry'
m = Minecraft::Client.new 'localhost:4567'
binding.pry
