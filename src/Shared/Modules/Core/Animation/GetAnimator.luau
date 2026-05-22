return function(model:Model)
    local animator = nil

    local animationController = model:FindFirstChildWhichIsA("AnimationController",true)
    if not animationController then
        local humanoid = model:FindFirstChildWhichIsA("Humanoid",true)
        if humanoid then
            animator = humanoid:FindFirstChildWhichIsA("Animator",true)
        end
    else
        animator = animationController:FindFirstChildWhichIsA("Animator",true)
    end

    return animator
end