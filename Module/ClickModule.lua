local ClickModule = {}

-- Only these named server-authoritative actions can be invoked remotely.
ClickModule.ClientActions = {OnClick = true}

function ClickModule.OnClick(player, folder)
    local data = folder.Data
    local main = data.MainData
    local upgrades = data.PlusData
    if type(main) ~= "table" or type(upgrades) ~= "table" then return end
    local clicks = main.Clicks
    local clickPlus = upgrades.ClickPlus
    if type(clicks) ~= "number" or type(clickPlus) ~= "number" then return end
    if clicks ~= clicks or clickPlus ~= clickPlus then return end
    if clickPlus < 0 or math.abs(clicks) == math.huge then return end
    local total = clicks + clickPlus
    if total == math.huge or total ~= total then return end
    folder:Update("MainData", "Clicks", total)
end

return ClickModule