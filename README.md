minecraft-ruby
==============

minecraftをrubyでいじってあそぼ

## 1. サーバ設定
- rconオプションを有効化してminecraft_server.***.jarを起動する
```
#server.propertiesにこの2行を追加
enable-rcon=true
rcon.password=hoge
```

## 2. ruby minecraft-client.rb で繋いであそぶ


``` ruby
pos = find :tompng
#=> {:x=>180.03, :y=>30.0, :z=>274.05}

summon Mob::Zombie, pos
#=> "Object successfully summoned"

getblock x:180, y:20, z:274
#=> Minecraft::BlockType::Stone

setblock Block::Glass, pos
#=> "Block placed"

getblocks positions
#=> [BlockType::Stone, ....]

#other examples
setblocks Block::DiamondBlock, positions, if: BlockType::Air

setblocks Block::DiamondBlock, positions, unless: [BlockType::Air, BlockType::Water]

setblocks Block::DiamondBlock, positions, if: ->(type){
  type && type.name =~ /Stone|Block/
}


```
