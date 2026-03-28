local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.NetworkHandler.EventBus).Remote(true)
local IDs = require(ReplicatedStorage.Events)

local StatsModules = {}
local Modules = script.Parent:WaitForChild("Modules")

for _, moduleScripts in ipairs(Modules:GetChildren()) do
	if moduleScripts:IsA("ModuleScript") and moduleScripts.Name ~= "PlayersDataStore" and moduleScripts.Name ~= "DataStore" then
		StatsModules[moduleScripts.Name] = require(moduleScripts)
	end
end

local ActiveFolders = {}

local function DeepCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = DeepCopy(v)
	end
	return copy
end

local PlayerFolder = {}
PlayerFolder.__index = PlayerFolder

-- 🔹 Constructor
function PlayerFolder.new(player, schema, dataStore)
	if ActiveFolders[player.UserId] then
		return ActiveFolders[player.UserId]
	end

	local self = setmetatable({}, PlayerFolder)

	self.Player = player
	self.Data = schema and DeepCopy(schema) or {}
	self.Version = 1
	self.ChangeListeners = {}
	self.CreatedListeners = {}
	self.Middleware = {}
	self.Store = dataStore

	ActiveFolders[player.UserId] = self

	for folderName in pairs(self.Data) do
		self:FireCreated(folderName)
	end

	Net:Fire(IDs.InitPlayer.Id, tostring(player.UserId), self.Data)

	return self
end

-- 🔹 Core
function PlayerFolder:EnsureFolder(folderName)
	if not self.Data[folderName] then
		self.Data[folderName] = { __sync = "Private" }
		self:FireCreated(folderName)
	end
end

function PlayerFolder:Define(path, dataType, defaultValue, syncMode)
	local folderName, itemName = path:match("([^.]+)%.([^.]+)")
	if not folderName then return end

	self:EnsureFolder(folderName)

	local folder = self.Data[folderName]
	folder[itemName] = defaultValue
	folder[itemName .. "__type"] = dataType
	folder.__sync = syncMode or "Private"
end

function PlayerFolder:AddMiddleware(path, func)
	self.Middleware[path] = func
end

function PlayerFolder:FireCreated(folderName)
	for _, cb in ipairs(self.CreatedListeners) do
		cb(folderName)
	end
end

function PlayerFolder:OnCreated(callback)
	table.insert(self.CreatedListeners, callback)
end

function PlayerFolder:FireChanged(path, newValue, oldValue)
	if self.ChangeListeners[path] then
		for _, cb in ipairs(self.ChangeListeners[path]) do
			cb(newValue, oldValue)
		end
	end
end

function PlayerFolder:OnChanged(path, callback)
	self.ChangeListeners[path] = self.ChangeListeners[path] or {}
	table.insert(self.ChangeListeners[path], callback)
end

-- 🔹 Update (optimized & deduped)
function PlayerFolder:Update(folderName, itemName, value)
	self:EnsureFolder(folderName)

	local folder = self.Data[folderName]
	if itemName == "__sync" then return end

	local expectedType = folder[itemName .. "__type"]
	if expectedType and type(value) ~= expectedType then
		warn("Type mismatch on update:", folderName, itemName)
		return
	end

	local path = folderName .. "." .. itemName
	local oldValue = folder[itemName]
	if oldValue == value then return end

	if self.Middleware[path] then
		value = self.Middleware[path](value, oldValue)
	end
	
	if oldValue == value then return end

	folder[itemName] = value
	self.Version += 1

	self:FireChanged(path, value, oldValue)

	local syncMode = folder.__sync or "Private"

	if syncMode == "Public" then
		Net:Fire(IDs.Update.Id, tostring(self.Player.UserId), folderName, itemName, value)
	else
		Net:FireToPlayer(self.Player, IDs.Update.Id, tostring(self.Player.UserId), folderName, itemName, value)
	end

	if self.Store then
		local key = self.Store.SetKey(self.Player)
		self.Store.Session[key] = self.Data
	end
end

-- 🔹 Sync Mode
function PlayerFolder:SetSyncMode(folderName, mode)
	local folder = self.Data[folderName]
	if not folder then return end

	folder.__sync = mode

	for itemName, value in pairs(folder) do
		if itemName ~= "__sync" and not itemName:match("__type$") then
			Net:Fire(IDs.Update.Id, tostring(self.Player.UserId), folderName, itemName, value)
		end
	end

	if self.Store then
		local key = self.Store.SetKey(self.Player)
		self.Store.Session[key] = self.Data
	end
end

function PlayerFolder:TogglePublic(folderName)
	local folder = self.Data[folderName]
	if not folder then return end

	local newMode = (folder.__sync == "Public") and "Private" or "Public"
	self:SetSyncMode(folderName, newMode)
end

-- 🔹 Destroy
function PlayerFolder:Destroy()
	ActiveFolders[self.Player.UserId] = nil
	Net:Fire(IDs.RemovePlayer.Id, tostring(self.Player.UserId))
end

-- 🔹 Static
function PlayerFolder.get(player)
	local folder = ActiveFolders[player.UserId]
	while not folder do task.wait() end
	return folder
end

function PlayerFolder.remove(player)
	local folder = ActiveFolders[player.UserId]
	if folder then folder:Destroy() end
end

Net:Connect(IDs.RequestUpdate.Id, function(player, folderName, itemName, value)
	local folder = PlayerFolder.get(player)
	if folder then
		folder:Update(folderName, itemName, value)
	end
end)

Net:Connect(IDs.RequestModule.Id, function(player, moduleName, moduleAction, ...)
	local folder = PlayerFolder.get(player)
	local mod = StatsModules[moduleName]

	if mod and mod[moduleAction] then
		mod[moduleAction](player, folder, ...)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerFolder.remove(player)
end)

-- 🔹 Get Data
function PlayerFolder:GetData(path)
	local folderName, itemName = path:match("([^.]+)%.([^.]+)")
	if not folderName or not itemName then
		warn("Invalid path:", path)
		return nil
	end

	local folder = self.Data[folderName]
	if not folder then return nil end

	return folder[itemName]
end

return PlayerFolder
