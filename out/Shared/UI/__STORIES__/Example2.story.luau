local ProfileController = require(script.Parent.Parent.Parent:FindFirstChild('Controllers'):FindFirstChild('ProfileController'):FindFirstChild('Client'))
local StoryAdapter = require(script.Parent.Parent:FindFirstChild('StoryAdapter'))
local Example = require(script.Parent.Parent:FindFirstChild('Classes'):FindFirstChild('Example2'))

ProfileController:init()

return StoryAdapter.wrap(Example)