-- ########################################################################## --
-- #  Map name: ???                                                         # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   ???                                                       # --
-- #    Version:  ???                                                       # --
-- ########################################################################## --

-- Include globals
Script.Load("data/script/maptools/main.lua");
Script.Load("data/script/maptools/ai/support.lua");
Script.Load("data/script/maptools/multiplayer/multiplayertools.lua");
Script.Load("data/script/maptools/tools.lua");
Script.Load("data/script/maptools/weathersets.lua");
Script.Load("data/script/maptools/comfort.lua");
Script.Load("data/script/maptools/mapeditortools.lua");

-- Load QSB
gvBasePath = "data/maps/externalmap/";
Script.Load(gvBasePath.. "qsb/oop.lua");
Script.Load(gvBasePath.. "qsb/mpsync.lua");
Script.Load(gvBasePath.. "qsb/questsystem.lua");
Script.Load(gvBasePath.. "qsb/questdebug.lua");
Script.Load(gvBasePath.. "qsb/interaction.lua");
Script.Load(gvBasePath.. "qsb/questbehavior.lua");
Script.Load(gvBasePath.. "qsb/mpruleset.lua");
Script.Load(gvBasePath.. "qsb/extraloader.lua");

-- Settings ----------------------------------------------------------------- --

function Mission_InitMap()
    -- Change hero amount here
    local MaxAmountHeroes = 3;

    -- Weather
    SetupHighlandWeatherGfxSet();
    AddPeriodicSummer(10);

    -- Music 
    LocalMusic.UseSet = HIGHLANDMUSIC;

    -- Multiplayer stuff
    MultiplayerTools.InitCameraPositionsForPlayers();	
	MultiplayerTools.SetUpGameLogicOnMPGameConfig();
    MultiplayerTools.GiveBuyableHerosToHumanPlayer(MaxAmountHeroes);
end

function Mission_InitSingleplayer()
    if XNetwork ~= nil and XNetwork.Manager_DoesExist() == 0 then
		for i=1, 8, 1 do
			MultiplayerTools.DeleteFastGameStuff(i);
		end
		local PlayerID = GUI.GetPlayerID();
		Logic.PlayerSetIsHumanFlag(PlayerID, 1);
        Logic.PlayerSetGameStateToPlaying(PlayerID);
    end
end

function Mission_StartQuestSystemBehavior()
    Score.Player[0] = {};
	Score.Player[0]["buildings"] = 0;
	Score.Player[0]["all"] = 0;
    LoadQuestSystem();
end

function GameCallback_OnGameStart()
    Mission_InitMap();
    Mission_InitSingleplayer();
    Mission_StartQuestSystemBehavior();
    
    -- Call your code here
end

-- User script -------------------------------------------------------------- --


