local ProfileController = require("@Shared/Controllers/ProfileController/Client")
local StoryAdapter = require("../StoryAdapter")
local Example = require("../Classes/Example")

ProfileController:init()

return StoryAdapter.wrap(Example)