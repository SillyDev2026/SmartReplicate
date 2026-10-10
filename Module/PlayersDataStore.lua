--!strict
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataStoreModule = {}
DataStoreModule.__index = DataStoreModule

local maxRetries = 6
local retryDelay = 0.3
local maxRetryDelay = 4

local function retryAsync(func: ()->any)
	local delayTime = retryDelay
	for i = 1, maxRetries do
		local success, result = pcall(func)
		if success then return result end
		if i < maxRetries then task.wait(delayTime) end
        delayTime = math.min(delayTime * 2, maxRetryDelay)
	end
	error("[DataStoreModule] Failed after max retries")
end

function DataStoreModule.new(config)
	local self = setmetatable({}, DataStoreModule)
	self.DataStore = DataStoreService:GetDataStore(config.Name, config.Scope)
	self.SessionId = HttpService:GenerateGUID(false)
	self.Cache = {} :: {[string]: {Value: any, Expiration: number}}
	self.CacheTTL = 60
	self.LockTTL = 30
	return self
end

-- Cache helpers
function DataStoreModule:_GetFromCache(key: string)
	local entry = self.Cache[key]
	if entry and entry.Expiration > os.time() then
		return entry.Value
	else
		self.Cache[key] = nil
		return nil
	end
end

function DataStoreModule:_SaveToCache(key: string, value: any)
	self.Cache[key] = {
		Value = value,
		Expiration = os.time() + self.CacheTTL
	}
end

function DataStoreModule:_GetLockKey(key: string)
	return key .. "_lock"
end

function DataStoreModule:IsLocked(key: string): boolean
	local lockKey = self:_GetLockKey(key)
	local success, lock = pcall(function()
		return self.DataStore:GetAsync(lockKey)
	end)
	if success and lock then
		return lock.Expiration > os.time()
	else
		return false
	end
end

function DataStoreModule:AcquireLock(key: string): boolean
    local lockKey = self:_GetLockKey(key)
    local success, result = pcall(function()
        return self.DataStore:UpdateAsync(lockKey, function(current)
            local now = os.time()
            if type(current) == "table" and type(current.Expiration) == "number"
                and current.Expiration > now and current.SessionId ~= self.SessionId then
                return nil -- Another server owns this lock.
            end
            return {SessionId = self.SessionId, Expiration = now + self.LockTTL}
        end)
    end)
    -- A successful API call that was cancelled due to an existing lock is
    -- NOT successful acquisition.
    return success and type(result) == "table" and result.SessionId == self.SessionId
end

function DataStoreModule:ReleaseLock(key: string): boolean
	local lockKey = self:_GetLockKey(key)
	local success, _ = pcall(function()
		self.DataStore:UpdateAsync(lockKey, function(current)
			if current and current.SessionId == self.SessionId then
				return nil
			else
				return current
			end
		end)
	end)
	return success
end

function DataStoreModule:GetBudget(BudgetType:Enum.DataStoreRequestType)
	local current = DataStoreService:GetRequestBudgetForRequestType(BudgetType)
	while current < 1 do
		task.wait(5)
		current = DataStoreService:GetRequestBudgetForRequestType(BudgetType)
	end
end

function DataStoreModule:GetAsync(key: string): {}?
	local cached = self:_GetFromCache(key)
	if cached then return cached end

	local data = retryAsync(function()
		local result = self.DataStore:GetAsync(key)
		if result == nil then result = {} end
		return result
	end)

	self:_SaveToCache(key, data)
	return data
end

function DataStoreModule:SetAsync(key: string, data: {}, canBind: boolean?)
    if not canBind then self:GetBudget(Enum.DataStoreRequestType.SetIncrementAsync) end
    local success, err = pcall(function()
        return retryAsync(function()
            return self.DataStore:SetAsync(key, data)
        end)
    end)
    if not success then
        warn("[SmartReplicate] SetAsync failed for key:", key, err)
        return false, err
    end
    self:_SaveToCache(key, data)
    return true, nil
end

function DataStoreModule:UpdateAsync(key: string, callback: (old: {}?) -> {}?, canBind: boolean?)
    if not canBind then self:GetBudget(Enum.DataStoreRequestType.UpdateAsync) end
    local success, result = pcall(function()
        return retryAsync(function()
            return self.DataStore:UpdateAsync(key, callback)
        end)
    end)
    if not success then
        warn("[SmartReplicate] UpdateAsync failed for key:", key, result)
        return false, result
    end
    if result ~= nil then self:_SaveToCache(key, result) end
    return true, result
end

function DataStoreModule:MergeTemplate(template, data)
	data = data or {}
	local function merge(temp, targ)
		for key, value in pairs(temp) do
			if type(value) == "table" then
				if type(targ[key]) ~= "table" then
					targ[key] = {}
				end
				merge(value, targ[key])
			else
				if targ[key] == nil then
					targ[key] = value
				end
			end
		end
	end
	merge(template, data)
	return data
end

function DataStoreModule:CleanData(template, data)
	if type(data) ~= "table" then return {} end
	local function clean(temp, targ)
		for key, value in pairs(targ) do
			if temp[key] == nil then
				targ[key] = nil
			elseif type(temp[key]) == "table" then
				if type(value) == "table" then
					clean(temp[key], value)
				else
					targ[key] = {}
				end
			end
		end
	end
	clean(template, data)
	return data
end

return DataStoreModule