local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:FindFirstChild("Assets")

local Net = require("../../Constants/Net")
local Utils = require("./Utils")

local EnemyService = {
    Classes = {}
}

function EnemyService:Init()
    task.wait(10)

    self:SpawnEnemy({
        Name = "CH12"
    })
end

function EnemyService:SpawnEnemy(data)
    local EnemyProperty = Utils:GetEnemyProperties(data.Name)

    if not EnemyProperty then return end

    local spawnPoint:Vector3
    local area = workspace:FindFirstChild("EnemieSpawnpoints")
    if area then
        area = area:FindFirstChild(EnemyProperty.Area)
        if area then
            local children = area:GetChildren()
            if #children > 0 then
                local randomSpawn = children[math.random(1,#children)]
                if randomSpawn then
                    spawnPoint = (randomSpawn.CFrame * CFrame.new(
                        (math.random()-0.5)*randomSpawn.Size.X,
                        randomSpawn.Size.Y/2,
                        (math.random()-0.5)*randomSpawn.Size.Z
                    ))
                end
            end
        end
    end

    local success, serverScript = pcall(function(...)
        return require("../../Enemies/"..data.Name.."/Server")
    end)

    if success and typeof(serverScript) == "table" and typeof(serverScript.new) == "function" then
        local enemyClass = serverScript.new()
        self.Classes[enemyClass.ID] = enemyClass
        local ClassesFolder = script.Parent.Parent.Parent.Enemies:FindFirstChild(data.Name)
        if ClassesFolder then
            local clientScript = ClassesFolder:FindFirstChild("Client")
            if clientScript then
                clientScript = clientScript:Clone()
                clientScript.Name = data.Name
                clientScript.Parent = ReplicatedStorage.RealCH12AbominationCrazyStuffForPeopleSelfishnessofthem
                Net.ReplicateEnemy.FireAll({
                    ID = enemyClass.ID,
                    Name = data.Name,
                    Position = spawnPoint
                })
                Debris:AddItem(clientScript,1)
            end
        end
    else
        if not success then
            warn("Failed to require server script for enemy " .. data.Name .. ":", serverScript)
        end
    end
end

return EnemyService