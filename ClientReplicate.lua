local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local FolderSyncEvent = ReplicatedStorage:WaitForChild("FolderSyncEvent")

local ActiveFolders = {}
export type ClientData = {
	EnsureFolder: (self: ClientData, folderName: string) -> (),
	OnCreated: (self: ClientData, callback: (folderName: string) -> ()) -> (),
	OnChanged: (self: ClientData, path: string, callback: (newValue: any, oldValue: any?) -> ()) -> (),
	ApplyUpdate: (self: ClientData, folderName: string, itemName: string, value: any) -> (),
	RequestUpdate: (self: ClientData, folderName: string, itemName: string, value: any) -> (),
	RequestModule: (self: ClientData, moduleName: string, action: string) -> (),
	GetData: (self: ClientData, folderName: string, statName: string) -> any,
}

local function DeepCopy(tbl)
	local copy = {}
	for k,v in pairs(tbl) do
		if type(v)=="table" then copy[k]=DeepCopy(v) else copy[k]=v end
	end
	return copy
end

local ClientFolder = {}
ClientFolder.__index = ClientFolder

function ClientFolder.new(userId, schema)
	if ActiveFolders[userId] then return ActiveFolders[userId] end
	local self = setmetatable({}, ClientFolder)
	self.UserId = userId
	self.Data = schema and DeepCopy(schema) or {}
	self.Version = 1
	self.ChangeListeners = {}
	self.CreatedListeners = {}
	ActiveFolders[userId] = self

	for folderName,_ in pairs(self.Data) do
		self:FireCreated(folderName)
	end

	return self
end

function ClientFolder:EnsureFolder(folderName)
	if not self.Data[folderName] then
		self.Data[folderName] = {}
		self:FireCreated(folderName)
	end
end

function ClientFolder:FireCreated(folderName)
	for _,cb in ipairs(self.CreatedListeners) do
		cb(folderName)
	end
end

function ClientFolder:OnCreated(callback)
	table.insert(self.CreatedListeners, callback)
end

function ClientFolder:FireChanged(path, newValue, oldValue)
	if self.ChangeListeners[path] then
		for _, cb in ipairs(self.ChangeListeners[path]) do
			cb(newValue, oldValue)
		end
	end
end

function ClientFolder:OnChanged(path, callback)
	self.ChangeListeners[path] = self.ChangeListeners[path] or {}
	table.insert(self.ChangeListeners[path], callback)
end

function ClientFolder:ApplyUpdate(folderName, itemName, value)
	self:EnsureFolder(folderName)
	local folder = self.Data[folderName]

	local oldValue = folder[itemName]
	folder[itemName] = value
	self.Version += 1
	self:FireChanged(folderName.."."..itemName, value, oldValue)
end

function ClientFolder:RequestUpdate(folderName, itemName, value)
	FolderSyncEvent:FireServer("RequestUpdate", folderName, itemName, value)
end

function ClientFolder.get(userId): ClientData
	local folder = ActiveFolders[userId]
	while not folder do
		task.wait()
		folder = ActiveFolders[userId]
	end
	return folder
end

function ClientFolder.remove(userId)
	ActiveFolders[userId] = nil
end

FolderSyncEvent.OnClientEvent:Connect(function(action, userId, ...)
	if action == "InitPlayer" then
		local data = ...
		ClientFolder.new(userId, data)
	elseif action == "Update" then
		local folderName, itemName, value = ...
		local folder = ClientFolder.get(userId)
		if folder then
			folder:ApplyUpdate(folderName, itemName, value)
		end
	elseif action == "RemovePlayer" then
		ClientFolder.remove(userId)
	end
end)

function ClientFolder:RequestModule(moduleName, action)
	FolderSyncEvent:FireServer('RequestModule', moduleName, action)
end

function ClientFolder:GetData(folderName, statName)
	return self.Data[folderName][statName]
end

return ClientFolder