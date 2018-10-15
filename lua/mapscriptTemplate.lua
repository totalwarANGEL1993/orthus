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

-- Debug
UseQuestTrace = false;
UseDebugCheats = true;
UseDebugShell = true;
UseCheckQuests = true;

-- Start resources for the human player
local GoldAmount   = 0;
local ClayAmount   = 0;
local WoodAmount   = 0;
local StoneAmount  = 0;
local IronAmount   = 0;
local SulfurAmount = 0;

-- Weather set to use
local WeatherSet = "SetupNormalWeatherGfxSet";

-- Player declaration
local DiplomacyStates = {
    -- Example:
    -- [1] = {"Spieler", Diplomacy.Neutral}
};

-- Forbid technologies for the human player
local TechnologiesToForbid = {
    -- Example:
    -- Technologies.GT_PulledBarrel
};

-- Player colors
local PlayerColors = {
    -- Example:
    -- [1] = KERBEROS_COLOR
};

-- Quests ------------------------------------------------------------------- --

--
-- Declare your quests in this function.
--
function CreateQuests()

end

-- Base functions ----------------------------------------------------------- --

function InitDiplomacy()
    for k, v in pairs(DiplomacyStates) do
        if k > 1 then
            Logic.SetDiplomacyState(1, k, v[2]);
        end
        SetPlayerName(k, v[1]);
    end
end

function InitResources()
    Tools.GiveResouces(1, GoldAmount, ClayAmount, WoodAmount, StoneAmount, IronAmount, SulfurAmount);
end

function InitTechnologies()
    for k, v in pairs(TechnologiesToForbid) do
        ForbidTechnology(v, 1);
    end
end

function InitWeatherGfxSets()
	_G[WeatherSet]();
end

function InitPlayerColorMapping()
    for k, v in pairs(PlayerColors) do
        Display.SetPlayerColor(k, v);
    end
end

function FirstMapAction()
    Score.Player[0] = {};
	Score.Player[0]["buildings"] = 0;
	Score.Player[0]["all"] = 0;
    
    QuestSystemBehavior:PrepareQuestSystem();
    if UseQuestTrace or UseDebugCheats or UseDebugShell or UseCheckQuests then
        QuestSystemDebug:Activate(UseCheckQuests, UseDebugCheats, UseDebugShell, UseQuestTrace);
    end
    CreateQuests();
end