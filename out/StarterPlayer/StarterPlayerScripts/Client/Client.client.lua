local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)

local Framework = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('Framework'))

Framework.Boot({
	Shared.Services
})