return {
	Name = "Dex";
	Aliases = {"dex", "explorer", "dexexplorer"};
	Description = "Gives Dex Explorer to the specified player.";
	Group = "DefaultAdmin";
	Args = {
		{
			Type = "player";
			Name = "player";
			Description = "The target player to receive Dex Explorer.";
		},
	};
}