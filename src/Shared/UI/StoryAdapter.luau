--!strict
local StoryAdapter = {}

local ReactRoblox = require("@Pckgs/ReactRoblox")
local ProfileService = require("@Shared/Controllers/ProfileController/Client")

type ReactNode = any

type UIModuleRef = { 
    Init: ((self: any) -> ())?,
    Render: ((self: any) -> ReactNode)?,
    Destroy: ((self: any) -> ())?,
    [string]: any
}

function StoryAdapter.wrap(module: UIModuleRef)
    return function(target: Instance)
        if typeof(target) == "Instance" then
            local root: any = nil

            local initFunc = module.Init
            if type(initFunc) == "function" then
                initFunc(module)
            end

            local renderFunc = module.Render
            if type(renderFunc) == "function" then
                local element = renderFunc(module)
                if element then
                    xpcall(function()
                        root = ReactRoblox.createRoot(target)
                        root:render(element)
                    end, function(err)
                        warn("[StoryAdapter] ❌ React Render Error: " .. tostring(err))
                    end)
                end
            end

            return function()
                if root then
                    xpcall(function()
                        root:unmount()
                    end, function(err)
                        warn("[StoryAdapter] ❌ React Unmount Error: " .. tostring(err))
                    end)
                end

                local destroyFunc = module.Destroy
                if type(destroyFunc) == "function" then
                    destroyFunc(module)
                end
                
                ProfileService:Destroy()
            end
        end
        return function() end
    end
end

return StoryAdapter