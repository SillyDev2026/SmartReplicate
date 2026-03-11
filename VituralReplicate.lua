local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ModulesFolder = script.Parent:WaitForChild("Modules")
local StatsModules: {[string]: any} = {}
local PlayersData = require(script.Parent.Modules.PlayersData)

for _, mod in ipairs(ModulesFolder:GetChildren()) do
	if mod:IsA("ModuleScript") and mod.Name ~= "PlayersDataStore" and mod.Name ~= "DataStore" then
		StatsModules[mod.Name] = require(mod)
	end
end

local FolderSyncEvent = ReplicatedStorage:FindFirstChild("FolderSyncEvent") or Instance.new("RemoteEvent")
FolderSyncEvent.Name = "FolderSyncEvent"
FolderSyncEvent.Parent = ReplicatedStorage

local ActiveFolders: {[number]: any} = {}

local function DeepCopy<T>(tbl: T): T
	if type(tbl) ~= "table" then return tbl end
	local copy = {} :: any
	for k,v in pairs(tbl) do
		copy[k] = DeepCopy(v)
	end
	return copy
end

export type VirtualData = {
	EnsureFolder: (self: VirtualData, folderName: string) -> VirtualData,
	Define: (self: VirtualData, path: string, dataType: string, defaultValue: any, syncMode: string?) -> VirtualData,
	AddMiddleware: (self: VirtualData, path: string, func: (value: any, oldValue: any) -> any) -> VirtualData,
	OnCreated: (self: VirtualData, callback: (folderName: string) -> ()) -> (),
	OnChanged: (self: VirtualData, path: string, callback: (newVal: any, oldVal: any) -> ()) -> (),
	Update: (self: VirtualData, path: string, value: any) -> (),
	SetSyncMode: (self: VirtualData, folderName: string, mode: string) -> (),
	TogglePublic: (self: VirtualData, folderName: string) -> (),
	GetData: (self: VirtualData, path: string) -> any,
	Destroy: (self: VirtualData) -> (),
	Data: PlayersData.Data,
}

local PlayerFolder = {}
PlayerFolder.__index = PlayerFolder

function PlayerFolder.new(player: Player, schema: {[string]: any}?, dataStore: any): VirtualData
	if ActiveFolders[player.UserId] then return ActiveFolders[player.UserId] end
	local self = setmetatable({}, PlayerFolder)
	self.Player = player
	self.Data = schema and DeepCopy(schema) or {}
	self.Version = 1
	self.ChangeListeners = {} :: {[string]: {(any, any) -> ()}}
	self.CreatedListeners = {} :: {(string) -> ()}
	self.Middleware = {} :: {[string]: (any, any) -> any}
	self.Store = dataStore
	ActiveFolders[player.UserId] = self

	for folderName,_ in pairs(self.Data) do
		self:FireCreated(folderName)
	end

	FolderSyncEvent:FireAllClients("InitPlayer", player.UserId, self.Data)
	return self
end

-- Utilities
function PlayerFolder:EnsureFolder(folderName: string)
	if not self.Data[folderName] then
		self.Data[folderName] = {__sync = "Private"}
		self:FireCreated(folderName)
	end
end

function PlayerFolder:Define(path: string, dataType: string, defaultValue: any, syncMode: string?)
	local parts = {}
	for part in path:gmatch("[^.]+") do
		table.insert(parts, part)
	end
	local folderName = parts[1]
	self:EnsureFolder(folderName)
	local current = self.Data
	for i, part in ipairs(parts) do
		if i == #parts then
			current[part] = defaultValue
			current[part.."__type"] = dataType
		else
			current[part] = current[part] or {}
			current = current[part]
		end
	end
	self.Data[folderName].__sync = syncMode or self.Data[folderName].__sync or "Private"
end

function PlayerFolder:AddMiddleware(path: string, func: (any, any) -> any)
	self.Middleware[path] = func
end

function PlayerFolder:FireCreated(folderName: string)
	for _, cb in ipairs(self.CreatedListeners) do
		cb(folderName)
	end
end

function PlayerFolder:OnCreated(callback: (folderName: string) -> ())
	table.insert(self.CreatedListeners, callback)
end

function PlayerFolder:FireChanged(path: string, newValue: any, oldValue: any)
	if self.ChangeListeners[path] then
		for _, cb in ipairs(self.ChangeListeners[path]) do
			cb(newValue, oldValue)
		end
	end
end

function PlayerFolder:OnChanged(path: string, callback: (newVal: any, oldVal: any) -> ())
	self.ChangeListeners[path] = self.ChangeListeners[path] or {}
	table.insert(self.ChangeListeners[path], callback)
end

function PlayerFolder:GetData(path: string): any
	local current = self.Data
	for part in path:gmatch("[^.]+") do
		if type(current) ~= "table" then
			warn(`Invalid path: {path}`)
			return nil
		end
		current = current[part]
		if current == nil then
			warn(`Path not found: {path}`)
			return nil
		end
	end
	return current
end

function PlayerFolder:Update(path: string, value: any)
	local parts = {}
	for part in path:gmatch("[^.]+") do table.insert(parts, part) end
	if #parts == 0 then return end
	self:EnsureFolder(parts[1])

	local current = self.Data
	for i, part in ipairs(parts) do
		if i == #parts then
			if part == "__sync" then return end
			local expectedType = current[part.."__type"]
			if expectedType and type(value) ~= expectedType then
				warn(`Type mismatch for {path}, expected {expectedType}, got {typeof(value)}`)
				return
			end
			local fullPath = table.concat(parts, ".")
			if self.Middleware[fullPath] then
				value = self.Middleware[fullPath](value, current[part])
			end
			local oldValue = current[part]
			current[part] = value
			self.Version += 1
			self:FireChanged(fullPath, value, oldValue)

			local syncMode = self.Data[parts[1]].__sync or "Private"
			if syncMode == "Public" then
				FolderSyncEvent:FireAllClients("Update", self.Player.UserId, parts[1], part, value)
			else
				FolderSyncEvent:FireClient(self.Player, "Update", self.Player.UserId, parts[1], part, value)
			end

			if self.Store then
				local key = self.Store.SetKey(self.Player)
				self.Store.Session[key] = self.Data
			end
		else
			current[part] = current[part] or {}
			current = current[part]
		end
	end
end

function PlayerFolder:SetSyncMode(folderName: string, mode: string)
	local folder = self.Data[folderName]
	if not folder then return end
	folder.__sync = mode
	for itemName,value in pairs(folder) do
		if itemName ~= "__sync" and not itemName:match("__type$") then
			if mode == "Public" then
				FolderSyncEvent:FireAllClients("Update", self.Player.UserId, folderName, itemName, value)
			else
				FolderSyncEvent:FireClient(self.Player, "Update", self.Player.UserId, folderName, itemName, value)
			end
		end
	end
	if self.Store then
		local key = self.Store.SetKey(self.Player)
		self.Store.Session[key] = self.Data
	end
end

function PlayerFolder:TogglePublic(folderName: string)
	local folder = self.Data[folderName]
	if not folder then return end
	self:SetSyncMode(folderName, (folder.__sync == "Public") and "Private" or "Public")
end

function PlayerFolder:Destroy()
	ActiveFolders[self.Player.UserId] = nil
	FolderSyncEvent:FireAllClients("RemovePlayer", self.Player.UserId)
end

function PlayerFolder.get(player: Player): VirtualData
	local folder = ActiveFolders[player.UserId]
	while not folder do task.wait() end
	return folder
end

function PlayerFolder.remove(player: Player)
	local folder = ActiveFolders[player.UserId]
	if folder then folder:Destroy() end
end

-- Remote Event Handling
FolderSyncEvent.OnServerEvent:Connect(function(player, action, ...)
	local folder = PlayerFolder.get(player)
	if not folder then return end

	if action == "RequestUpdate" then
		local path, value = ...
		if folder then folder:Update(path, value) end
	elseif action == "RequestModule" then
		local moduleName, moduleAction = ...
		local module = StatsModules[moduleName]
		if module and module[moduleAction] then
			module[moduleAction](player, folder)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerFolder.remove(player)
end)

return PlayerFolder
