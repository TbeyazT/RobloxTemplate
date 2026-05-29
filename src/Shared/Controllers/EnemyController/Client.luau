local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require("../../Net")
local Utils = require("./Utils")

local ReplicatedFolder = ReplicatedStorage:WaitForChild("RealCH12AbominationCrazyStuffForPeopleSelfishnessofthem",10)

local EnemyController = {
	ActiveEnemies = {}
}

function EnemyController:Init()
	Net.ReplicateEnemy.SetCallback(function(Value: { ID: string, Name: string, Position: Vector3 })
        self:ReplicateEnemy(Value)
    end)
end

function EnemyController:ReplicateEnemy(data)
	local enemyProperty = Utils:GetEnemyProperties(data.Name)
	if not enemyProperty then return end

	local clientModule = ReplicatedFolder:WaitForChild(data.Name, 5)
	if not clientModule then
		warn("[EnemyController] Failed to find replicated client module for enemy: " .. tostring(data.Name))
		return
	end

	local success, clientClass = pcall(function()
		return require(clientModule)
	end)

	if success and typeof(clientClass) == "table" and typeof(clientClass.new) == "function" then
		local enemyInstance = clientClass.new(data)
		self.ActiveEnemies[data.ID] = enemyInstance
	else
		if not success then
			warn("[EnemyController] Failed to require client class for " .. tostring(data.Name) .. ":", clientClass)
		end
	end
end

function EnemyController:DestroyEnemy(enemyID: string)
	local enemyInstance = self.ActiveEnemies[enemyID]
	if enemyInstance then
		if typeof(enemyInstance.Destroy) == "function" then
			enemyInstance:Destroy()
		elseif typeof(enemyInstance.destroy) == "function" then
			enemyInstance:destroy()
		end
		self.ActiveEnemies[enemyID] = nil
	end
end

return EnemyController