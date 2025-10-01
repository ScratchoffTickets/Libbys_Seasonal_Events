include("autorun/server/spellbooks/spellbooks_core.lua")
include("autorun/server/spellbooks/spellbooks_net.lua")
include("autorun/server/spellbooks/spellbooks_hooks.lua")
include("autorun/server/spellbooks/spellbooks_cmd.lua")

//ffnnh5ribnj k54k
function CreateSpellbook(pos)
    return SPELLBOOKS.Spawn(pos)
end
