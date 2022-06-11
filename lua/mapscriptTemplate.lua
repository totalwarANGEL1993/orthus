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
gvS5cLibPath = "data/maps/externalmap/s5c/";
Script.Load(gvBasePath.. "qsb/loader.lua");

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
    if Folders.Map then
        Score.Player[0] = {};
        Score.Player[0]["buildings"] = 0;
        Score.Player[0]["all"] = 0;

        LoadQuestSystem();
        ActivateDebugMode(true, false, true, true);

        -- Call your code here
    end
end

-- User script -------------------------------------------------------------- --


