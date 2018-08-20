-- ########################################################################## --
-- #  Main Map Script                                                       # --
-- #  --------------------------------------------------------------------  # --
-- #    Mapname: ##MAP_NAME## # --
-- #    Author:  ##MAP_AUTHOR## # --
-- ########################################################################## --

function InitDiplomacy()
    -- Add player to diplomacy menu
    local PlayersToSet = {##MISSION_ADD_PLAYER##};
    for k, v in pairs(PlayersToSet) do
        Logic.SetDiplomacyState(1, v[1], v[3]);
        SetPlayerName(v[1], v[2]);
    end
end

function InitResources()
    -- Set start resources of human player
    local Gold   = ##START_GOLD_AMOUNT##;
    local Clay   = ##START_CLAY_AMOUNT##;
    local Wood   = ##START_WOOD_AMOUNT##;
    local Stone  = ##START_STONE_AMOUNT##;
    local Iron   = ##START_IRON_AMOUNT##;
    local Sulfur = ##START_SULFUR_AMOUNT##;
    Tools.GiveResouces(1, Gold, Clay, Wood, Stone, Iron, Sulfur);
end

function InitTechnologies()
    -- Forbid technologies for the player
    local TechsToForbid = {##START_FORBID_TECHS##};
    for k, v in pairs(TechsToForbid) do
        ForbidTechnology(v);
    end
    -- Research technologies for the player
    local TechsToResearch = {##START_RESEARCH_TECHS##};
    for k, v in pairs(TechsToResearch) do
        ResearchTechnology(v);
    end
end

function InitWeatherGfxSets()
	SetupNormalWeatherGfxSet();
end

function InitPlayerColorMapping()
    local SetPlayerCollors = {##START_SET_COLORS##};
    for k, v in pairs(SetPlayerCollors) do
        -- TBA
    end
end

function FirstMapAction()
    -- Activate debug mode
    local UseQuestTrade = ##QUEST_TRACE## == true;
    local UseDbgCheats = ##DEBUG_CHEATS## == true;
    local UseDbgShell = ##DEBUG_SHELL## == true;
    if UseQuestTrade or UseDbgCheats or UseDbgShell then
        QuestSystemDebug:Activate(UseQuestTrade, UseDbgCheats, UseDbgShell);
    end
    
    -- StartQuests
    CreateQuests();
end

-- Generate quests -------------------------------------------------------------

function CreateQuests()
    local Quests = {##MISSION_QUESTS##};
    for k, v in pairs(Qeusts) do
        new(
            QuestTemplate,
            v.Name
            v.Receiver,
            v.Time,
            v.Objectives,
            v.Conditions,
            v.Rewards,
            v.Reprisals,
            v.Description
        );
    end
end

-- Generated briefings ---------------------------------------------------------

-- This is the space for your briefings. Generated dialog briefings will be
-- placed here.

##MISSION_BRIEFINGS##

-- User functions --------------------------------------------------------------

-- This is the place where your functions live. Put in your code in user
-- definded behavior or add other functions here.

##MISSION_USER_BEHAVIOR##

