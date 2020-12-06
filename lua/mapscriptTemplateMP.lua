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
gvBasePath = "data/maps/externalmap/qsb/";

Script.Load(gvBasePath.. "core/oop.lua");
Script.Load(gvBasePath.. "core/mpsync.lua");
Script.Load(gvBasePath.. "core/questsystem.lua");
Script.Load(gvBasePath.. "core/questdebug.lua");
Script.Load(gvBasePath.. "core/interaction.lua");

Script.Load(gvBasePath.. "lib/libloader.lua");
Script.Load(gvBasePath.. "ext/extraloader.lua");

Script.Load(gvBasePath.. "questbehavior.lua");
Script.Load(gvBasePath.. "treasure.lua");
Script.Load(gvBasePath.. "mpruleset.lua");

-- Settings ----------------------------------------------------------------- --

function GameCallback_OnGameStart()
    -- Weather
    SetupHighlandWeatherGfxSet();
    AddPeriodicSummer(10);

    -- Music 
    LocalMusic.UseSet = HIGHLANDMUSIC;

    -- Multiplayer stuff
    MultiplayerTools.InitCameraPositionsForPlayers();	
    MultiplayerTools.SetUpGameLogicOnMPGameConfig();
    
    -- Singleplayer
    if XNetwork.Manager_DoesExist() == 0 then
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

-- Ruleset ------------------------------------------------------------------ --

MPRuleset_Rules = {
    Resources = {
        -- Amount of resources in resource heaps
        ResourceHeapSize    = 2000,

        -- Choosen resource preset
        Choosen = 1,

        [1] = {
            Gold            = 1000,
            Clay            = 1500,
            Wood            = 1200,
            Stone           = 800,
            Iron            = 50,
            Sulfur          = 50,
        },
        [2] = {
            Gold            = 2000,
            Clay            = 3500,
            Wood            = 2400,
            Stone           = 1600,
            Iron            = 800,
            Sulfur          = 800,
        },
        [3] = {
            Gold            = 5000,
            Clay            = 8000,
            Wood            = 8000,
            Stone           = 5000,
            Iron            = 5000,
            Sulfur          = 5000,
        },
    },

    Timer = {
        -- Peacetime in minutes (0 = off)
        Peacetime           = 20,

        -- Minutes until everyone loses (0 = off)
        DeathPenalty        = 0,
    },

    Commandment = {
        -- Crush building glitch fixed. Buildings will deselect the building
        -- and then destroy it right away without warning. (0 = off)
        CrushBuilding       = 1,

        -- Formation tech fix (0 = off)
        -- Formations will only require GT_StandingArmy researched and not 
        -- GT_Tactics to also be allowed.
        Formaition          = 1,

        -- Associate village centers to players (0 = off)
        -- Give sequential names to village centers for each player. Players
        -- can not build village centers expect there where they allowed to.
        -- Example: (P1VC1, P1VC2, ..)
        AssociateVillages   = 0,

        -- Block HQ rush (0 = off)
        -- Player HQs can not be damaged until the player has village
        -- centers left.
        HQRushBlock         = 1,

        -- Bridges can not be destroyed (0 = off)
        InvincibleBridges   = 1,

        -- Control worker amount in workplaces (0 = off)
        Workplace           = 1,

        -- Minutes the weather can not be changed again after a change was
        -- triggered by the weather tower.
        WeatherChangeDelay  = 3,

        -- Minutes a player must wait between two blesses.
        BlessDelay          = 3,
    },

    Limits = {
        -- Limit of heroes the player can buy
        Hero         = 3,

        -- Building Limit  (-1 = off)
        Market       = 1,
        Tower        = 5,
        University   = -1,
        Village      = -1,

        -- Unit limits (-1 = off)
        Bow          = -1,
        LightCavalry = -1,
        HeavyCavalry = -1,
        Rifle        = -1,
        Spear        = -1,
        Serf         = -1,
        Scout        = -1,
        Sword        = -1,
        Thief        = -1,

        -- vehicle limit (-1 = off)
        Cannon1      = -1,
        Cannon2      = -1,
        Cannon3      = -1,
        Cannon4      = -1,
    },

    -- Heroes available (0 = forbidden)
    Heroes = {
        Dario               = 1,
        Pilgrim             = 1,
        Salim               = 1,
        Erec                = 1,
        Ari                 = 1,
        Helias              = 1,
        Drake               = 1,
        Yuki                = 1,
        -- ---------- --
        Varg                = 1,
        Kerberos            = 1,
        Mary                = 1,
        Kala                = 1,
    },

    Technologies = {
        -- Gunsmith technologies
        Gunsmith            = {
            Rifle           = 2, -- Weapons branch (0 to 2)
            Armor           = 2, -- Armor branch (0 to 2)
        },

        -- Laboratory technologies
        Laboratory          = {
            Cannon          = 2, -- Cannon branch (0 to 2)
            Weather         = 2, -- Weather branch (0 to 2)
        },

        -- Masory technologies
        Masory              = {
            Walls           = 1, -- Building defence
        },

        Sawmill             = {
            Spearmen        = 2, -- Sear branch (0 to 2)
            Bowmen          = 2, -- Bow branch (0 to 2)
        },

        -- Smith technologies
        Smith               = {
            Light           = 3, -- Light armor branch (0 to 3)
            Heavy           = 3, -- Heavy armor branch (0 to 3)
            Weapons         = 2, -- Weapon branch (0 to 2)
        },

        -- University technologies
        University          = {
            Construction    = 4, -- Construction branch (0 to 4)
            Civil           = 4, -- Civil branch (0 to 4)
            Industrial      = 4, -- Industrial branch (0 to 4)
            Millitary       = 4, -- Millitary branch (0 to 4)
            Addon           = 4, -- Addon branch (0 to 4)
        },

        Village             = {
            Civil           = 3, -- Village center (0 to 3)
        }
    },

    Callbacks = {
        -- After configuration has been loaded
        OnMapConfigured = function()
        end,

        -- After peacetime ended (no peacetime means immediate execution after
        -- configuration is loaded)
        OnPeacetimeOver = function()
        end,
    },
};

-- User script -------------------------------------------------------------- --


