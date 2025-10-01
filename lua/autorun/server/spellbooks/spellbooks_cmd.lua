// list/give/cast
concommand.Add("halloween_give_spell", function(ply, _, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply:IsSuperAdmin() then return end

    if #args < 1 then
        local list = SPELLBOOKS.LoadSpells()
        if #list == 0 then
            print("No spells available.")
            return
        end
        print("Available spells:")
        for _, s in ipairs(list) do
            print("- " .. s.DisplayName)
        end
        return
    end

    if not ply:Alive()
        or ply:GetNWBool("IsCasting", false)
        or ply:GetNWBool("IsRandomizing", false)
        or ply:GetNWString("ActiveSpell", "") ~= ""
        or ply:GetNWBool("SpellInProgress", false)
    then
        print("You cannot receive a new spell at this time.")
        return
    end

    local name = table.concat(args, " ")
    local found, chosen

    for _, s in ipairs(SPELLBOOKS.LoadSpells()) do
        if s.DisplayName == name then
            found = true
            chosen = s
            break
        end
    end

    if not found and file.Exists("spells/" .. name .. ".lua", "LUA") then
        found = true
        chosen = { Name = name, DisplayName = name }
    end

    if not found then
        print("Invalid spell")
        return
    end

    SPELLBOOKS.AssignSpell(ply, chosen)
    SPELLBOOKS.CastSpell(ply)
end)
