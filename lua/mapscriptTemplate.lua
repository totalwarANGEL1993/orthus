-- ########################################################################## --
-- #  Map name: ???                                                         # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   ???                                                       # --
-- #    Version:  ???                                                       # --
-- ########################################################################## --

-- Include globals
Script.Load("data/script/maptools/main.lua");
Script.Load("data/script/maptools/mapeditortools.lua");

-- Load QSB
local BasePath = "data/maps/externalMap/";
Script.Load(BasePath.. "qsb/oop.lua");
Script.Load(BasePath.. "qsb/questsystem.lua");
Script.Load(BasePath.. "qsb/questdebug.lua");
Script.Load(BasePath.. "qsb/interaction.lua");
Script.Load(BasePath.. "qsb/information.lua");
Script.Load(BasePath.. "qsb/questbehavior.lua");

-- Settings ----------------------------------------------------------------- --

function InitDiplomacy()
    -- Logic.SetDiplomacyState(Player1, Player2, DiplomacyState);
    -- SetPlayerName(Player, Name);
end

function InitResources()
    Tools.GiveResouces(1, 0, 0, 0, 0, 0, 0);
end

function InitTechnologies()
    -- ForbidTechnology(Technology, PlayerID);
end

function InitWeatherGfxSets()
	SetupNormalWeatherGfxSet();
end

function InitPlayerColorMapping()
    -- Display.SetPlayerColor(PlayerID, ColorID);
end

function FirstMapAction()
    Score.Player[0] = {};
	Score.Player[0]["buildings"] = 0;
	Score.Player[0]["all"] = 0;
    
    LoadQuestSystem();
    ActivateDebugMode(true, false, true, true);
    
    
end
