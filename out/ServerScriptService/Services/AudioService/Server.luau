local Players           = game:GetService("Players")

local Dumpster = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Dumpster'))
local Net = require(game:GetService('ServerScriptService'):FindFirstChild('Net'))

local AudioService = {}

function AudioService:init()
    self._dumpster = Dumpster.new()
    task.spawn(function()
        Players.PlayerAdded:Connect(function(player)
            task.wait(5)
            self:PlaySound(player, "StageComplete", {Volume = 0.5})
        end)
    end)
end

function AudioService:PlaySound(player, soundName, properties)
    Net.PlayAudio.Fire(player, {
        SoundName = soundName,
        Properties = properties
    })
end

function AudioService:PlaySoundAll(soundName, properties)
    Net.PlayAudio.FireAll({
        SoundName = soundName,
        Properties = properties
    })
end

return AudioService