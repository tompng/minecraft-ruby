require_relative 'const'
module Minecraft
  class BlockBase
    attr_accessor :name
    def initialize name
      self.name = name
    end
    def to_s
      name
    end
    def == obj
      self.class == obj.class && name == obj.name
    end
  end

  class Block < BlockBase
    def to_block_type
      type_name = Const::BlockInfo[name]
      BlockType.new type_name if type_name
    end
    Const::BlockInfo.keys.each{|name|
      const_set name.split('_').map(&:capitalize).join, Block.new("minecraft:#{name}")
    }
  end

  class BlockType < BlockBase
    def self.[] obj
      case obj
      when BlockType
        obj
      when Block
        obj.to_block_type
      when NilClass
        nil
      else
        Block.new(obj).to_block_type
      end
    end
    Const::BlockInfo.values.uniq.each{|name|
      const_set name, BlockType.new(name)
    }
  end

  module Mob
    [*Const::Monsters,*Const::Animals,*Const::Objects].each{|name|
      const_set name, name
    }
  end

end