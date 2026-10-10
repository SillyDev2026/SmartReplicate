--!strict
-- Script alongside Folder "Module" containing PlayersDataStore.
-- No real GetAsync/SetAsync/UpdateAsync requests are made to Roblox's backend.
local Backend = require(script.Parent:WaitForChild("Module"):WaitForChild("PlayersDataStore"))
local state = {}
local calls = 0
local fake = {}

function fake:UpdateAsync(key: string, transform: (any) -> any): any
    calls += 1
    local nextValue = transform(state[key])
    if nextValue ~= nil then state[key] = nextValue end
    return nextValue
end

function fake:GetAsync(key: string): any
    return state[key]
end

function fake:SetAsync(key: string, value: any)
    state[key] = value
end

local one = Backend.new({Name = "SmartReplicate_Regression_One"})
local two = Backend.new({Name = "SmartReplicate_Regression_Two"})
one.DataStore = fake
two.DataStore = fake
assert(one:AcquireLock("Profile") == true, "First owner failed to lock")
assert(two:AcquireLock("Profile") == false, "Second owner incorrectly acquired lock")
assert(one:ReleaseLock("Profile"), "First owner failed to release lock")
assert(two:AcquireLock("Profile"), "Second owner could not acquire released lock")
assert(two:ReleaseLock("Profile"), "Second owner failed to release lock")
local ok, value = one:UpdateAsync("Data", function(_old)
    return {Coins = 19}
end, true)
assert(ok and value.Coins == 19 and state.Data.Coins == 19, "UpdateAsync returned before write")
assert(calls >= 5, "Expected mock UpdateAsync calls")
print("SmartReplicate data lock regression PASS")
