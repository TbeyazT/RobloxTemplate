local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)

local Framework = require("@Shared/Framework")

Framework.Boot({
	Shared.Controllers
})