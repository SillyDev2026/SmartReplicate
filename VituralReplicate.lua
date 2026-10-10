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
local requestClock = {} -- Fixed two-slot per-player throttle (module/update).
local MIN_MODULE_INTERVAL = 0.10
local MIN_UPDATE_INTERVAL = 0.10
local MAX_REQUEST_PATH = 96

local function allowRequest(player: Player, channel: "module" | "update", interval: number): boolean
    if player.Parent ~= Players then return false end
    local current = os.clock()
    local clock = requestClock[player.UserId]
    if clock == nil then
        clock = {module = -math.huge, update = -math.huge}
        requestClock[player.UserId] = clock
    end
    if current - clock[channel] < interval then return false end
    clock[channel] = current
    return true
end

local function validPath(path: any): boolean
    return type(path) == "string" and #path > 2 and #path <= MAX_REQUEST_PATH
        and path:match("^[%w_]+%.[%w_]+$") ~= nil
end

local function publicSnapshot(data: {[string]: any}): {[string]: any}
    local visible = {}
    for name, folder in pairs(data) do
        if type(folder) == "table" and folder.__sync == "Public" then
            visible[name] = folder
        end
    end
    return visible
end


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
    self.ClientWritable = {} -- Default deny: clients cannot set arbitrary persisted values.
	self.Store = dataStore

	ActiveFolders[player.UserId] = self

	for folderName in pairs(self.Data) do
		self:FireCreated(folderName)
	end

    -- Initial snapshots must not broadcast private fields to other clients.
    -- Send both a public snapshot and an owner-only full snapshot; the client
    -- merges packets if either one arrives first.
    Net:Fire(IDs.InitPlayer.Id, tostring(player.UserId), publicSnapshot(self.Data))
    Net:FireToPlayer(player, IDs.InitPlayer.Id, tostring(player.UserId), self.Data)

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

function PlayerFolder:AllowClientUpdate(path: string, validator: ((any, any) -> boolean)?)
    assert(validPath(path), "Client-writable paths must use Folder.Key")
    assert(validator == nil or type(validator) == "function", "Validator must be a function")
    self.ClientWritable[path] = validator or true
    return self
end

function PlayerFolder:DisallowClientUpdate(path: string)
    self.ClientWritable[path] = nil
    return self
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
	if itemName == "__sync" or itemName:match("__type$") then return end

	local expectedType = folder[itemName .. "__type"]
	if expectedType and typeof(value) ~= expectedType then
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

    assert(mode == "Public" or mode == "Private", "Sync mode must be Public or Private")
    folder.__sync = mode

    for itemName, value in pairs(folder) do
        if itemName ~= "__sync" and not itemName:match("__type$") then
            if mode == "Public" then
                Net:Fire(IDs.Update.Id, tostring(self.Player.UserId), folderName, itemName, value)
            else
                -- Revoke values previously made public on other clients.
                Net:Fire(IDs.Update.Id, tostring(self.Player.UserId), folderName, itemName, nil)
                Net:FireToPlayer(self.Player, IDs.Update.Id, tostring(self.Player.UserId), folderName, itemName, value)
            end
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

Net:Connect(IDs.RequestUpdate.Id, function(player, pathOrFolder, keyOrValue, optionalValue)
    if not allowRequest(player, "update", MIN_UPDATE_INTERVAL) then return end
    local folder = ActiveFolders[player.UserId]
    if folder == nil then return end

    -- Support both documented RequestUpdate("Folder.Key", value) and the
    -- older wire form RequestUpdate("Folder", "Key", value).
    local path = pathOrFolder
    local value = keyOrValue
    if optionalValue ~= nil then
        if type(pathOrFolder) ~= "string" or type(keyOrValue) ~= "string" then return end
        path = pathOrFolder .. "." .. keyOrValue
        value = optionalValue
    end
    if not validPath(path) or value == nil then return end

    local permission = folder.ClientWritable[path]
    if permission == nil then return end
    local folderName, itemName = path:match("^([%w_]+)%.([%w_]+)$")
    local current = folder.Data[folderName]
    if type(current) ~= "table" or current[itemName] == nil then return end
    if itemName == "__sync" or itemName:match("__type$") then return end
    if typeof(value) ~= typeof(current[itemName]) then return end
    if type(value) == "number" and (value ~= value or math.abs(value) == math.huge) then return end
    if type(value) == "table" or type(value) == "userdata" then return end

    if type(permission) == "function" then
        local ok, accepted = pcall(permission, value, current[itemName])
        if not ok or accepted ~= true then return end
    end
    folder:Update(folderName, itemName, value)
end)

Net:Connect(IDs.RequestModule.Id, function(player, moduleName, moduleAction, ...)
    if not allowRequest(player, "module", MIN_MODULE_INTERVAL) then return end
    local folder = ActiveFolders[player.UserId]
    if folder == nil then return end
    if type(moduleName) ~= "string" or type(moduleAction) ~= "string" then return end
    if #moduleName > 60 or #moduleAction > 60 then return end
    local mod = StatsModules[moduleName]
    if type(mod) ~= "table" or type(mod.ClientActions) ~= "table" then return end
    if mod.ClientActions[moduleAction] ~= true then return end
    local callback = mod[moduleAction]
    if type(callback) ~= "function" then return end
    local ok, err = pcall(callback, player, folder, ...)
    if not ok then warn("[SmartReplicate] Client module action failed:", err) end
end)

Players.PlayerRemoving:Connect(function(player)
    requestClock[player.UserId] = nil
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
