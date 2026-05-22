return {
	Name = "WipeData";
	Aliases = {"WD"};
	Description = "Wipes the specified player's data.";
	Group = "DefaultAdmin";
	Args = {
		{
			Type = "player";
			Name = "player";
			Description = "The player whose data will be wiped.";
		},
	};
}