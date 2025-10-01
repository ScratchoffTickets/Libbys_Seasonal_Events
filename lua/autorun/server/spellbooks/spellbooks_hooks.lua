// SPELLBOOKS.*
hook.Add("Think", "SpellbookGlobalRangeCheck", function()
    // ents.FindByClass("lby_spellbook_entity")
    for _, sb in ipairs(ents.FindByClass("prop_dynamic")) do
        if IsValid(sb) and sb:GetModel() == "models/props_halloween/hwn_spellbook_upright.mdl" then
            SPELLBOOKS.CheckSpellbookCollect(sb)
        end
    end
end)

hook.Add("PlayerButtonDown", "Spellbooks_CastOnG", function(ply, button)
    if button == KEY_G then
        SPELLBOOKS.CastSpell(ply)
    end
end)

hook.Add("PlayerDeath", "Spellbooks_OnDeathOverlayClear", function(ply)
    SPELLBOOKS.MarkSpellAsFinished(ply)
    ply:SetNWBool("SpellOverlay", false)
    net.Start("ClearSpellUI")
    net.Send(ply)
    SPELLBOOKS.ClearPlayer(ply)
end)

hook.Add("PlayerSpawn", "Spellbooks_OnSpawnResetRestore", function(ply)
    ply:SetNWBool("IsCasting", false)
    ply:SetNWBool("SpellInProgress", false)
    ply:SetNWBool("SpellOverlay", false)

    timer.Remove("CastingInterruptTimer_" .. ply:SteamID())

    local saved = SPELLBOOKS.GetPlayerSaved(ply)
    if saved.Name ~= "" then
        ply:SetNWString("ActiveSpell", saved.Name)
        ply:SetNWString("ActiveSpellDisplayName", saved.DisplayName)
        net.Start("FinalizeSpell")
        net.WriteString(saved.DisplayName)
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
        if IsValid(sb) and sb:GetModel() == "models/props_halloween/hwn_spellbook_upright.mdl" then
            sb:Remove()
        end
    end
end)
