local Players = game:GetService('Players')
local Module = script.VirtualData
local VirtualData = require(Module)
local Modules = script.Modules
local DataStore = require(Modules:FindFirstChild('DataStore'))
local Store = DataStore.new({Name = 'LevelTracker'})
local PlayersData = script.PlayersData

function Data(name)
	return require(PlayersData[name])
end

Players.PlayerAdded:Connect(function(player)
	local key = Store.SetKey(player)
	local default = {}
	for _, modules in pairs(PlayersData:GetChildren()) do
		if modules:IsA('ModuleScript') then
			default[modules.Name] = require(modules)
		end
	end	
	local data = Store:GetAsync(key, player, default)
	VirtualData.new(player, data, Store)
end)

Players.PlayerRemoving:Connect(function(player)
	local key = Store.SetKey(player)
	Store:OnLeaveUpdate(key)
end)

game:BindToClose(function()
	local key = 'Player_'
	Store:BindOnUpdate(key, Players)
end)