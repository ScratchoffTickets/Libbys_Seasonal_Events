// SPELLBOOKS.*
hook.Add("Think", "SpellbookGlobalRangeCheck", function()
    if not SPELLBOOKS or not SPELLBOOKS.CheckSpellbookCollect then return end
    local tracked = SPELLBOOKS.List

    for _, sb in ipairs(ents.FindByClass("prop_dynamic")) do
        if IsValid(sb) and sb:GetModel() == "models/libbys/halloween/lby_spellbook.mdl" then
            local managed = sb.IsManagedSpellbook
            if not managed and tracked then
                for i = 1, #tracked do
                    if tracked[i] == sb then managed = true break end
                end
            end
            if managed then
                SPELLBOOKS.CheckSpellbookCollect(sb)
            end
        end
    end
end)

hook.Add("PlayerButtonDown", "Spellbooks_CastOnG", function(ply, button)
    if button == KEY_G and SPELLBOOKS and SPELLBOOKS.CastSpell then
        SPELLBOOKS.CastSpell(ply)
    end
end)

hook.Add("PlayerDeath", "Spellbooks_OnDeathOverlayClear", function(ply)
    if not SPELLBOOKS then return end
    if SPELLBOOKS.MarkSpellAsFinished then SPELLBOOKS.MarkSpellAsFinished(ply) end
    ply:SetNWBool("SpellOverlay", false)
    net.Start("ClearSpellUI") net.Send(ply)
    if SPELLBOOKS.ClearPlayer then SPELLBOOKS.ClearPlayer(ply) end
end)

hook.Add("PlayerSpawn", "Spellbooks_OnSpawnResetRestore", function(ply)
    ply:SetNWBool("IsCasting", false)
    ply:SetNWBool("SpellInProgress", false)
    ply:SetNWBool("SpellOverlay", false)
    timer.Remove("CastingInterruptTimer_" .. ply:SteamID())

    if not (SPELLBOOKS and SPELLBOOKS.GetPlayerSaved) then
        ply:SetNWString("ActiveSpell", "")
        return
    end

    local saved = SPELLBOOKS.GetPlayerSaved(ply)
    if saved.Name and saved.Name ~= "" then
        ply:SetNWString("ActiveSpell", saved.Name)
        ply:SetNWString("ActiveSpellDisplayName", saved.DisplayName or saved.Name)
        net.Start("FinalizeSpell")
        net.WriteString(saved.DisplayName or saved.Name)
        net.Send(ply)
    else
        ply:SetNWString("ActiveSpell", "")
    end
end)



hook.Add("PlayerDisconnected", "Spellbooks_StopRandomizerOnDC", function(ply)
    local id = ply:SteamID()
    timer.Remove("SpellRandomizer_" .. id)
    ply:SetNWBool("IsRandomizing", false)
end)

hook.Add("ShutDown", "Spellbooks_RemoveAllProps", function()
    for _, sb in ipairs(ents.FindByClass("prop_dynamic")) do
        if IsValid(sb) and sb:GetModel() == "models/libbys/halloween/lby_spellbook.mdl" then
            sb:Remove()
        end
    end
end)
