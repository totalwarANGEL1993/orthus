-- Default mapscript for Multiplayer.

-- Include globals
Script.Load("data/script/maptools/ai/support.lua");
Script.Load("data/script/maptools/multiplayer/multiplayertools.lua");
Script.Load("data/script/maptools/tools.lua");
Script.Load("data/script/maptools/weathersets.lua");
Script.Load("data/script/maptools/comfort.lua");
Script.Load("data/script/maptools/dynamicfog.lua");
Script.Load("data/script/maptools/extra2comfort.lua");

-- Load QSB
Script.Load(gvBasePath.. "qsb/loader.lua");
Script.Load(gvBasePath.. "qsb/lib/quest/multiplayersystem.lua");

-- Settings ----------------------------------------------------------------- --

function Mission_InitWeatherGfxSets()
    SetupHighlandWeatherGfxSet();
end

function GameCallback_OnGameStart()
    -- Weather
    Mission_InitWeatherGfxSets();
    AddPeriodicSummer(10);

    -- Music 
    LocalMusic.UseSet = HIGHLANDMUSIC;

    -- Multiplayer stuff
    MultiplayerTools.InitCameraPositionsForPlayers();	
    MultiplayerTools.SetUpGameLogicOnMPGameConfig();

    -- Singleplayer
    if not QuestSync or not QuestSync:IsMultiplayerGame() then
		for i=1, 8, 1 do
			MultiplayerTools.DeleteFastGameStuff(i);
		end
		local PlayerID = GUI.GetPlayerID();
		Logic.PlayerSetIsHumanFlag(PlayerID, 1);
        Logic.PlayerSetGameStateToPlaying(PlayerID);
    end

    -- Load quest system
    Score.Player[0] = {};
	Score.Player[0]["buildings"] = 0;
	Score.Player[0]["all"] = 0;
    LoadQuestSystem();
end