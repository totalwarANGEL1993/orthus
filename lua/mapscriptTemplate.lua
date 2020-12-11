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
gvBasePath = "data/maps/externalmap/qsb/";

Script.Load(gvBasePath.. "lib/libloader.lua");
Script.Load(gvBasePath.. "core/mpsync.lua");
Script.Load(gvBasePath.. "core/bugfixes.lua");
Script.Load(gvBasePath.. "core/questsystem.lua");
Script.Load(gvBasePath.. "core/questdebug.lua");

Script.Load(gvBasePath.. "ext/extraloader.lua");

Script.Load(gvBasePath.. "questbehavior.lua");
Script.Load(gvBasePath.. "treasure.lua");

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
    
    -- Call your code here
end

-- User script -------------------------------------------------------------- --


