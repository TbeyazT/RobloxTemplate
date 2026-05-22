opt server_output = "ServerScriptService/Net.luau"
opt client_output = "Shared/Net.luau"

event DataLoaded = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Player: Instance,
        Data: map { [string.utf8]: unknown }
    }
}

event DataUpdated = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Player: Instance,
        Key: string.utf8,
        Value: unknown
    }
}

event PlayAudio = {
    from: Server,
    call: SingleAsync,
    data: struct {
        SoundName: string.utf8,
        properties: unknown
    }
}

event Notify = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Text: string.utf8,
        Duration: f32,
        TextColor: Color3?,
        FrameScale: f32?,
        UseRichAnimation: boolean?
    }
}

funct ChangeSetting = {
    call: Async,
    args: string.utf8,
    rets: boolean
}

funct EditTutorial = {
    call: Async,
    args: struct {
        Key: string.utf8,
        Value: unknown
    }
}

funct Rebirth = {
    call: Async,
    args: boolean,
    rets: unknown
}
--brainrot
event AssignBrainrot = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        ID: string.utf8,
        plotNumber: unknown
    }
}

event UnassignBrainrot = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        ID: string.utf8
    }
}

funct ClaimBrainrotCash = {
    call: Async,
    args: struct {
        ID: string.utf8
    },
    rets: struct {
        Success: boolean,
        Amount: u32
    }
}

funct UpgradeBrainrot = {
    call: Async,
    args: string.utf8,
    rets:string.utf8
}

--plot
event PlotAssigned = {
    from: Server,
    type: Reliable,
    call: ManyAsync, 
    data: struct {
        UserId: f64,
        PlotCFrame: CFrame
    }
}

event PlotRemoved = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        UserId: f64
    }
}

event BuyBaseUpgrade = {
    from: Client,
    type:Reliable,
    call: SingleAsync,
}
--food
funct StartEatingFood = {
    call: Async,
    args: string.utf8,
    rets: boolean
}

event StopEatingFood = {
    from: Client,
    type: Reliable,
    call: SingleAsync
}

event FoodInitialData = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        ID: string.utf8,
        Name: string.utf8,
        Capacity: f64,
        MaxCapacity: f64,
        CFrame: CFrame,
        Eater: Instance?
    }[]
}

event FoodSpawned = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        ID: string.utf8,
        Name: string.utf8,
        Capacity: f64,
        MaxCapacity: f64,
        CFrame: CFrame,
        Eater: Instance?
    }
}

event FoodDespawned = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        ID: string.utf8
    }
}

event FoodCapacityUpdated = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        ID: string.utf8,
        Capacity: f64
    }[]
}

event FoodEaterUpdated = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        ID: string.utf8,
        Eater: Instance?
    }
}

--wall stuff
event HitWall = {
    from: Client,
    type: Reliable,
    call: SingleAsync
}

event WallDamaged = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        WallName: string.utf8,
        Durability: f64,
        Max: f64
    }
}

event WallDestroyed = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        WallName: string.utf8
    }
}

event WallRepaired = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        WallName: string.utf8
    }
}

event GrabBrainrot = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        ID: string.utf8
    }
}

event WorldBrainrotInitialData = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        ID: string.utf8,
        Name: string.utf8,
        CFrame: CFrame,
        DespawnTime: f64,
        AreaID: unknown
    }[]
}

event WorldBrainrotSpawned = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        ID: string.utf8,
        Name: string.utf8,
        CFrame: CFrame,
        DespawnTime: f64,
        AreaID: unknown
    }
}

event WorldBrainrotDespawned = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        ID: string.utf8
    }
}

event PlayerCarryingBrainrot = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Player: Instance,
        CarriedList: string.utf8[]
    }
}

event PlayerDroppedBrainrot = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Player: Instance
    }
}

event DropBrainrot = {
    from: Client,
    type: Reliable,
    call: ManyAsync,
}

--product
event PromptProduct = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: string.utf8,
}
--STATS
event UpgradePlayerStat = {
    from:Client,
    type:Reliable,
    call:SingleAsync,
    data: struct {
        StatName: string.utf8,
        Amount: u32
    }
}