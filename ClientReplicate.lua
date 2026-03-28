local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local EventBus = require('@game/ReplicatedStorage/NetworkHandler/EventBus')
local Events = require('@game/ReplicatedStorage/Events')

local Bus = EventBus.Remote(false)

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

local function DeepCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = DeepCopy(v)
	end
	return copy
end

local ClientFolder = {}
ClientFolder.__index = ClientFolder

-- 🔹 constructor
function ClientFolder.new(userId: number, schema: {[string]: any}?): ClientData
	if ActiveFolders[userId] then
		return ActiveFolders[userId]
	end

	local self = setmetatable({}, ClientFolder)
	self.UserId = userId
	self.Data = schema and DeepCopy(schema) or {}
	self.Version = 1
	self.ChangeListeners = {}
	self.CreatedListeners = {}
	self.Middleware = {}

	ActiveFolders[userId] = self

	for folderName in pairs(self.Data) do
		self:FireCreated(folderName)
	end

	return self
end

-- 🔹 utilities
function ClientFolder:EnsureFolder(folderName: string)
	if not self.Data[folderName] then
		self.Data[folderName] = {}
		self:FireCreated(folderName)
	end
end

function ClientFolder:FireCreated(folderName: string)
	for _, cb in ipairs(self.CreatedListeners) do
		cb(folderName)
	end
end

function ClientFolder:OnCreated(callback)
	table.insert(self.CreatedListeners, callback)
end

function ClientFolder:FireChanged(path: string, newValue: any, oldValue: any?)
	if self.ChangeListeners[path] then
		for _, cb in ipairs(self.ChangeListeners[path]) do
			cb(newValue, oldValue)
		end
	end
end

function ClientFolder:OnChanged(path: string, callback)
	self.ChangeListeners[path] = self.ChangeListeners[path] or {}
	table.insert(self.ChangeListeners[path], callback)
end

-- 🔹 apply update
function ClientFolder:ApplyUpdate(path: string, value: any)
	local parts = {}
	for part in path:gmatch("[^.]+") do
		table.insert(parts, part)
	end

	if #parts == 0 then return end

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

-- 🔹 requests
function ClientFolder:RequestUpdate(path: string, value: any)
	Bus:Fire(Events.RequestUpdate.Id, Events.RequestUpdate.Tag, path, value)
end

function ClientFolder:RequestModule(moduleName: string, action: string, ...)
	Bus:Fire(Events.RequestModule.Id, Events.RequestModule.Tag, moduleName, action, ...)
end

-- 🔹 data access
function ClientFolder:GetData(path: string)
	local current = self.Data

	for part in path:gmatch("[^.]+") do
		if type(current) ~= "table" then return nil end
		current = current[part]
		if current == nil then return nil end
	end

	return current
end

-- 🔹 static
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

Bus:Connect(Events.InitPlayer.Id, function(_, tag, userId, data)
	ClientFolder.new(tonumber(userId), data)
end)

Bus:Connect(Events.Update.Id, function(_, tag, userId, folderName, key, value)
	local folder = ActiveFolders[tonumber(userId)]
	if not folder then return end

	local path = folderName .. "." .. key
	folder:ApplyUpdate(path, value)
end)

Bus:Connect(Events.RemovePlayer.Id, function(_, tag, userId)
	ClientFolder.remove(userId)
end)

return ClientFolder
