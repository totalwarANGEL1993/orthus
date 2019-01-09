-- ########################################################################## --
-- #  Map name: ???                                                         # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   ???                                                       # --
-- #    Version:  ???                                                       # --
-- ########################################################################## --

-- Include globals
Script.Load("data/script/maptools/main.lua");
Script.Load("data/script/maptools/mapeditortools.lua");

-- Load base
Script.Load("data/maps/externalMap/qsb/oop.lua");
Script.Load("data/maps/externalMap/qsb/questsystem.lua");
Script.Load("data/maps/externalMap/qsb/questdebug.lua");
-- load library
Script.Load("data/maps/externalMap/qsb/interaction.lua");
Script.Load("data/maps/externalMap/qsb/information.lua");
Script.Load("data/maps/externalMap/qsb/questbehavior.lua");

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
    
    QuestSystemBehavior:PrepareQuestSystem();
    QuestSystemDebug:Activate(true, true, true, false);
    
    
end
