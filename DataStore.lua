local Players = game:GetService('Players')
local Module = script.VirtualData
local VirtualData = require(Module)
local Modules = script.Modules
local DataStore = require(Modules:FindFirstChild('DataStore'))
local StoreName = script.DataStoreName.Value
local Store = DataStore.new({Name = script.DataStoreName.Value})
local PlayersData = script:FindFirstChild(StoreName)

Players.PlayerAdded:Connect(function(player)
	local key = Store.SetKey(player)
	local default = {}
	for _, modules in pairs(PlayersData:GetChildren()) do
		if modules:IsA('ModuleScript') and (modules.Name ~= 'DataStore' and modules.Name ~= 'PlayersDataStore') then
			default[modules.Name] = require(modules)
		end
	end	
	local data = Store:GetAsync(key, player, default)
	local folder = VirtualData.new(player, data, Store)
	-- u create the rest here if any problems just contact sillydev0050 in discord
end)

Players.PlayerRemoving:Connect(function(player)
	local key = Store.SetKey(player)
	Store:OnLeaveUpdate(key)
end)

game:BindToClose(function()
	local key = 'Player_'
	Store:BindOnUpdate(key, Players)
end)
