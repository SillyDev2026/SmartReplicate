local Players = game:GetService('Players')
local Module = script.VirtualData
local VirtualData = require(Module)
local Modules = script.Modules
local DataStore = require(Modules:FindFirstChild('DataStore'))
local Store = DataStore.new({Name = 'PlayersData'})
local PlayersData = script.PlayersData

function Data(name)
	return require(PlayersData[name])
end

Players.PlayerAdded:Connect(function(player)
	local key = Store.SetKey(player)
	local default = {
		MainData = Data('MainData'),
		PlusData = Data('PlusData'),
		CostData = Data('CostData')
	}
	
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