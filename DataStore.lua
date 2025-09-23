local Players = game:GetService('Players')
local Module = script.VirtualData
local VirtualData = require(Module)
local Modules = script.Modules
local DataStore = require(Modules:FindFirstChild('DataStore'))
local Store = DataStore.new({Name = 'PlayersData'})

Players.PlayerAdded:Connect(function(player)
	local key = Store.SetKey(player)
	local default = {
		MainData = {Clicks = 0, Rebirths = 0, __sync = 'Public'},
		PlusData = {ClickPlus = 1,RebirthPlus = 1, __sync = 'Private'},
		CostData = {RebirthCost = 20, __sync = 'Private'}
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