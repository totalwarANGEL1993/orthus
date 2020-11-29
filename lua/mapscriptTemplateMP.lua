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
gvBasePath = "data/maps/externalMap/";
Script.Load(gvBasePath.. "qsb/oop.lua");
Script.Load(gvBasePath.. "qsb/mpsync.lua");
Script.Load(gvBasePath.. "qsb/questsystem.lua");
Script.Load(gvBasePath.. "qsb/questdebug.lua");
Script.Load(gvBasePath.. "qsb/interaction.lua");
Script.Load(gvBasePath.. "qsb/questbehavior.lua");
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

function Mission_InitResources()
    local Gold 	 = 500;
	local Clay 	 = 800;
	local Wood 	 = 500;
	local Stone  = 500;
	local Iron 	 = 500;
    local Sulfur = 250;
    if XNetwork ~= nil and XNetwork.Manager_DoesExist() == 1 then
        local Players = XNetwork.GameInformation_GetMapMaximumNumberOfHumanPlayer();
        for i= 1, Players, 1 do
            Tools.GiveResouces(i, Gold, Clay, Wood, Stone, Iron, Sulfur);
        end
    else
        Tools.GiveResouces(1, Gold, Clay, Wood, Stone, Iron, Sulfur);
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
    Mission_InitResources();
    Mission_StartQuestSystemBehavior();

    -- TODO: Call MP rule script here
    
    -- Call your code here
end

-- User script -------------------------------------------------------------- --


