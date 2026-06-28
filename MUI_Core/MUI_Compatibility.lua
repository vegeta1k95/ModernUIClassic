function MUI.GetClassID(who)
    local _, _, classID = UnitClass(who or "player")
    return classID
end

function MUI.GetClassName(who)
    local className = UnitClass(who or "player")
    return className
end