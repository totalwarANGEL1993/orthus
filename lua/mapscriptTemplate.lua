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
gvBasePath = "data/maps/externalmap/";

Script.Load(gvBasePath.. "qsb/core/oop.lua");
Script.Load(gvBasePath.. "qsb/core/questtools.lua");
Script.Load(gvBasePath.. "qsb/core/questsync.lua");
Script.Load(gvBasePath.. "qsb/core/bugfixes.lua");
Script.Load(gvBasePath.. "qsb/core/questsystem.lua");
Script.Load(gvBasePath.. "qsb/core/questbriefing.lua");
Script.Load(gvBasePath.. "qsb/core/questdebug.lua");

Script.Load(gvBasePath.. "qsb/lib/libloader.lua");
Script.Load(gvBasePath.. "qsb/ext/extraloader.lua");

Script.Load(gvBasePath.. "qsb/questbehavior.lua");
Script.Load(gvBasePath.. "qsb/treasure.lua");

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
    -- Display.SetPlayerColorMapping(PlayerID, ColorID);
end

function FirstMapAction()
    Score.Player[0] = {};
	Score.Player[0]["buildings"] = 0;
	Score.Player[0]["all"] = 0;
    
    LoadQuestSystem();
    ActivateDebugMode(true, false, true, true);
    
    -- Call your code here
end

-- User script -------------------------------------------------------------- --


