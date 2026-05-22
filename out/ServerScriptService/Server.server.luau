local ServerScriptService = game:GetService("ServerScriptService")

local Framework = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('Framework'))

Framework.Boot({
	ServerScriptService.Services
})