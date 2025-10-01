local spellbooks = {}              // spawned prop_dynamic spellbooks (SPELLBOOKS)
local cachedSpells = {}            // [{Name, DisplayName}]
local playerLastSpells = {}        // [steamid] = last DisplayName
local playerSpells = {}            // [steamid] = {Name, DisplayName}


local COLLECTION_RANGE = 50
local SPELLBOOK_LIFETIME = 120
local EXPLOSION_DAMAGE = 30


SPELLBOOKS = SPELLBOOKS or {}


local function isBuildOrPill(ply)
    if ply:GetNWBool("BuildMode", false) then return true end
    if ply:GetNWBool("_Kyle_Buildmode", false) then return true end
    if pk_pills and pk_pills.getMappedEnt and pk_pills.getMappedEnt(ply) then return true end
    return false
end


local function EmitSpellSound(pos, soundPath)
    sound.Play(soundPath, pos, 100, 100, 1)
end

local function PlayPickupSound(ply)
    if not IsValid(ply) then return end
    ply:EmitSound("libbys/halloween/pumpkin_pickup.ogg", 85)
    ply:EmitSound("libbys/halloween/spell_tick.ogg", 45)
end

local function StopPickupSound(ply)
    if not IsValid(ply) then return end
    ply:StopSound("libbys/halloween/spell_tick.ogg")
end


local function CreateExplosion(ply)
    if not IsValid(ply) then return end
    local explosion = ents.Create("env_explosion")
    if not IsValid(explosion) then return end
    explosion:SetPos(ply:GetPos())
    explosion:SetOwner(ply)
    explosion:SetKeyValue("iMagnitude", tostring(EXPLOSION_DAMAGE))
    explosion:Spawn()
    explosion:Activate()
    explosion:Fire("Explode", "", 0)
end


local function LoadSpells()
    if #cachedSpells > 0 then return cachedSpells end
    local spellFiles = file.Find("spells/*.lua", "LUA")
    for _, spellFile in ipairs(spellFiles) do
        local spellPath = "spells/" .. spellFile
        if file.Exists(spellPath, "LUA") then
            local ok, spellData = pcall(include, spellPath)
            if ok and spellData and spellData.GetDisplayName then
                table.insert(cachedSpells, {
                    Name = string.StripExtension(spellFile),
                    DisplayName = spellData.GetDisplayName()
                })
            end
        end
    end
    return cachedSpells
end


local function SavePlayerSpell(ply, spell)
    playerSpells[ply:SteamID()] = { Name = spell.Name, DisplayName = spell.DisplayName }
end


local function ClearPlayerSpell(ply)
    playerSpells[ply:SteamID()] = nil
end


local function GetPlayerSpell(ply)
    return playerSpells[ply:SteamID()] or { Name = "", DisplayName = "" }
end


local function CreateSpellbookProp(pos)
    local spellbook = ents.Create("prop_dynamic")
    if not IsValid(spellbook) then return end
    spellbook:SetModel("models/props_halloween/hwn_spellbook_upright.mdl")
    spellbook:SetPos(pos)
    spellbook:SetSolid(SOLID_NONE)
    spellbook:SetTrigger(true)
    spellbook:SetMoveType(MOVETYPE_NONE)
    spellbook:Spawn()

    EmitSpellSound(pos, "libbys/halloween/spawn.ogg")
    local seq = spellbook:LookupSequence("idle")
    if seq and seq >= 0 then spellbook:ResetSequence(seq) end

    local tname = "SpellbookLifetime_" .. spellbook:EntIndex()
    timer.Create(tname, SPELLBOOK_LIFETIME, 1, function()
        if IsValid(spellbook) then spellbook:Remove() end
    end)
    spellbook:CallOnRemove("KillLifetime", function()
        if timer.Exists(tname) then timer.Remove(tname) end
    end)

    table.insert(spellbooks, spellbook)
    return spellbook
end


local function CleanupSpellbooks()
    for _, sb in ipairs(spellbooks) do
        if IsValid(sb) then sb:Remove() end
    end
    table.Empty(spellbooks)
end


// I guess we doin SPELLBOOKS now
function SPELLBOOKS.Spawn(pos)
    return CreateSpellbookProp(pos)
end


local function AssignSpell(ply, spell) // spell = {Name, DisplayName}
    if not IsValid(ply) then return end
    ply:SetNWString("ActiveSpell", spell.Name or "")
    ply:SetNWString("ActiveSpellDisplayName", spell.DisplayName or spell.Name or "")
    SavePlayerSpell(ply, spell)
end
SPELLBOOKS.AssignSpell = AssignSpell


local function MarkSpellAsFinished(ply)
    if not IsValid(ply) then return end
    ply:SetNWBool("SpellInProgress", false)
    ply:SetNWBool("IsCasting", false)
    ply:SetNWBool("IsRandomizing", false)
    ply:SetNWBool("SpellOverlay", false)
    ply:SetNWString("ActiveSpell", "")
    ply:SetNWString("ActiveSpellDisplayName", "")

    local id = ply:SteamID()
    timer.Remove("CastingInterruptTimer_" .. id)
    timer.Remove("SpellRandomizer_" .. id)
end
SPELLBOOKS.MarkSpellAsFinished = MarkSpellAsFinished


local function SpellCastFailure(ply)
    if not IsValid(ply) then return end
    EmitSpellSound(ply:GetPos(), "libbys/halloween/charged_death.ogg")
    CreateExplosion(ply)
    MarkSpellAsFinished(ply)

    local prevWeapon = ply:GetNWString("PreviousWeaponClass", "")
    if prevWeapon ~= "" then
        ply:Give(prevWeapon)
        ply:SelectWeapon(prevWeapon)
    end
end


local function GetRandomSpellExcludingLast(ply, spells)
    local last = playerLastSpells[ply:SteamID()]
    local pool = {}
    for _, s in ipairs(spells) do
        if s.DisplayName ~= last then
            pool[#pool + 1] = s
        end
    end
    if #pool == 0 then pool = spells end
    return pool[math.random(#pool)]
end


local function HandleSpellbookCollect(ply, spellbook)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:GetNWBool("IsRandomizing", false) then return end
    if ply:GetNWString("ActiveSpell", "") ~= "" then return end
    if ply:GetNWBool("IsCasting", false) then return end
    if ply:GetNWBool("SpellInProgress", false) then return end
    if isBuildOrPill(ply) then return end

    PlayPickupSound(ply)
    if IsValid(spellbook) then spellbook:Remove() end

    local spells = LoadSpells()
    if #spells == 0 then return end

    ply:SetNWBool("IsRandomizing", true)

    local names = {}
    for i = 1, #spells do names[i] = spells[i].DisplayName end
    net.Start("StartSpellRandomizer")
    net.WriteTable(names)
    net.Send(ply)

    local id = ply:SteamID()
    local randoTimer = "SpellRandomizer_" .. id
    timer.Create(randoTimer, 2, 1, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local s = GetRandomSpellExcludingLast(ply, spells)
        AssignSpell(ply, s)
        playerLastSpells[id] = s.DisplayName
        ply:SetNWBool("IsRandomizing", false)
        net.Start("FinalizeSpell")
        net.WriteString(s.DisplayName)
        net.Send(ply)
        StopPickupSound(ply)
    end)
end
SPELLBOOKS.HandleSpellbookCollect = HandleSpellbookCollect


local function CheckSpellbookCollect(spellbook)
    local nearby = ents.FindInSphere(spellbook:GetPos(), COLLECTION_RANGE)
    for _, ent in ipairs(nearby) do
        if ent:IsPlayer() and ent:Alive() then
            HandleSpellbookCollect(ent, spellbook)
            break
        end
    end
end
SPELLBOOKS.CheckSpellbookCollect = CheckSpellbookCollect


local function CastSpell(ply)
    if not IsValid(ply) then return end
    local spellName = ply:GetNWString("ActiveSpell", "")
    if spellName == "" or ply:GetNWBool("IsCasting", false) then return end
    if isBuildOrPill(ply) then return end
    if ply:InVehicle() or ply:GetNWBool("IsSitting", false) then return end

    local origWeap = ply:GetActiveWeapon()
    if not IsValid(origWeap) then return end
    ply:SetNWString("PreviousWeaponClass", origWeap:GetClass())

    local arms = ply:Give("spellcaster")
    if not IsValid(arms) then return end
    ply:SelectWeapon("spellcaster")

    local vm = ply:GetViewModel()
    if IsValid(vm) then
        vm:SetModel("models/weapons/c_arms.mdl")
        local animID = vm:LookupSequence("cast_spell")
        if animID and animID >= 0 then
            vm:SendViewModelMatchingSequence(animID)
        end
    end

    ply:SetNWBool("IsCasting", true)

    local id = ply:SteamID()
    local function InterruptMonitor()
        if not IsValid(ply) or not ply:Alive() or ply:InVehicle() or ply:GetNWBool("IsSitting", false) then
            SpellCastFailure(ply)
            timer.Remove("CastingInterruptTimer_" .. id)
        end
    end
    timer.Create("CastingInterruptTimer_" .. id, 0.1, 0, InterruptMonitor)

    local castFrame = 17 * (1 / 30)
    timer.Simple(castFrame, function()
        if not IsValid(ply) or not ply:Alive() then
            timer.Remove("CastingInterruptTimer_" .. id)
            timer.Remove("SpellRandomizer_" .. id)
            return
        end

        timer.Remove("CastingInterruptTimer_" .. id)
        timer.Remove("SpellRandomizer_" .. id)

        local script = "spells/" .. spellName .. ".lua"
        if file.Exists(script, "LUA") then
            local ok, spellData = pcall(include, script)
            if ok and spellData and isfunction(spellData.Cast) then
                local result = spellData.Cast(ply)
                ply:SetNWBool("SpellOverlay", true)
                if result == false then
                    MarkSpellAsFinished(ply)
                    ply:SetNWBool("SpellOverlay", false)
                end
            end
        end

        net.Start("ClearSpellUI")
        net.Send(ply)
    end)

    timer.Simple(1, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local prev = ply:GetNWString("PreviousWeaponClass", "")
        if prev ~= "" then
            ply:Give(prev)
            ply:SelectWeapon(prev)
        end
        ply:SetNWBool("IsCasting", false)
        ClearPlayerSpell(ply)
        ply:SetNWString("ActiveSpell", "")
    end)

    timer.Simple(1.5, function()
        if not IsValid(ply) or not ply:Alive() then
            ClearPlayerSpell(ply)
        end
    end)
end
SPELLBOOKS.CastSpell = CastSpell


function SPELLBOOKS.GiveAndCast(ply, spellName)
    if not IsValid(ply) or not file.Exists("spells/" .. spellName .. ".lua", "LUA") then return end
    AssignSpell(ply, { Name = spellName, DisplayName = spellName })
    CastSpell(ply)
end


local function GarbageCollector()
    for i = #spellbooks, 1, -1 do
        if not IsValid(spellbooks[i]) then table.remove(spellbooks, i) end
    end
    for steamid, _ in pairs(playerSpells) do
        local ply = player.GetBySteamID(steamid)
        if not IsValid(ply) then
            playerSpells[steamid] = nil
            playerLastSpells[steamid] = nil
            timer.Remove("CastingInterruptTimer_" .. steamid)
            timer.Remove("SpellRandomizer_" .. steamid)
        end
    end
end
timer.Create("SpellGarbageCollector", 300, 0, GarbageCollector)



hook.Add("ShutDown", "SpellbookCleanup", function()
    CleanupSpellbooks()
end)
hook.Add("PostCleanupMap", "SpellbookMapCleanup", function()
    CleanupSpellbooks()
end)



function SPELLBOOKS.GetPlayerSaved(ply) return GetPlayerSpell(ply) end
function SPELLBOOKS.ClearPlayer(ply) return ClearPlayerSpell(ply) end
function SPELLBOOKS.LoadSpells() return LoadSpells() end
