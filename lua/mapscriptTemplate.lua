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
gvBasePath = "data/maps/externalMap/";
Script.Load(gvBasePath.. "qsb/md5.lua");
Script.Load(gvBasePath.. "qsb/s5hook_ex2.lua");
Script.Load(gvBasePath.. "qsb/oop.lua");
Script.Load(gvBasePath.. "qsb/mpsync.lua");
Script.Load(gvBasePath.. "qsb/questsystem.lua");
Script.Load(gvBasePath.. "qsb/questdebug.lua");
Script.Load(gvBasePath.. "qsb/interaction.lua");
Script.Load(gvBasePath.. "qsb/questbehavior.lua");
Script.Load(gvBasePath.. "qsb/mpruleset.lua");
Script.Load(gvBasePath.. "qsb/extraloader.lua");

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


