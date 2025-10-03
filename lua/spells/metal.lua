local function CleanupMetal(ply, uid)
    hook.Remove("PlayerFootstep",     uid .. "_Foot")
    hook.Remove("EntityTakeDamage",   uid .. "_Dmg")
    hook.Remove("OnPlayerHitGround",  uid .. "_Ground")
    hook.Remove("PlayerDeath",        uid .. "_Death")
    hook.Remove("PlayerDisconnected", uid .. "_DC")
    timer.Remove(uid .. "_Timer")

    if not IsValid(ply) then return end
    if not ply._metalActive then return end

    ply:SetMaterial("")
    local vm = ply:GetViewModel()
    if IsValid(vm) then vm:SetMaterial("") end

    if ply._metalWalkSpeed then ply:SetWalkSpeed(ply._metalWalkSpeed) end
    if ply._metalRunSpeed  then ply:SetRunSpeed(ply._metalRunSpeed) end
    if ply._metalJumpPower then ply:SetJumpPower(ply._metalJumpPower) end
    if ply._metalGravity   ~= nil then ply:SetGravity(ply._metalGravity) end


    ply:SetNWBool("IsMetal", false)
    ply:SetNWBool("SpellInProgress", false)
    ply:SetNWBool("SpellOverlay", false)
    ply:StopSound("libbys/halloween/metaltheme.wav")

    ply._metalWalkSpeed, ply._metalRunSpeed = nil, nil
    ply._metalJumpPower, ply._metalGravity = nil, nil
    ply._metalActive = nil
end

return {
    Cast = function(ply)
        if not IsValid(ply) then return false end
        if ply:GetNWBool("SpellInProgress") or ply._metalActive then return false end

        local sid64 = ply:SteamID64() or tostring(ply:EntIndex())
        local uid = "Metal_" .. sid64

        ply._metalActive = true
        ply:SetNWBool("SpellInProgress", true)
        ply:SetNWBool("IsMetal", true)
        ply:SetNWBool("SpellOverlay", true)

        ply._metalWalkSpeed = ply:GetWalkSpeed()
        ply._metalRunSpeed  = ply:GetRunSpeed()
        ply._metalJumpPower = ply:GetJumpPower()
        ply._metalGravity   = ply:GetGravity()

        ply:EmitSound("libbys/halloween/zap.wav", 60, 100)
        ply:EmitSound("libbys/halloween/metaltheme.wav", 100, 100)

        ply:SetMaterial("debug/env_cubemap_model")
        local vm = ply:GetViewModel()
        if IsValid(vm) then -- ViewModel still might not work
            vm:SetMaterial("debug/env_cubemap_model")
        end

        ply:SetWalkSpeed(100)
        ply:SetRunSpeed(140)
        ply:SetJumpPower(0)
        ply:SetGravity(2.2)


        hook.Add("PlayerFootstep", uid .. "_Foot", function(player, pos, foot, sound, volume, rf)
            if player ~= ply or not player:GetNWBool("IsMetal") then return end
            player:EmitSound("libbys/halloween/clang_short.wav", 85, math.random(90, 110))
            util.ScreenShake(player:GetPos(), 5, 3, 0.5, 500)
            return true
        end)

        hook.Add("EntityTakeDamage", uid .. "_Dmg", function(target, dmginfo)
            if target ~= ply or not target:GetNWBool("IsMetal") then return end
            dmginfo:SetDamage(0)
            return true
        end)

        hook.Add("OnPlayerHitGround", uid .. "_Ground", function(player, inWater, onFloater, speed)
            if player ~= ply or not ply:GetNWBool("IsMetal") then return end
            if speed <= 200 then return end

            local crushRadius = 200
            for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), crushRadius)) do
                if ent:IsPlayer() then
                    if ent ~= ply and ent:Alive() then ent:Kill() end
                elseif ent:IsNPC() then
                    ent:TakeDamage(2500, ply, ply)
                elseif ent:GetClass() == "prop_physics" then
                    ent:Fire("Break")
                end
            end
        end)

        hook.Add("PlayerDeath", uid .. "_Death", function(victim)
            if victim == ply then CleanupMetal(ply, uid) end
        end)
        hook.Add("PlayerDisconnected", uid .. "_DC", function(p)
            if p == ply then CleanupMetal(ply, uid) end
        end)

        timer.Create(uid .. "_Timer", 37, 1, function()
            CleanupMetal(ply, uid)
            if IsValid(ply) then
                ply:EmitSound("libbys/halloween/power_down.ogg", 45, 100)
            end
        end)


        return "async"
    end,

    GetDisplayName = function()
        return "Metal"
    end
}
