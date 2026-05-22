debug.setmemorycategory(script.Name .. " Client")
--[[
    ProfileClient
    Client-side data cache and bridge. Interacts with the server via Zap.
]]
-------------------------- Dependencies --------------------------
local Players = game:GetService("Players")

local Promise = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Promise'))
local Signal  = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Signal'))
local Trove   = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Trove'))
local Net     = require(script.Parent.Parent.Parent:FindFirstChild('Net'))

local LocalPlayer = Players.LocalPlayer
-------------------------- Types --------------------------
type Connection = { Disconnect: (self: any) -> () }
type Callback   = (newValue: any, oldValue: any?) -> ()

export type ProfileData = {
    [string]: any,
}
-------------------------- Controller --------------------------
local ProfileClient = {
    LoadOrder = 1,

    _trove          = nil :: any,   -- Trove
    
    -- Storing data per-player
    _data           = {} :: { [Player]: ProfileData },
    _isLoaded       = {} :: { [Player]: boolean },
    _loadedSignals  = {} :: { [Player]: any }, -- Signals, fired once per player
    _signals        = {} :: { [Player]: { [string]: any } }, -- per-player, per-key signals
}

-------------------------- Lifecycle --------------------------
function ProfileClient:init()
    self._trove = Trove.new()

    -- Clean up memory when a player leaves
    self._trove:Connect(Players.PlayerRemoving, function(player)
        self:_cleanupPlayer(player)
    end)

    -- Initial full payload (Server must send { Player = player, Data = fullData })
    Net.DataLoaded.SetCallback(function(payload)
        local player = payload.Player
        local fullData = payload.Data

        self._data[player] = fullData
        self._isLoaded[player] = true
        self:_getLoadedSignal(player):Fire()

        if self._signals[player] then
            for key, signal in self._signals[player] do
                if fullData[key] ~= nil then
                    signal:Fire(fullData[key], nil)
                end
            end
        end
    end)

    Net.DataUpdated.On(function(payload)
        local player = payload.Player
        local key = payload.Key
        local newValue = payload.Value

        if not self._isLoaded[player] then return end

        local oldValue = self._data[player][key]
        self._data[player][key] = newValue

        if self._signals[player] and self._signals[player][key] then
            self._signals[player][key]:Fire(newValue, oldValue)
        end
    end)
end

function ProfileClient:Destroy()
    if self._trove then
        self._trove:Destroy()
        self._trove = nil :: any
    end
    
    table.clear(self._data)
    table.clear(self._isLoaded)
    table.clear(self._loadedSignals)
    table.clear(self._signals)
end

-------------------------- Private --------------------------
function ProfileClient:_getLoadedSignal(player: Player): any
    if not self._loadedSignals[player] then
        self._loadedSignals[player] = self._trove:Add(Signal.new())
    end
    return self._loadedSignals[player]
end

function ProfileClient:_getSignal(player: Player, key: string): any
    if not self._signals[player] then
        self._signals[player] = {}
    end
    if not self._signals[player][key] then
        self._signals[player][key] = self._trove:Add(Signal.new())
    end
    return self._signals[player][key]
end

function ProfileClient:_cleanupPlayer(player: Player)
    self._data[player] = nil
    self._isLoaded[player] = nil
    
    if self._loadedSignals[player] then
        self._loadedSignals[player]:Destroy()
        self._loadedSignals[player] = nil
    end
    
    if self._signals[player] then
        for _, signal in self._signals[player] do
            signal:Destroy()
        end
        self._signals[player] = nil
    end
end

-------------------------- Public API --------------------------
function ProfileClient:IsLoaded(playerOpt: Player?): boolean
    local player = playerOpt or LocalPlayer
    return self._isLoaded[player] == true
end

--[[
    Returns a Promise that resolves with the value at `key`.
    Wait for data to load if not available.
    
    Usage: 
        ProfileClient:Get("Cash") -- Gets LocalPlayer cash
        ProfileClient:Get("Cash", TargetPlayer) -- Gets TargetPlayer cash
]]
function ProfileClient:Get(key: string, playerOpt: Player?): any -- Promise<any>
    local player = playerOpt or LocalPlayer

    return Promise.new(function(resolve, reject)
        local function read()
            resolve(self._data[player][key])
        end

        if self._isLoaded[player] then
            read()
            return
        end

        local conn
        conn = self:_getLoadedSignal(player):Connect(function()
            conn:Disconnect()
            read()
        end)

        task.delay(15, function()
            if conn.Connected then
                conn:Disconnect()
                warn(player,key)
                reject(string.format("Timeout: ProfileData never loaded for player %s, key '%s'.", player.Name, key))
            end
        end)
    end)
end

--[[
    Subscribes to changes on `key`.
    
    Usage:
        ProfileClient:Observe("Cash", function(...) end)
        ProfileClient:Observe("Cash", function(...) end, TargetPlayer)
]]
function ProfileClient:Observe(key: string, callback: Callback, playerOpt: Player?): Connection
    local player = playerOpt or LocalPlayer
    local signal = self:_getSignal(player, key)
    local conn   = signal:Connect(callback)

    if self._isLoaded[player] and self._data[player][key] ~= nil then
        task.spawn(callback, self._data[player][key], nil)
    end

    return conn
end

--[[
    Waits for data to be loaded, then calls callback once with the full data table.
    
    Usage:
        ProfileClient:OnReady(function(data) end)
        ProfileClient:OnReady(function(data) end, TargetPlayer)
]]
function ProfileClient:OnReady(callback: (data: ProfileData) -> (), playerOpt: Player?): Connection
    local player = playerOpt or LocalPlayer

    if self._isLoaded[player] then
        task.spawn(callback, self._data[player])
        return { Disconnect = function() end }
    end

    local conn
    conn = self:_getLoadedSignal(player):Connect(function()
        conn:Disconnect()
        callback(self._data[player])
    end)
    return conn
end

-------------------------- Server Calls --------------------------
function ProfileClient:ChangeSetting(key: string): any 
    return Promise.resolve(Net.ChangeSetting.Call(key))
end

function ProfileClient:ClaimGroupReward(): any 
    return
end

function ProfileClient:ClaimWelcomeReward(): any 
    return
end

function ProfileClient:EditTutorial(key: string, value: any)
    Net.EditTutorial.Call({ Key = key, Value = value })
end

function ProfileClient:Rebirth(isSkipped: boolean): any 
    return Promise.resolve(Net.Rebirth.Call(isSkipped))
end

-------------------------- UI Labs / Testing --------------------------
--[[
    Usage:
        ProfileClient:Mock({ Cash = 100 })
        ProfileClient:Mock({ Cash = 100 }, TargetPlayer)
]]
function ProfileClient:Mock(mockData: ProfileData, playerOpt: Player?)
    local player = playerOpt or LocalPlayer

    self._data[player] = mockData
    self._isLoaded[player] = true
    self:_getLoadedSignal(player):Fire()

    if self._signals[player] then
        for key, signal in self._signals[player] do
            if mockData[key] ~= nil then
                signal:Fire(mockData[key], nil)
            end
        end
    end
end

--[[
    Usage:
        ProfileClient:MockUpdate("Cash", 200)
        ProfileClient:MockUpdate("Cash", 200, TargetPlayer)
]]
function ProfileClient:MockUpdate(key: string, newValue: any, playerOpt: Player?)
    local player = playerOpt or LocalPlayer

    if not self._isLoaded[player] or not self._data[player] then return end

    local oldValue = self._data[player][key]
    self._data[player][key] = newValue

    if self._signals[player] and self._signals[player][key] then
        self._signals[player][key]:Fire(newValue, oldValue)
    end
end

return ProfileClient