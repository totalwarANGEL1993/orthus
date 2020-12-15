-- Default mapscript for Multiplayer.

-- Include globals
Script.Load("data/script/maptools/main.lua");
Script.Load("data/script/maptools/ai/support.lua");
Script.Load("data/script/maptools/multiplayer/multiplayertools.lua");
Script.Load("data/script/maptools/tools.lua");
Script.Load("data/script/maptools/weathersets.lua");
Script.Load("data/script/maptools/comfort.lua");
Script.Load("data/script/maptools/mapeditortools.lua");

-- Load QSB
Script.Load(gvBasePath.. "core/oop.lua");
Script.Load(gvBasePath.. "core/questtools.lua");
Script.Load(gvBasePath.. "core/mpsync.lua");
Script.Load(gvBasePath.. "core/bugfixes.lua");
Script.Load(gvBasePath.. "core/questsystem.lua");
Script.Load(gvBasePath.. "core/questdebug.lua");

Script.Load(gvBasePath.. "lib/libloader.lua");
Script.Load(gvBasePath.. "ext/extraloader.lua");

Script.Load(gvBasePath.. "questbehavior.lua");
Script.Load(gvBasePath.. "multiplayersystem.lua");
Script.Load(gvBasePath.. "treasure.lua");

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
    if not MPSync or not MPSync:IsMultiplayerGame() then
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