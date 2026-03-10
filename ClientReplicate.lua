local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local FolderSyncEvent = ReplicatedStorage:WaitForChild("FolderSyncEvent")

local ActiveFolders: {[number]: any} = {}

export type ClientData = {
	EnsureFolder: (self: ClientData, folderName: string) -> (),
	OnCreated: (self: ClientData, callback: (folderName: string) -> ()) -> (),
	OnChanged: (self: ClientData, path: string, callback: (newValue: any, oldValue: any?) -> ()) -> (),
	ApplyUpdate: (self: ClientData, path: string, value: any) -> (),
	RequestUpdate: (self: ClientData, path: string, value: any) -> (),
	RequestModule: <T...>(self: ClientData, moduleName: string, action: string, T...) -> (),
	GetData: (self: ClientData, path: string) -> any,
}

local function DeepCopy<T>(tbl: T): T
	if type(tbl) ~= "table" then return tbl end
	local copy = {} :: any
	for k,v in pairs(tbl) do
		copy[k] = DeepCopy(v)
	end
	return copy
end

local ClientFolder = {}
ClientFolder.__index = ClientFolder

function ClientFolder.new(userId: number, schema: {[string]: any}? ): ClientData
	if ActiveFolders[userId] then return ActiveFolders[userId] end
	local self = setmetatable({}, ClientFolder)
	self.UserId = userId
	self.Data = schema and DeepCopy(schema) or {}
	self.Version = 1
	self.ChangeListeners = {} :: {[string]: {(any, any?) -> ()}}
	self.CreatedListeners = {} :: {(string) -> ()}
	self.Middleware = {} :: {[string]: (any, any?) -> any}
	ActiveFolders[userId] = self

	for folderName,_ in pairs(self.Data) do
		self:FireCreated(folderName)
	end

	return self
end

-- Ensure a folder exists at the top level
function ClientFolder:EnsureFolder(folderName: string)
	if not self.Data[folderName] then
		self.Data[folderName] = {}
		self:FireCreated(folderName)
	end
end

-- Creation listeners
function ClientFolder:FireCreated(folderName: string)
	for _, cb in ipairs(self.CreatedListeners) do
		cb(folderName)
	end
end

function ClientFolder:OnCreated(callback: (folderName: string) -> ())
	table.insert(self.CreatedListeners, callback)
end

-- Change listeners
function ClientFolder:FireChanged(path: string, newValue: any, oldValue: any?)
	if self.ChangeListeners[path] then
		for _, cb in ipairs(self.ChangeListeners[path]) do
			cb(newValue, oldValue)
		end
	end
end

function ClientFolder:OnChanged(path: string, callback: (newValue: any, oldValue: any?) -> ())
	self.ChangeListeners[path] = self.ChangeListeners[path] or {}
	table.insert(self.ChangeListeners[path], callback)
end

-- Apply an update to arbitrary depth
function ClientFolder:ApplyUpdate(path: string, value: any)
	local parts = {} :: {string}
	for part in path:gmatch("[^.]+") do table.insert(parts, part) end
	if #parts == 0 then return end

	-- ensure top-level folder
	self:EnsureFolder(parts[1])

	local current = self.Data
	for i, part in ipairs(parts) do
		if i == #parts then
			local fullPath = table.concat(parts, ".")
			if self.Middleware[fullPath] then
				value = self.Middleware[fullPath](value, current[part])
			end
			local oldValue = current[part]
			current[part] = value
			self.Version += 1
			self:FireChanged(fullPath, value, oldValue)
		else
			current[part] = current[part] or {}
			current = current[part]
		end
	end
end

-- Request server update
function ClientFolder:RequestUpdate(path: string, value: any)
	FolderSyncEvent:FireServer("RequestUpdate", path, value)
end

-- Generic module request
function ClientFolder:RequestModule<T...>(moduleName: string, action: string, ...: T...)
	FolderSyncEvent:FireServer("RequestModule", moduleName, action, ...)
end

-- Get data from arbitrary depth
function ClientFolder:GetData(path: string): any
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

-- Get active folder by userId
function ClientFolder.get(userId: number): ClientData
	local folder = ActiveFolders[userId]
	while not folder do
		task.wait()
		folder = ActiveFolders[userId]
	end
	return folder
end

function ClientFolder.remove(userId: number)
	ActiveFolders[userId] = nil
end

-- Client event handling
FolderSyncEvent.OnClientEvent:Connect(function(action: string, userId: number, ...)
	local folder = ActiveFolders[userId]
	if action == "InitPlayer" then
		local data = ...
		ClientFolder.new(userId, data)
	elseif action == "Update" then
		local path, value = ...
		if folder then
			folder:ApplyUpdate(path, value)
		end
	elseif action == "RemovePlayer" then
		ClientFolder.remove(userId)
	end
end)

return ClientFolder
