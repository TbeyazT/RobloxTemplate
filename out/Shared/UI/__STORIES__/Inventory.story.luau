local ProfileController = require(script.Parent.Parent.Parent:FindFirstChild('Controllers'):FindFirstChild('ProfileController'):FindFirstChild('Client'))
local StoryAdapter = require(script.Parent.Parent:FindFirstChild('StoryAdapter'))
local Inventory = require(script.Parent.Parent:FindFirstChild('Classes'):FindFirstChild('Inventory'))

ProfileController:init()

return StoryAdapter.wrap(Inventory)