-- ########################################################################## --
-- #  Troop Spawn Generator                                                 # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module allows to create AI player and armies.
--
-- Altough this module is using parts of the AI functions for handling normal
-- armies this script is not bound to the limit of 8 armies per player or 8 
-- troops per army.
--
-- Armies have a strict behavior defined by their FSM. They will attack certain
-- positions or patrol between them. Sub behaviors like how the army reacts to
-- attacks or which troops are spawned can be configured.
--
-- If you are an beginner you should stick to the options the quest behaviors
-- give you. They are enough in most of the cases.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.core.questsync</li>
-- <li>qsb.core.questtools</li>
-- </ul>
--
-- @set sort=true
--

TroopGenerator = {
    States = {
        Decide = 1,
        Attack  = 2,
        Guard   = 3,
        Retreat = 4,
        Refill  = 5,
    },

    DefaultUnitsToBuild = {
        UpgradeCategories.LeaderPoleArm,
        UpgradeCategories.LeaderSword,
        UpgradeCategories.LeaderBow,
        UpgradeCategories.LeaderHeavyCavalry,
        UpgradeCategories.LeaderCavalry,
        UpgradeCategories.LeaderRifle,
    },

    CreatedAiPlayers = {},
    CreatedAiArmies = {},
    AiArmyNameToId = {},

    AI = {},
};

---
-- Table of army sub behaviors.
-- @field Decide Army is in default state and selects next action
-- @field Attack Army walks to the destination and attacks enemies
-- @field Guard Army patrols over their path
-- @field Retreat Army is retreating to the home base
-- @field Refill Army is recruiting or respawning until full
-- @within Constants
--
ArmyStates = {
    Decide = 1,
    Attack  = 2,
    Guard   = 3,
    Retreat = 4,
    Refill  = 5,
}

---
-- Table of army behavior.
-- @field MemberIsAttacked Enemies attacked a member of the army
-- @field SelectPurchasedType Selects the next purchased type
-- @field SelectSpawnedType Selects the next spawned type
-- @field SelectAttackTarget Selects the attack target
-- @field SelectPatrolTarget Selects the first patrol point
-- @within Constants
--
ArmyBehaviors = {
    MemberIsAttacked    = 2,
    SelectPurchasedType = 3,
    SelectSpawnedType   = 4,
    SelectAttackTarget  = 5,
    SelectPatrolTarget  = 6,
};

---
-- Table of army categories.
-- @field City City troop types
-- @field BlackKnight Black knight troop types
-- @field Bandit Bandit troop types
-- @field Barbarian Barbarian troop types
-- @field Evil Evil troop types
-- @within Constants
--
ArmyCategories = {
    City = {
        UpgradeCategories.LeaderBow,
        UpgradeCategories.LeaderSword,
        UpgradeCategories.LeaderPoleArm,
        UpgradeCategories.LeaderCavalry,
        UpgradeCategories.LeaderHeavyCavalry,
        UpgradeCategories.LeaderRifle
    },
    BlackKnight = {
        UpgradeCategories.LeaderBanditBow,
        UpgradeCategories.BlackKnightLeaderMace1,
        UpgradeCategories.LeaderPoleArm,
        UpgradeCategories.LeaderCavalry,
        UpgradeCategories.LeaderHeavyCavalry
    },
    Bandit = {
        UpgradeCategories.LeaderBanditBow,
        UpgradeCategories.LeaderBandit,
        UpgradeCategories.LeaderPoleArm,
        UpgradeCategories.LeaderCavalry,
        UpgradeCategories.LeaderHeavyCavalry
    },
    Barbarian = {
        UpgradeCategories.LeaderBanditBow,
        UpgradeCategories.LeaderBarbarian,
        UpgradeCategories.LeaderCavalry,
        UpgradeCategories.LeaderHeavyCavalry
    },
    Evil = {
        UpgradeCategories.Evil_LeaderBearman,
        UpgradeCategories.Evil_LeaderSkirmisher
    },
};

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ~~~                              API                                   ~~~ --
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

---
-- Creates an AI player and sets the technology level.
--
-- Use this function or the behavior to initalize the AI. An AI must first be
-- initalized before an army can be created.
--
-- <b>Note:</b> If you decide to allow to recruit armies keep in mind that they
-- will have 12 groups instead of 8!
--
-- @param[type=number] _PlayerID     PlayerID
-- @param[type=number] _TechLevel    Technology level [1|4]
-- @param[type=number] _SerfAmount   (optional) Amount of serfs
-- @param[type=string] _HomePosition (optional) Default army home position
-- @param[type=number] _Strength     (optional) Armies to recruit (0 = off)
-- @param[type=boolean] _Construct   (optional) AI can construct buildings
-- @param[type=boolean] _Rebuild     (optional) AI rebuilds (construction required)
-- @within Methods
--
-- @usage CreateAIPlayer(2, 4);
--
function CreateAIPlayer(_PlayerID, _TechLevel, _SerfAmount, _HomePosition, _Strength, _Construct, _Rebuild)
    _SerfAmount = _SerfAmount or 6;
    _Construct = (_Construct ~= nil and _Construct) or true;
    _Rebuild = (_Rebuild ~= nil and _Rebuild) or true;
    _Strength = _Strength or 0;

    if not TroopGenerator.CreatedAiPlayers[_PlayerID] then
        local PlayerEntities = QuestTools.GetPlayerEntities(_PlayerID, 0);
        for i= 1, table.getn(PlayerEntities), 1 do
            if Logic.IsBuilding(PlayerEntities[i]) == 1 then
                TroopGenerator.AI:CreateAI(_PlayerID, _SerfAmount, _HomePosition, _Strength, _TechLevel, _Construct, _Rebuild);
                TroopGenerator.CreatedAiPlayers[_PlayerID] = true;
                return;
            end
        end
    end
    Message("DEBUG: Failed to create AI for player " .._PlayerID.. "!");
end

---
-- Disables or enables the ability to attack for the army. This function can
-- be used to forbid an army to attack even if there are valid targets.
--
-- @param[type=number]  _PlayerID ID of player
-- @param               _Army     Name or ID of army
-- @param[type=boolean] _Flag     Ability to attack
-- @within Methods
-- 
-- @usage ArmyDisableAttackAbility(2, 1, true);
--
function ArmyDisableAttackAbility(_PlayerID, _Army, _Flag)
    local ArmyID = TroopGenerator.AiArmyNameToId[_Army];
    if not ArmyID then
        ArmyID = _Army;
    end
    TroopGenerator.AI:SetAttackAllowed(_PlayerID, ArmyID, not _Flag);
end

---
-- Disables or enables the ability to patrol between positions. This
-- function can force an army to stay on its spawnpoint or to avoid to be put
-- on guard duties.
--
-- @param[type=number]  _PlayerID ID of player
-- @param               _Army     Name or ID of army
-- @param[type=boolean] _Flag     Ability to attack
-- @within Methods
-- 
-- @usage ArmyDisablePatrolAbility(2, 1, true);
--
function ArmyDisablePatrolAbility(_PlayerID, _Army, _Flag)
    local ArmyID = TroopGenerator.AiArmyNameToId[_Army];
    if not ArmyID then
        ArmyID = _Army;
    end
    TroopGenerator.AI:SetDefenceAllowed(_PlayerID, ArmyID, not _Flag);
end

---
-- Initalizes an army that is recruited by the AI player.
-- Armies can also be created with the behavior interface. This is a simple
-- type of army that can be configured by placing and naming script entities.
-- The army name must be unique for the player!
--
-- The AI player must be initalized first!
--
-- Use script entities named with PlayerX_AttackTargetY to define positions
-- that will be attacked by the army. Replace X with the player ID and Y with
-- a unique number starting by 1.
--
-- Also you can use entities named with PlayerX_PatrolPointY to define
-- positions were the army will patrol. Also replace X with the player ID and
-- Y with a unique number starting by 1.
--
-- @param[type=string] _ArmyName   Army identifier
-- @param[type=number] _PlayerID   Owner of army
-- @param[type=number] _Strength   Strength of army [1|8]
-- @param[type=string] _Position   Home Position of army
-- @param[type=number] _Area Action range of the army
-- @param[type=table] _TroopTypes  Upgrade categories to recruit
-- @return[type=number] Army ID
-- @within Methods
--
-- @usage CreateAIPlayerArmy("Foo", 2, 8, "armyPos1", 5000, TroopTypeTable);
--
function CreateAIPlayerArmy(_ArmyName, _PlayerID, _Strength, _Position, _Area, _TroopTypes)
    if TroopGenerator.AiArmyNameToId[_ArmyName] then
        return;
    end
    TroopGenerator.CreatedAiArmies[_PlayerID] = TroopGenerator.CreatedAiArmies[_PlayerID] or {};
    _Strength = (_Strength < 0 and 1) or _Strength;
    if not TroopGenerator.CreatedAiPlayers[_PlayerID] then
        return;
    end
    local Instance = TroopGenerator.AI:CreateArmy {
        PlayerID        = _PlayerID,
        RodeLength      = _Area or 3000,
        Strength        = _Strength or 12,
        RetreatStrength = 0.1, 
        HomePosition    = _Position,
        TroopCatalog    = _TroopTypes or TroopGenerator.AI[_PlayerID].UnitsToBuild,
    };
    if Instance then
        TroopGenerator.AiArmyNameToId[_ArmyName] = Instance:GetID();
        return TroopGenerator.AiArmyNameToId[_ArmyName];
    end
end

---
-- Initalizes an army that is spawned until a generator entity is destroyed.
-- Armies can also be created with the behavior interface. This is a simple
-- type of army that can be configured by placing and naming script entities.
-- The army name must be unique for the player!
--
-- The AI player must be initalized first!
--
-- Define a list of troops that are sparned in this order. Troops will be
-- spawrned as long as the generator exists.
--
-- Use script entities named with PlayerX_AttackTargetY to define positions
-- that will be attacked by the army. Replace X with the player ID and Y with
-- a unique number starting by 1.
--
-- Also you can use entities named with PlayerX_PatrolPointY to define
-- positions were the army will patrol. Also replace X with the player ID and
-- Y with a unique number starting by 1.
--
-- @param[type=string] _ArmyName    Army identifier
-- @param[type=number] _PlayerID    Owner of army.
-- @param[type=number] _Strength    Strength of army [1|8]
-- @param[type=string] _Position    Home Position of army
-- @param[type=string] _Spawner  Name of generator
-- @param[type=number] _Area  Action range of the army
-- @param[type=number] _Respawn Time till troops are refreshed
-- @param              ...          List of types to spawn
-- @within Methods
--
-- @usage CreateAIPlayerSpawnArmy(
--     "Bar", 2, 8, "armyPos1", "lifethread", 5000,
--     {Entities.PU_LeaderSword2, 3},
--     {Entities.PU_LeaderBow2, 3},
--     {Entities.PV_Cannon2, 0}
-- );
--
function CreateAIPlayerSpawnArmy(_ArmyName, _PlayerID, _Strength, _Position, _Spawner, _Area, _Respawn, ...)
    if TroopGenerator.AiArmyNameToId[_ArmyName] then
        return;
    end
    TroopGenerator.CreatedAiArmies[_PlayerID] = TroopGenerator.CreatedAiArmies[_PlayerID] or {};
    _Strength = (_Strength < 0 and 1) or _Strength;
    if not TroopGenerator.CreatedAiArmies[_PlayerID] then
        return;
    end
    local EntityTypes = {};
    for i= 1, table.getn(arg), 1 do
        table.insert(EntityTypes, arg[i]);
    end
    assert(table.getn(EntityTypes) > 0);
    local Instance = TroopGenerator.AI:CreateSpawnArmy {
        PlayerID                 = _PlayerID,
        RodeLength               = _Area or 3000,
        Strength                 = _Strength or 12,
        HomePosition             = _Position,
        Lifethread               = _Spawner,
        IndependedFromLifethread = false,
        RespawnTime              = _Respawn,
        TroopCatalog             = EntityTypes,
    }
    if Instance then
        TroopGenerator.AiArmyNameToId[_ArmyName] = Instance:GetID();
        return TroopGenerator.AiArmyNameToId[_ArmyName];
    end
end

---
-- Sets the max amount of serfs the AI player will buy.
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=number] _Limit    Amount of serfs
-- @within Methods
-- 
-- @usage AIPlayerChangeSerfLimit(2, 4);
--
function AIPlayerChangeSerfLimit(_PlayerID, _Limit)
    AI.Village_SetSerfLimit(_PlayerID, _Limit);
end

---
-- Enables or disables the repair ability of an AI player.
--
-- @param[type=number]  _PlayerID ID of player
-- @param[type=boolean] _Flag     Repair is disabled
-- @within Methods
-- 
-- @usage AIPlayerDisableRepairAbility(2, true);
--
function AIPlayerDisableRepairAbility(_PlayerID, _Flag)
    TroopGenerator.AI:SetDoesRepair(_PlayerID, not _Flag);
end

---
-- Enables or disables the construction ability of an AI player.
--
-- @param[type=number]  _PlayerID ID of player
-- @param[type=boolean] _Flag     Construction is disabled
-- @within Methods
-- 
-- @usage AIPlayerDisableConstructAbility(2, true);
--
function AIPlayerDisableConstructAbility(_PlayerID, _Flag)
    TroopGenerator.AI:SetDoesConstruct(_PlayerID, not _Flag);
end

---
-- Enables or disables the rebuild ability of an AI player.
--
-- @param[type=number]  _PlayerID ID of player
-- @param[type=boolean] _Flag     Rebuild is disabled
-- @within Methods
-- 
-- @usage AIPlayerDisableRebuildAbility(2, true);
--
function AIPlayerDisableRebuildAbility(_PlayerID, _Flag)
    TroopGenerator.AI:SetDoesRebuild(_PlayerID, not _Flag);
end

---
-- Alters update time and amount of updated cheat resources for the AI.
--
-- <b>Note:</b> Only needed if the player should by resources for themself.
--
-- @param[type=number] _PlayerID   ID of player
-- @param[type=number] _UpdateTime Time between updates
-- @param[type=number] _Gold       Amount of gold
-- @param[type=number] _Clay       Amount of clay
-- @param[type=number] _Wood       Amount of wood
-- @param[type=number] _Stone      Amount of stone
-- @param[type=number] _Iron       Amount of iron
-- @param[type=number] _Sulfur     Amount of sulfur
-- @within Methods
-- 
-- @usage AIPlayerChangeResourceRespawnRates(2, 5*60, 6500, 1000, 2500, 1000, 2500, 2500);
--
function AIPlayerChangeResourceRespawnRates(_PlayerID, _UpdateTime, _Gold, _Clay, _Wood, _Stone, _Iron, _Sulfur)
    _Gold = _Gold or 0;
    _Clay = _Clay or 0;
    _Wood = _Wood or 0;
    _Stone = _Stone or 0;
    _Iron = _Iron or 0;
    _Sulfur = _Sulfur or 0;
    if not _UpdateTime then
        return;
    end
    AI.Player_SetResourceRefreshRates(_PlayerID, _Gold, _Clay, _Iron, _Sulfur, _Stone, _Wood, _UpdateTime);
end

---
-- Hides an Entity from the AI or makes it visible again.
--
-- Hidden entities will under no circumstances be added to armies created with
-- code from this library.
--
-- @param[type=number]  _PlayerID ID of player
-- @param               _Entity Entity to hide (Scriptname or ID)
-- @param[type=boolean] _HiddenFlag Entity is hidden
-- @within Methods
-- 
-- @usage AIPlayerChangeResourceRespawnRates(2, "Dario", true);
--
function HideEntityFromAIPlayer(_PlayerID, _Entity, _HiddenFlag)
    TroopGenerator.AI:HideEntityFromAI(_PlayerID, _Entity, _HiddenFlag);
end

---
-- Returns true if the entity is hidden from the AI of the given player ID.
--
-- @param[type=number]  _PlayerID ID of player
-- @param               _Entity Entity to hide (Scriptname or ID)
-- @return[type=boolean] Entity is hidden
-- @within Methods
-- 
-- @usage if IsEntityHiddenFromAIPlayer(2, "Dario") then
--     -- Do smething...
-- end
--
function IsEntityHiddenFromAIPlayer(_PlayerID, _Entity)
    return TroopGenerator.AI:IsEntityHidenFromAI(_PlayerID, _Entity);
end

---
-- Registers an attack target position for the player.
--
-- Already generated armies will also add this position to the list of their
-- possible targets.
--
-- @param[type=number] _PlayerID ID of player
-- @param              _Position Zielppsition
-- @return[type=number] ID of target position
-- @within Methods
-- 
-- @usage VeryImportantTargetID = CreateAIPlayerAttackTarget(2, "VeryImportantTarget");
--
function CreateAIPlayerAttackTarget(_PlayerID, _Position)
    if not TroopGenerator.CreatedAiPlayers[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return -1;
    end
    TroopGenerator.AI:AddAttackTarget(_PlayerID, _Position);
    return GetID(_Position);
end

---
-- Removes the attack target from the AI player and all armies of said player.
-- @param[type=number] _PlayerID ID of player
-- @param[type=number] _ID       Zielppsition
-- @within Methods
-- 
-- @usage DestroyAIPlayerAttackTarget(2, VeryImportantTargetID);
--
function DestroyAIPlayerAttackTarget(_PlayerID, _ID)
    if not TroopGenerator.CreatedAiPlayers[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    TroopGenerator.AI:RemoveAttackTarget(_PlayerID, _ID);
end

---
-- Registers an patrol waypoint position for the player.
--
-- Already generated armies will also add this position to the list of their
-- patrol waypoints.
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=number] _Position Zielppsition
-- @return[type=number] ID of target position
-- @within Methods
-- 
-- @usage VeryImportantTargetID = CreateAIPlayerPatrolPoint(2, "VeryImportantTarget");
--
function CreateAIPlayerPatrolPoint(_PlayerID, _Position)
    if not TroopGenerator.CreatedAiPlayers[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return -1;
    end
    TroopGenerator.AI:AddDefenceTarget(_PlayerID, _Position);
    return GetID(_Position);
end

---
-- Removes the patrol waypoint from the AI player and all armies of said player.
-- @param[type=number] _PlayerID ID of player
-- @param[type=number] _ID       Zielppsition
-- @within Methods
-- 
-- @usage DestroyAIPlayerPatrolPoint(2, VeryImportantTargetID);
--
function DestroyAIPlayerPatrolPoint(_PlayerID, _ID)
    if not TroopGenerator.CreatedAiPlayers[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    TroopGenerator.AI:RemoveDefenceTarget(_PlayerID, _ID);
end

---
-- Overrides the behavior of the army with the given function.
--
-- <b>Note:</b> Only change behavior if you know what you are doing! You
-- might break the army controller!
--
-- <table border="1">
-- <tr>
-- <td><b>Behavior</b></td>
-- <td><b>Description</b></td>
-- </tr>
-- <tr>
-- <td>MemberIsAttacked</td>
-- <td>Called when ever an enemy attacks an member of the army.</td>
-- </tr>
-- <tr>
-- <td>SelectPurchasedType</td>
-- <td><b>Note:</b> Only used if the army purchases troops!</br>
-- Passes the catalog to the controller. The controller must set the catalog
-- iterator. Use this to change how an army recruits their members. You can
-- prioritize certain types.</td>
-- </tr>
-- <tr>
-- <td>SelectSpawnedType</td>
-- <td><b>Note:</b> Only used if the army spawns troops!</br>
-- Passes the catalog to the controller. The controller must set the catalog
-- iterator.</td>
-- </tr>
-- <tr>
-- <td>SelectAttackTarget</td>
-- <td>Passes the list of reachable attack targets where no army has been send
-- to yet to the controller function. The controller must order those targets by
-- any criteria and return the sorted list. The army will take the first target
-- in this list.<br>
-- By default, the targets are sorted by distance. The first one is the closest
-- to the home position.</td>
-- </tr>
-- <tr>
-- <td>SelectPatrolTarget</td>
-- <td>Passes the list of reachable patrol targets to the controller function.
-- The controller must create a list from those targets and set them as the
-- path. Additionally it has to set the index of the first waypoint. Army will
-- loop over the waypoints starting from the selected one.<br>
-- By default, any position that is reachable from the home position of the
-- army will be put into the list and the first waypoint is set by random.</td>
-- </tr>
-- <tr>
-- <td>AttackFinished</td>
-- <td>Checks, if the current attack has finished. The controller must return
-- true when the attack is finished.<br>
-- By default, an attack ends, after an area in size of the rode length of the
-- army around the current target has been cleared from enemies.</td>
-- </tr>
-- </table>
--
-- @param[type=number] _PlayerID   ID of player
-- @param[type=number] _ArmyID     ID of army
-- @param[type=number] _Behavior   ID of behavior
-- @param[type=number] _Controller Controller function
-- @within Methods
-- 
-- @usage ChangeArmyBehavior(2, FrontalAttackArmyID, ArmyBehaviors.SelectPurchasedType, CavalryOnlyRecruiter);
--
function ChangeArmyBehavior(_PlayerID, _ArmyID, _Behavior, _Controller)
    if not TroopGenerator.AI[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    if not TroopGenerator.AI[_PlayerID].Armies[_ArmyID] then
        assert(false, "Army " .._ArmyID.. " not initalized for player " .._PlayerID.. "!");
        return;
    end
    if type(_Controller) ~= "function" then
        assert(false, "Controller must be a function!");
        return;
    end
    
    if ArmyBehaviors.MemberIsAttacked == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnMemberIsAttackedBehavior(_Controller);
    elseif ArmyBehaviors.SelectPurchasedType == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnTypeToRecruitSelectedBehavior(_Controller);
    elseif ArmyBehaviors.SelectSpawnedType == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnTypeToSpawnSelectedBehavior(_Controller);
    elseif ArmyBehaviors.SelectAttackTarget == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnAttackTargetSelectedBehavior(_Controller);
    elseif ArmyBehaviors.SelectPatrolTarget == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnWaypointSelectedBehavior(_Controller);
    elseif ArmyBehaviors.AttackFinished == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnAttackTargetClearedBehavior(_Controller)
    end
end

---
-- Changes the unit types an AI player will recruit.
--
-- <b>Note:</b> The cannon type is automatically set by the technology level.
-- 
-- @param[type=number] _PlayerID     ID of player
-- @param[type=table]  _CategoryList List of units to recruit
-- @within Methods
-- 
-- @usage SetAIPlayerUnitsToBuild(2, {UpgradeCategories.LeaderBarbarian});
--
function SetAIPlayerUnitsToBuild(_PlayerID, _CategoryList)
    if not TroopGenerator.AI[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return ArmyIDList;
    end
    TroopGenerator.AI:SetUnitsToBuild(_PlayerID, _CategoryList);
end

---
-- Returns the IDs of all armies of the player.
-- @param[type=number] _PlayerID ID of player
-- @return[type=table] All armies of player
-- @within Methods
-- 
-- @usage local AllArmies = GetAIPlayerArmies(2);
--
function GetAIPlayerArmies(_PlayerID)
    local ArmyIDList = {};
    if not TroopGenerator.AI[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return ArmyIDList;
    end
    for i= 1, table.getn(TroopGenerator.AI[_PlayerID].Armies), 1 do
        table.insert(ArmyIDList, TroopGenerator.AI[_PlayerID].Armies[i]:GetID());
    end
    return ArmyIDList;
end

---
-- Returns the IDs of all armies of the player that are currently in the state.
-- @param[type=number] _PlayerID ID of player
-- @return[type=table] Armies in state of player
-- @within Methods
-- @see ArmyStates
-- 
-- @usage local AllArmies = GetAIPlayerArmies(2, ArmyStates.Attack);
--
function GetAIPlayerArmiesByState(_PlayerID, _State)
    local ArmyIDList = {};
    if not TroopGenerator.AI[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return ArmyIDList;
    end
    for k, v in pairs(GetAIPlayerArmies(_PlayerID)) do
        if TroopGenerator.AI[_PlayerID].Armies[v]:GetState() == _State then
            table.insert(ArmyIDList, v);
        end
    end
    return ArmyIDList;
end

---
-- Sets if the AI player is ignoring the costs of units when recruiting or
-- refreshing.
-- 
-- <p><b>Note:</b> This is active by default!</p>
--
-- @param[type=number]  _PlayerID ID of player
-- @param[type=boolean] _Flag     Does ignore costs
-- @within Methods
-- 
-- @usage SetAIPlayerIgnoreMilitaryCosts(2, false);
--
function SetAIPlayerIgnoreMilitaryCosts(_PlayerID, _Flag)
    if not TroopGenerator.AI[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    TroopGenerator.AI:SetIgnoreMilitaryUnitCosts(_PlayerID, _Flag);
end

---
-- Sets if the AI player is ignoring the attraction limit.
-- 
-- <p><b>Note:</b> This is active by default!</p>
--
-- @param[type=number]  _PlayerID ID of player
-- @param[type=boolean] _Flag     Does ignore limit
-- @within Methods
-- 
-- @usage SetAIPlayerIgnoreAttractionLimit(2, false);
--
function SetAIPlayerIgnoreAttractionLimit(_PlayerID, _Flag)
    if not TroopGenerator.AI[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    TroopGenerator.AI:SetIgnoreVillageCenterLimit(_PlayerID, _Flag);
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ~~~                          TroopGenerator.AI                         ~~~ --
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

function TroopGenerator.AI:CreateAI(_PlayerID, _SerfAmount, _HomePosition, _Strength, _TechLevel, _Construct, _Rebuild)
    if self[_PlayerID] then
        return;
    end
    self[_PlayerID] = {
        Armies          = {},
        ArmySequence    = 0,
        Unavailable     = {},
        AttackPos       = {},
        ServedAttackPos = {},
        DefencePos      = {},
        HomePosition    = _HomePosition,
        TechLevel       = _TechLevel,
        UnitsToBuild    = copy(TroopGenerator.DefaultUnitsToBuild),
        EmploysArmies   = _Strength > 0,
        Strength        = _Strength,
        MilitaryCosts   = true,
        VillageCenter   = true,
    };
    table.insert(self[_PlayerID].UnitsToBuild, Entities["PV_Cannon" .._TechLevel]);
    
    -- Find default target and patrol points
    for k, v in pairs(QuestTools.GetEntitiesByPrefix("Player" .._PlayerID.. "_AttackTarget")) do
        self:AddAttackTarget(_PlayerID, v);
    end
    for k, v in pairs(QuestTools.GetEntitiesByPrefix("Player" .._PlayerID.. "_PatrolPoint")) do
        self:AddDefenceTarget(_PlayerID, v);
    end

    -- Upgrade troops
    for i= 2, _TechLevel, 1 do
        Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderBow, _PlayerID);
        Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderSword, _PlayerID);
        Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderPoleArm, _PlayerID);
    end
    if _TechLevel == 4 then
        Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderCavalry, _PlayerID);
        Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderHeavyCavalry, _PlayerID);
        Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderRifle, _PlayerID);
    end

    -- Serf limit
    local SerfLimit = 3 * (_Strength +1);
    local Description = {
        serfLimit    = _SerfAmount or SerfLimit,
        constructing = _Construct == true,
        repairing    = true,
        
        resources = {
            gold   = 3500 + (600 * _Strength),
            clay   = 1200 + (200 * _Strength),
            iron   = 2500 + (300 * _Strength),
            sulfur = 2500 + (300 * _Strength),
            stone  = 1200 + (200 * _Strength),
            wood   = 1500 + (250 * _Strength),
        },
        refresh = {
            updateTime = math.floor((30 / (_Strength +1)) +0.5),
            gold       = 750,
            clay       = 10,
            iron       = 15,
            sulfur     = 15,
            stone      = 10,
            wood       = 10,
        },
    };
    if _Rebuild then
        Description.rebuild	= {delay = 2*60};
    end
    SetupPlayerAi(_PlayerID, Description);

    -- Employ armies
    self:EmployArmies(_PlayerID);

    QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, function(_PlayerID)
        TroopGenerator.AI:ArmyStateController(_PlayerID);
    end, _PlayerID);

    QuestTools.StartInlineJob(Events.LOGIC_EVENT_ENTITY_HURT_ENTITY, function(_PlayerID)
        TroopGenerator.AI:ArmyAttackedController(_PlayerID);
    end, _PlayerID);
end

function TroopGenerator.AI:ArmyStateController(_PlayerID)
    if self[_PlayerID] then
        for i= table.getn(self[_PlayerID].Armies), 1, -1 do
            self:ControlArmy(_PlayerID, self[_PlayerID].Armies[i]);
            if self[_PlayerID].Armies[i] then
                self:ControlArmyMember(_PlayerID, self[_PlayerID].Armies[i]);
            end
        end
    end
end

function TroopGenerator.AI:ArmyAttackedController(_PlayerID)
    if self[_PlayerID] then
        local Attacker = Event.GetEntityID1();
        local Defender = Event.GetEntityID2();
        local AttackerPlayerID = Logic.EntityGetPlayer(Attacker);
        local DefenderPlayerID = Logic.EntityGetPlayer(Defender);

        if AttackerPlayerID ~= _PlayerID then
            return;
        end
        local ArmyID = TroopGenerator.AI:GetArmyEntityIsEmployedIn(Defender);
        if ArmyID == 0 then
            return;
        end
        if not self[_PlayerID].Armies[ArmyID] then
            return;
        end
        self[_PlayerID].Armies[ArmyID]:OnMemberIsAttackedBehavior(Attacker, Defender);
    end
end

function TroopGenerator.AI:SetDoesRepair(_PlayerID, _Flag)
    if self[_PlayerID] then
        AI.Village_EnableRepairing(_PlayerID, (_Flag == true and 1) or 0);
    end
end

function TroopGenerator.AI:SetDoesConstruct(_PlayerID, _Flag)
    if self[_PlayerID] then
        AI.Village_EnableConstructing(_PlayerID, (_Flag == true and 1) or 0);
    end
end

function TroopGenerator.AI:SetDoesRebuild(_PlayerID, _Flag)
    if self[_PlayerID] then
        if _Flag == true then
            AI.Entity_ActivateRebuildBehaviour(_PlayerID, 2*60, 0);
        else
            AI.Village_DeactivateRebuildBehaviour(_PlayerID);
        end
    end
end

function TroopGenerator.AI:UpgradeTroops(_PlayerID, _NewTechLevel)
    if self[_PlayerID] then
        local OldLevel = self[_PlayerID].TechLevel;
        if _NewTechLevel > 0 and _NewTechLevel < 5 and OldLevel < _NewTechLevel then
            -- Remove cannon
            for i= table.getn(self[_PlayerID].UnitsToBuild), 1, -1 do
                local UpgradeCategory = self[_PlayerID].UnitsToBuild[i];
                if UpgradeCategory == UpgradeCategories.Cannon1
                or UpgradeCategory == UpgradeCategories.Cannon2
                or UpgradeCategory == UpgradeCategories.Cannon3
                or UpgradeCategory == UpgradeCategories.Cannon4 then
                    table.remove(self[_PlayerID].UnitsToBuild, i);
                end
            end
            -- Upgrade troops
            for i= OldLevel, _NewTechLevel, 1 do
                Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderBow, _PlayerID);
                Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderSword, _PlayerID);
                Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderPoleArm, _PlayerID);
            end
            if _NewTechLevel == 4 then
                Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderCavalry, _PlayerID);
                Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderHeavyCavalry, _PlayerID);
                Logic.UpgradeSettlerCategory(UpgradeCategories.LeaderRifle, _PlayerID);
            end
            -- Add cannon type
            local CannonType = Entities["PV_Cannon" .._NewTechLevel];
            table.insert(self[_PlayerID].UnitsToBuild, CannonType);
        end
    end
end

function TroopGenerator.AI:SetUnitsToBuild(_PlayerID, _CategoryList)
    if self[_PlayerID] then
        -- Remove all
        self[_PlayerID].UnitsToBuild = {};
        -- Add troops
        for i= 1, table.getn(_CategoryList), 1 do
            local UpgradeCategory = self[_PlayerID].UnitsToBuild[i];
            if _CategoryList[i] ~= UpgradeCategories.Cannon1
            or _CategoryList[i] ~= UpgradeCategories.Cannon2
            or _CategoryList[i] ~= UpgradeCategories.Cannon3
            or _CategoryList[i] ~= UpgradeCategories.Cannon4 then
                table.insert(self[_PlayerID].UnitsToBuild, _CategoryList[i]);
            end
        end
        -- Add cannon type
        local CannonType = Entities["PV_Cannon" ..self[_PlayerID].TechLevel];
        table.insert(self[_PlayerID].UnitsToBuild, CannonType);
        -- Alter recruiting armies
        for i= 1, table.getn(self[_PlayerID].Armies), 1 do
            if not self[_PlayerID].Armies[i]:DoesRespawn() then
                self[_PlayerID].Armies[i]:SetTroopCatalog(self[_PlayerID].UnitsToBuild);
            end
        end
    end
end

function TroopGenerator.AI:SetIgnoreMilitaryUnitCosts(_PlayerID, _Flag)
    if self[_PlayerID] then
        self[_PlayerID].MilitaryCosts = _Flag;
    end
end

function TroopGenerator.AI:DoesIgnoreMilitaryCosts(_PlayerID)
    if self[_PlayerID] then
        return self[_PlayerID].MilitaryCosts == true;
    end
    return false;
end

function TroopGenerator.AI:SetIgnoreVillageCenterLimit(_PlayerID, _Flag)
    if self[_PlayerID] then
        self[_PlayerID].VillageCenter = _Flag;
    end
end

function TroopGenerator.AI:DoesIgnoreVillageCenterLimit(_PlayerID)
    if self[_PlayerID] then
        return self[_PlayerID].VillageCenter == true;
    end
    return false;
end

-- ~~~ Detection ~~~ --

function TroopGenerator.AI:GetEnemiesInArea(_PlayerID, _Position, _Area)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    local Enemies = {}
    for i= 1, 8, 1 do
        if i ~= _PlayerID and Logic.GetDiplomacyState(i, _PlayerID) == Diplomacy.Hostile then
            local PlayerUnits = {Logic.GetPlayerEntitiesInArea(i, 0, _Position.X, _Position.Y, _Area, 16)};
            local Amount = table.getn(PlayerUnits)-1;
            if Amount > 0 then
                for j= Amount+1, 2, -1 do
                    -- Ignore worker
                    if Logic.IsEntityInCategory(PlayerUnits[j], EntityCategories.Worker) == 0 then
                        table.insert(Enemies, PlayerUnits[j]);
                    end
                end
            end
        end
    end
    for i= table.getn(Enemies), 1, -1 do
        if (Logic.IsBuilding(Enemies[i]) == 0 and Logic.IsSettler(Enemies[i]) == 0)
        or Logic.GetEntityType(Enemies[i]) == Entities.PU_Thief
        or Logic.GetEntityHealth(Enemies[i]) == 0 then
            table.remove(Enemies, i);
        end
    end
    return Enemies;
end

function TroopGenerator.AI:GetArmyDefencePositions(_PlayerID, _ArmyID)
    local Waypoints = {}
    if self[_PlayerID] and self[_PlayerID].Armies[_ArmyID] then
        Waypoints = copy(self[_PlayerID].DefencePos);
        local HomePosition = self[_PlayerID].Armies[_ArmyID]:GetHomePosition();
        -- Check accessablility and fill list
        for i= table.getn(Waypoints), 1, -1 do
            local TargetPosition = Waypoints[i];
            if not QuestTools.SameSector(TargetPosition, HomePosition) then
                table.remove(Waypoints, i);
            end
        end
        -- Sort, so that the closest is first
        local sort = function(a, b)
            return QuestTools.GetDistance(a, HomePosition) < QuestTools.GetDistance(b, HomePosition);
        end
        table.sort(Waypoints, sort);
    end
    return Waypoints;
end

function TroopGenerator.AI:GetAllUnattendedAttackTargets(_PlayerID, _ArmyID)
    local Unattended = {}
    if self[_PlayerID] and self[_PlayerID].Armies[_ArmyID] then
        -- Use armys rode length for enemy detection
        local RodeLength = self[_PlayerID].Armies[_ArmyID]:GetRodeLength();
        local HomePosition = self[_PlayerID].Armies[_ArmyID]:GetHomePosition();
        for i= 1, table.getn(self[_PlayerID].AttackPos), 1 do
            local Target = self[_PlayerID].AttackPos[i];
            local Enemies = self[_PlayerID].Armies[_ArmyID]:GetEnemiesInRodeLength(Target);
            -- Check usage of target if enemies are found
            if table.getn(Enemies) > 0 then
                local InUse = false;
                for j= 1, table.getn(self[_PlayerID].Armies) do
                    if self[_PlayerID].Armies[j]:GetTarget() == Target then
                        InUse = true;
                    end
                end
                -- Add unattended target if reachable
                if not InUse then
                    if QuestTools.SameSector(HomePosition, Target) then
                        table.insert(Unattended, Target);
                    end
                end
            end
        end
    end
    return Unattended;
end

function TroopGenerator.AI:GetClosestUnattendedAttackTarget(_PlayerID, _ArmyID)
    if self[_PlayerID] and self[_PlayerID].Armies[_ArmyID] then
        local HomePosition = self[_PlayerID].Armies[_ArmyID]:GetHomePosition();
        local Unattended = TroopGenerator.AI:GetAllUnattendedAttackTargets(_PlayerID, _ArmyID);
        -- Break if nothing is found
        if table.getn(Unattended) == 0 then
            return nil;
        end
        -- Sort, so that the closest is first
        local sort = function(a, b)
            return QuestTools.GetDistance(a, HomePosition) < QuestTools.GetDistance(b, HomePosition);
        end
        table.sort(Unattended, sort);
        -- Return first element
        return Unattended[1];
    end
    return nil;
end

-- deprecated ?
function TroopGenerator.AI:GetClosestPositionToArmy(_PlayerID, _ArmyID, ...)
    if self[_PlayerID] then
        for i= 1, table.getn(self[_PlayerID].Armies), 1 do
            if self[_PlayerID].Armies[i] == _ArmyID then
                local LastDistance = Logic.WorldGetSize();
                local LastEntity   = nil;
                local Index        = 0;
                local ArmyPosition = self[_PlayerID].Armies[i]:GetPosition();
                for j= 1, table.getn(arg), 1 do
                    local Distance = QuestTools.GetDistance(arg[j], ArmyPosition);
                    if Distance < LastDistance then
                        LastDistance = Distance
                        LastEntity   = arg[j];
                        Index        = j;
                    end
                end
                return LastEntity, Index;
            end
        end
    end
    return arg[1], 1;
end

function TroopGenerator.AI:GenerateNewArmyID(_PlayerID)
    if self[_PlayerID] then
        self[_PlayerID].ArmySequence = self[_PlayerID].ArmySequence +1;
        return self[_PlayerID].ArmySequence;
    end
    return 0;
end

function TroopGenerator.AI:AddArmy(_PlayerID, _Army)
    if self[_PlayerID] and self[_PlayerID].Strength < table.getn(self[_PlayerID].Armies) then
        table.insert(self[_PlayerID].Armies, _Army);
    end
end

function TroopGenerator.AI:HideEntityFromAI(_PlayerID, _Entity, _Flag)
    if self[_PlayerID] then
        self[_PlayerID].Unavailable[_Entity] = _Flag == true;
    end
end

function TroopGenerator.AI:IsEntityHidenFromAI(_PlayerID, _Entity)
    if self[_PlayerID] then
        return self[_PlayerID].Unavailable[_Entity] == true;
    end
end

-- ~~~ Targeting ~~~ --

function TroopGenerator.AI:AddAttackTarget(_PlayerID, _Entity)
    if self[_PlayerID] then
        if not QuestTools.IsInTable(_Entity, self[_PlayerID].AttackPos) then
            table.insert(self[_PlayerID].AttackPos, _Entity);
        end
    end
end

function TroopGenerator.AI:RemoveAttackTarget(_PlayerID, _Entity)
    if self[_PlayerID] then
        for i= table.getn(self[_PlayerID].AttackPos), 1, 1 do
            if self[_PlayerID].AttackPos[i] == _Entity then
                table.remove(self[_PlayerID].AttackPos, i);
            end
        end
    end
end

function TroopGenerator.AI:SetAttackAllowed(_PlayerID, _ArmyID, _Flag)
    if self[_PlayerID] then
        for i= 1, table.getn(self[_PlayerID].Armies), 1 do
            if self[_PlayerID].Armies[i]:GetID() == _ArmyID then
                self[_PlayerID].Armies[i]:SetAttackAllowed(_Flag == true);
            end
        end
    end
end

function TroopGenerator.AI:AddDefenceTarget(_PlayerID, _Entity)
    if self[_PlayerID] then
        if not QuestTools.IsInTable(_Entity, self[_PlayerID].DefencePos) then
            table.insert(self[_PlayerID].DefencePos, _Entity);
        end
    end
end

function TroopGenerator.AI:RemoveDefenceTarget(_PlayerID, _Entity)
    if self[_PlayerID] then
        for i= table.getn(self[_PlayerID].DefencePos), 1, 1 do
            if self[_PlayerID].DefencePos[i] == _Entity then
                table.remove(self[_PlayerID].DefencePos, i);
            end
        end
    end
end

function TroopGenerator.AI:SetDefenceAllowed(_PlayerID, _ArmyID, _Flag)
    if self[_PlayerID] then
        for i= 1, table.getn(self[_PlayerID].Armies), 1 do
            if self[_PlayerID].Armies[i]:GetID() == _ArmyID then
                self[_PlayerID].Armies[i]:SetDefenceAllowed(_Flag == true);
            end
        end
    end
end

-- ~~~ Army ~~~ --

function TroopGenerator.AI:CreateArmy(_Data)
    local NewID = self:GenerateNewArmyID(_Data.PlayerID);
    if NewID == 0 then
        return;
    end
    local Instance = new(
        TroopGenerator.Army,
        NewID,
        _Data.PlayerID,
        _Data.RodeLength or 3000,
        _Data.Strength or 12,
        _Data.RetreatStrength or 0.1, 
        _Data.HomePosition,
        nil,
        true,
        0,
        _Data.TroopCatalog
    );
    table.insert(self[_Data.PlayerID].Armies, Instance);
    return Instance;
end

function TroopGenerator.AI:CreateSpawnArmy(_Data)
    local NewID = self:GenerateNewArmyID(_Data.PlayerID);
    if NewID == 0 then
        return;
    end
    local Instance = new(
        TroopGenerator.Army,
        NewID,
        _Data.PlayerID,
        _Data.RodeLength or 3000,
        _Data.Strength or 12,
        _Data.RetreatStrength or 0.1, 
        _Data.HomePosition,
        _Data.Lifethread,
        _Data.IndependedFromLifethread == true,
        _Data.RespawnTime or 30,
        _Data.TroopCatalog
    );
    table.insert(self[_Data.PlayerID].Armies, Instance);
    return Instance;
end

function TroopGenerator.AI:EmployArmies(_PlayerID)
    if self[_PlayerID] then
        if self[_PlayerID].EmploysArmies then
            local Strength = self[_PlayerID].Strength;
            -- Drop armies if to much
            if Strength > table.getn(self[_PlayerID].Armies) then
                while (Strength > table.getn(self[_PlayerID].Armies)) do
                    TroopGenerator.AI:CreateArmy({
                        PlayerID		         = _PlayerID,
                        RodeLength               = 8000,
                        Strength		         = 12,
                        RetreatStrength          = 0.1, 
                        HomePosition             = self[_PlayerID].HomePosition,
                        Lifethread               = nil,
                        IndependedFromLifethread = true,
                        RespawnTime              = 0,
                        TroopCatalog             = self[_PlayerID].UnitsToBuild
                    });
                end
            end
        end
    end
end

function TroopGenerator.AI:GetNextUnemployedLeader(_PlayerID, _RallyPoint, _TroopTypes)
    _TroopTypes = _TroopTypes or {};
    if self[_PlayerID] then
        local Leader = {};
        Leader = copy(QuestTools.GetAllCannons(_PlayerID), Leader);
        Leader = copy(QuestTools.GetAllLeader(_PlayerID), Leader);
        for i= table.getn(Leader), 1, -1 do
            local Name = QuestTools.CreateNameForEntity(Leader[i]);
            local Task = Logic.GetCurrentTaskList(Leader[i]);
            if Task and (string.find(Task, "TRAIN") or string.find(Task, "BATTLE") or string.find(Task, "DIE")) then
                table.remove(Leader, i);
            elseif AI.Entity_GetConnectedArmy(Leader[i]) ~= -1 then
                table.remove(Leader, i);
            elseif self:IsEntityHidenFromAI(_PlayerID, Name) then
                table.remove(Leader, i);
            elseif not self:IsLeaderAllowedTypeForArmy(Leader[i], _TroopTypes) then
                table.remove(Leader, i);
            elseif not QuestTools.SameSector(Leader[i], _RallyPoint) then
                table.remove(Leader, i);
            else
                for j= 1, table.getn(self[_PlayerID].Armies), 1 do
                    for k, v in pairs(self[_PlayerID].Armies[j]:GetMembers()) do
                        if GetID(v:GetScriptName()) == Leader[i] then
                            table.remove(Leader, i);
                        end
                    end
                end
            end
        end
        if table.getn(Leader) > 0 then
            return Leader[1];
        end
    end
    return 0;
end

function TroopGenerator.AI:IsLeaderAllowedTypeForArmy(_Entity, _TroopTypes)
    local ID = GetID(_Entity);
    local PlayerID = Logic.EntityGetPlayer(ID);
    local EntityType = Logic.GetEntityTypeName(ID);
    if not _TroopTypes or table.getn(_TroopTypes) == 0 then
        return true;
    end
    local TroopTypes = {};
    for k, v in pairs(_TroopTypes) do
        if string.find(Logic.GetEntityTypeName(v), "Cannon") ~= nil then
            table.insert(TroopTypes, v);
        else
            table.insert(TroopTypes, Logic.GetSettlerTypeByUpgradeCategory(v, PlayerID));
        end
    end
    return QuestTools.HasEntityOneOfTypes(ID, TroopTypes);
end

function TroopGenerator.AI:GetArmyEntityIsEmployedIn(_Entity)
    local Name = QuestTools.CreateNameForEntity(_Entity);
    for i= 1, 8, 1 do
        if self[i] then
            for j= 1, table.getn(self[i].Armies), 1 do
                for k, v in pairs(self[i].Armies[j]:GetMembers()) do
                    if Name == v:GetScriptName() then
                        return self[i].Armies[j]:GetID();
                    end
                end
            end
        end
    end
    return 0;
end

function TroopGenerator.AI:DropArmy(_PlayerID, _ArmyID, _DeleteTroops)
    if self[_PlayerID] then
        for i= table.getn(self[_PlayerID].Armies), 1, -1 do
            if self[_PlayerID].Armies[i] and self[_PlayerID].Armies[i]:GetID() == _ArmyID then
                local Army = table.remove(self[_PlayerID].Armies, i);
                if _DeleteTroops then
                    Army:KillAllGroups();
                else
                    Army:UnbindAllGroups();
                end
            end
        end
    end
end

function TroopGenerator.AI:IsNecessaryToHireLeader(_PlayerID)
    if self[_PlayerID] then
        local NeededAmount = 0;
        for i= 1, table.getn(self[_PlayerID].Armies), 1 do
            NeededAmount = NeededAmount + self[_PlayerID].Armies[i]:GetMaxTroopCount();
        end
        local Leader = {};
        Leader = copy(QuestTools.GetAllLeader(_PlayerID), Leader);
        Leader = copy(QuestTools.GetAllCannons(_PlayerID), Leader);
        return NeededAmount > table.getn(Leader);
    end
    return false;
end

-- ~~~ Army controller ~~~ --

function TroopGenerator.AI:ControlArmy(_PlayerID, _Army)
    if self[_PlayerID] then
        -- Destroy if lifethread is destroyed
        if _Army:DoesRespawn() then
            if _Army:IsDead() then
                local Kill = not _Army:IsIndependedFromLifethread();
                self:DropArmy(_PlayerID, _Army:GetID(), Kill);
                return;
            end
        end

        -- Select action
        if _Army:GetState() == ArmyStates.Decide then
            if _Army:IsAttackAllowed() then
                if _Army:GetTarget() == nil then
                    local TargetsAvailable = self:GetAllUnattendedAttackTargets(_PlayerID, _Army:GetID());
                    if table.getn(TargetsAvailable) > 0 then
                        local TargetsSorted = _Army:OnAttackTargetSelectedBehavior(TargetsAvailable);
                        _Army:SetPath({TargetsSorted[1]});
                        _Army:SetWaypoint(1);
                        _Army:SetTarget(_Army:GetCurrentWaypoint());
                        _Army:SetState(ArmyStates.Attack);
                        return;
                    end
                else
                    _Army:SetState(ArmyStates.Attack);
                end
            end
            if _Army:IsDefenceAllowed() then
                local GuardPath = self:GetArmyDefencePositions(_PlayerID, _Army:GetID());
                _Army:OnWaypointSelectedBehavior(GuardPath);
                _Army:SetState(ArmyStates.Guard);
            end
            return;
        end

        -- Attack enemies
        if _Army:GetState() == ArmyStates.Attack then
            if _Army:GetTroopCount() == 0 or _Army:DoesRetreat() then
                _Army:CancelState();
                _Army:SetState(ArmyStates.Retreat);
                return;
            end
            if _Army:OnAttackTargetClearedBehavior() then
                _Army:CancelState();
                _Army:SetState(ArmyStates.Decide);
            end
            return;
        end

        -- Patrol between positions
        if _Army:GetState() == ArmyStates.Guard then
            if _Army:GetTroopCount() == 0 or _Army:DoesRetreat() then
                _Army:CancelState();
                _Army:SetState(ArmyStates.Retreat);
                _Army:SetGuardStartTime(0);
            elseif not _Army:IsDefenceAllowed() then
                _Army:CancelState();
                _Army:SetState(ArmyStates.Decide);
                _Army:SetGuardStartTime(0);
            else
                if _Army:IsAttackAllowed() then
                    if _Army:GetTarget() ~= nil then
                        _Army:SetState(ArmyStates.Attack);
                    else
                        local TargetsAvailable = self:GetAllUnattendedAttackTargets(_PlayerID, _Army:GetID());
                        if table.getn(TargetsAvailable) > 0 then
                            _Army:CancelState();
                            _Army:SetState(ArmyStates.Decide);
                            _Army:SetGuardStartTime(0);
                            return;
                        end
                    end
                end
                if _Army:GetCurrentWaypoint() == nil then
                    local DefenceTargets = self:GetArmyDefencePositions(_PlayerID, _Army:GetID());
                    if table.getn(DefenceTargets) == 0 then
                        _Army:SetState(ArmyStates.Decide);
                        _Army:SetGuardStartTime(0);
                    else
                        _Army:OnWaypointSelectedBehavior(DefenceTargets);
                        _Army:SetGuardStartTime(Logic.GetTime());
                    end
                else
                    if _Army:GetGuardStartTime() + _Army:GetGuardTime() < Logic.GetTime() then
                        _Army:Stop();
                        _Army:NextWaypoint(true);
                        _Army:SetGuardStartTime(Logic.GetTime());
                    else
                        if QuestTools.GetDistance(_Army:GetPosition(), _Army:GetAnchor()) > 1000 then
                            if not _Army:IsFighting() then
                                _Army:Move(_Army:GetAnchor());
                            end
                        else
                            if not _Army:IsFighting() then
                                local Enemies = _Army:GetEnemiesInRodeLength(_Army:GetAnchor());
                                if table.getn(Enemies) > 0 then
                                    _Army:AttackMove(Enemies[1]);
                                end
                            end
                        end
                    end
                end
            end
            return;
        end

        -- Retreat
        if _Army:GetState() == ArmyStates.Retreat then
            if table.getn(_Army:GetMembers()) == 0 then
                _Army:SetLastRespawn(Logic.GetTime());
                _Army:SetState(ArmyStates.Refill);
            elseif QuestTools.GetDistance(_Army:GetPosition(), _Army:GetHomePosition()) <= 2000 then
                _Army:SetLastRespawn(Logic.GetTime());
                _Army:SetState(ArmyStates.Refill);
            end
            return;
        end

        -- Refill
        if _Army:GetState() == ArmyStates.Refill then
            if _Army:DoesRespawn() then
                if _Army:GetTroopCount() == _Army:GetMaxTroopCount() and _Army:HasFullStrength() then
                    _Army:SetState(ArmyStates.Decide);
                else
                    if _Army:IsInitialSpawn() then
                        _Army:SetHasInitialSpawned();
                        repeat
                            _Army:SpawnTroop()
                        until (_Army:GetTroopCount() == _Army:GetMaxTroopCount())
                        _Army:SetLastRespawn(Logic.GetTime());
                    else
                        if _Army:GetRespawnTime() + _Army:GetLastRespawn() < Logic.GetTime() then
                            if _Army:SpawnTroop() then
                                _Army:SetLastRespawn(Logic.GetTime());
                            end
                        end
                        _Army:RefillWeakGroups(true);
                    end
                end
            else
                if _Army:GetTroopCount() == _Army:GetMaxTroopCount() and _Army:HasFullStrength() then
                    _Army:SetStrength(_Army:CalculateStrength());
                    _Army:SetState(ArmyStates.Decide);
                else
                    local UnemployedID = self:GetNextUnemployedLeader(_PlayerID, _Army:GetHomePosition());
                    if UnemployedID ~= 0 then
                        _Army:BindGroup(UnemployedID);
                    else
                        if self:IsNecessaryToHireLeader(_PlayerID) then
                            local RallyPointPos = GetPosition(_Army:GetHomePosition());
                            _Army:OnTypeToRecruitSelectedBehavior(_Army:GetTroopCatalog());
                            _Army:BuyUnit(_Army:GetChosenTypeToRecruit());
                            local UnemployedID = self:GetNextUnemployedLeader(_PlayerID, _Army:GetHomePosition());
                            if UnemployedID ~= 0 then
                                local Max = Logic.LeaderGetMaxNumberOfSoldiers(UnemployedID);
                                if self:DoesIgnoreMilitaryCosts(self:GetPlayerID()) then
                                    self:CheatSoldierCosts(_Army:GetChosenTypeToRecruit(), Max);
                                end
                                _Army:BindGroup(UnemployedID);
                            end
                        end
                    end
                    _Army:RefillWeakGroups(self:DoesIgnoreMilitaryCosts(_Army:GetPlayerID()));
                end
            end
        end
    end
end

-- ~~~ Group controller ~~~ --

function TroopGenerator.AI:ControlArmyMember(_PlayerID, _Army)
    if self[_PlayerID] then
        local MemberList = _Army:GetMembers();
        for i= table.getn(MemberList), 1, -1 do
            if not MemberList[i]:IsAlive() then
                _Army:UnbindGroup(MemberList[i]);
            else
                if MemberList[i]:GetState() == GroupState.Default then
                    MemberList[i]:ChoseFormation();
                    if _Army:GetState() == ArmyStates.Attack then
                        if not MemberList[i]:PrioritizedAttackController(_Army) then
                            local EnemyList = MemberList[i]:GetEnemiesInSight();
                            if table.getn(EnemyList) == 0 then
                                if not MemberList[i]:IsNear(_Army:GetPosition(), 1500) then
                                    MemberList[i]:SetState(GroupState.Scattered);
                                    MemberList[i]:Stop();
                                else
                                    if not MemberList[i]:IsWalking() then
                                        MemberList[i]:Move(_Army:GetCurrentWaypoint());
                                    end
                                end
                            else
                                if not MemberList[i]:IsNear(_Army:GetPosition(), 4500) then
                                    MemberList[i]:SetState(GroupState.Scattered);
                                    MemberList[i]:Stop();
                                else
                                    if not MemberList[i]:IsFighting() then
                                        if not MemberList[i]:TargetEnemiesInSight(EnemyList, _Army) then
                                            if not MemberList[i]:IsWalking() then
                                                MemberList[i]:Move(_Army:GetCurrentWaypoint());
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif _Army:GetState() == ArmyStates.Guard then
                        if not MemberList[i]:PrioritizedAttackController(_Army) then
                            if not MemberList[i]:IsNear(_Army:GetPosition(), 2000) then
                                MemberList[i]:SetState(GroupState.Scattered);
                                MemberList[i]:Stop();
                            end
                        end
                    elseif _Army:GetState() == ArmyStates.Retreat then
                        if not MemberList[i]:IsWalking() then
                            MemberList[i]:Move(_Army:GetHomePosition());
                        end
                    elseif _Army:GetState() == ArmyStates.Refill then
                        if not MemberList[i]:IsFighting() then
                            local EnemyList = MemberList[i]:GetEnemiesInSight();
                            if table.getn(EnemyList) > 0 then
                                MemberList[i]:TargetEnemiesInSight(EnemyList, _Army);
                            end
                        end
                    end
                elseif MemberList[i]:GetState() == GroupState.Scattered then
                    if MemberList[i]:IsNear(_Army:GetPosition(), 500) then
                        MemberList[i]:SetState(GroupState.Default);
                        MemberList[i]:Stop();
                    else
                        if not MemberList[i]:IsWalking() then
                            MemberList[i]:Move(_Army:GetPosition());
                        end
                    end
                end
            end
        end
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ~~~                     TroopGenerator.Army                       ~~~ --
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

ArmyTroopTypeToBarracks = {
    -- Barracks
    ["BlackKnightLeaderMace1"] = UpgradeCategories.Barracks,
    ["Evil_LeaderBearman"]     = UpgradeCategories.Barracks,
    ["LeaderBandit"]           = UpgradeCategories.Barracks,
    ["LeaderBarbarian"]        = UpgradeCategories.Barracks,
    ["LeaderPoleArm"]          = UpgradeCategories.Barracks,
    ["LeaderSword"]            = UpgradeCategories.Barracks,

    -- Archery
    ["Evil_LeaderSkirmisher"]  = UpgradeCategories.Archery,
    ["LeaderBanditBow"]        = UpgradeCategories.Archery,
    ["LeaderBow"]              = UpgradeCategories.Archery,
    ["LeaderRifle"]            = UpgradeCategories.Archery,

    -- Stables
    ["LeaderCavalry"]          = UpgradeCategories.Stable,
    ["LeaderHeavyCavalry"]     = UpgradeCategories.Stable,

    -- Foundry
    ["PV_Cannon1"]             = UpgradeCategories.Foundry,
    ["PV_Cannon2"]             = UpgradeCategories.Foundry,
    ["PV_Cannon3"]             = UpgradeCategories.Foundry,
    ["PV_Cannon4"]             = UpgradeCategories.Foundry,
}

ArmyLeaderToSoldierUpgradeCategory = {
    ["BlackKnightLeaderMace1"] = UpgradeCategories.BlackKnightSoldierMace1,
    ["Evil_LeaderBearman"]     = UpgradeCategories.Evil_SoldierBearman,
    ["Evil_LeaderSkirmisher"]  = UpgradeCategories.Evil_SoldierSkirmisher,
    ["LeaderBandit"]           = UpgradeCategories.SoldierBandit,
    ["LeaderBarbarian"]        = UpgradeCategories.SoldierBarbarian,
    ["LeaderPoleArm"]          = UpgradeCategories.SoldierPoleArm,
    ["LeaderSword"]            = UpgradeCategories.SoldoerSword,
    ["LeaderBanditBow"]        = UpgradeCategories.SoldierBanditBow,
    ["LeaderBow"]              = UpgradeCategories.SoldierBow,
    ["LeaderRifle"]            = UpgradeCategories.SoldierRifle,
    ["LeaderCavalry"]          = UpgradeCategories.SoldierCavalry,
    ["LeaderHeavyCavalry"]     = UpgradeCategories.SoldierHeavyCavalry,
}

ArmyCannonTypeToUpgradeCategory = {
    ["PV_Cannon1"]             = UpgradeCategories.Cannon1,
    ["PV_Cannon2"]             = UpgradeCategories.Cannon2,
    ["PV_Cannon3"]             = UpgradeCategories.Cannon3,
    ["PV_Cannon4"]             = UpgradeCategories.Cannon4,
}

TroopGenerator.Army = {
    m_ID                = 0,
    m_PlayerID          = 0,
    m_AttackTarget      = nil,
    m_State             = 0,
    m_TroopCount        = 8,
    m_RetreatStrength   = 0;
    m_RespawnTime       = 0,
    m_LastRespawn       = 0,
    m_Attacker          = 0,

    m_RodeLength        = 2000,
    m_ScatterArea       = 1700,
    m_GatherArea        = 1000,
    m_NoEnemyDistance   = 1000,
    m_PersecutionArea   = 5000,

    m_Lifethread        = nil,
    m_Independed        = true,
    m_HomePosition        = nil,

    m_DoesRespawn       = true,
    m_InitialSpawn      = false,
    m_AttackAllowed     = true,
    m_DefenceAllowed    = true,
    m_GuardStartTime    = 0,
    m_GuardTime         = 5*60,

    m_RecruitIterator   = 0,
    m_RecruitCatalog    = {},
    m_TroopInterator    = 0,
    m_TroopCatalog      = {},
    m_Member            = {},
};

function TroopGenerator.Army:construct(
    _ID, _PlayerID, _RodeLength, _Strength, _RetreatStrength, _Spawnpoint, 
    _Lifethread, _Independed, _RespawnTime, _TroopCatalog
)
    self.m_ID               = _ID;
    self.m_PlayerID         = _PlayerID;
    self.m_State            = ArmyStates.Decide;
    self.m_TroopCount       = _Strength;
    self.m_RodeLength       = _RodeLength;
    self.m_Strength         = 0;
    self.m_RetreatStrength  = _RetreatStrength;
    self.m_HomePosition     = _Spawnpoint;
    self.m_Independed       = _Independed == true;
    self.m_DoesRespawn      = _RespawnTime ~= nil and _RespawnTime > 0;
    self.m_RespawnTime      = _RespawnTime;
    self.m_TroopCatalog     = _TroopCatalog;
    self.m_TroopInterator   = (table.getn(self.m_TroopCatalog) > 0 and 1) or 0;
    self.m_Path             = {};
    self.m_Waypoint         = 0;

    self:SetLifethread(_Lifethread);
end
class(TroopGenerator.Army);

-- ~~~ State ~~~ --

function TroopGenerator.Army:CancelState()
    self:SetTarget(nil);
    self:SetPath({});
    self:SetWaypoint(0);
    self:SetGuardStartTime(0);
    self:Stop();
end

function TroopGenerator.Army:GetID()
    return self.m_ID;
end

function TroopGenerator.Army:GetPlayerID()
    return self.m_PlayerID;
end

function TroopGenerator.Army:GetState()
    return self.m_State;
end

function TroopGenerator.Army:SetState(_State)
    self.m_State = _State;
    return self;
end

function TroopGenerator.Army:IsDead()
    if self:DoesRespawn() then
        for k, v in pairs(self:GetLifethread()) do
            if IsExisting(v) then
                return false;
            end
        end
    else
        local PlayerEntities = QuestTools.GetPlayerEntities(self:GetPlayerID(), 0);
        for i= 1, table.getn(PlayerEntities), 1 do 
            if Logic.IsSettler(PlayerEntities[i]) == 1 then
                return false;
            end
            if Logic.IsBuilding(PlayerEntities[i]) == 1 and Logic.IsConstructionComplete(PlayerEntities[i]) == 1 then
                return false;
            end
        end
    end
    return table.getn(self.m_Member) == 0;
end

function TroopGenerator.Army:IsFighting()
    for i= 1, table.getn(self.m_Member), 1 do
        if self.m_Member[i]:IsFighting() then
            return true;
        end
    end
    return false;
end

function TroopGenerator.Army:IsMoving()
    for i= 1, table.getn(self.m_Member), 1 do
        if self.m_Member[i]:IsWalking() then
            return true;
        end
    end
    return false;
end

function TroopGenerator.Army:GetPosition()
    if table.getn(self.m_Member) > 0 then
        local Names = {};
        for k, v in pairs(self.m_Member) do
            table.insert(Names, v:GetScriptName());
        end
        return QuestTools.GetGeometricFocus(unpack(Names));
    end
    return self.m_HomePosition;
end

function TroopGenerator.Army:GetHomePosition()
    return self.m_HomePosition;
end

function TroopGenerator.Army:SetHomePosition(_Home)
    self.m_HomePosition = _Home;
    return self;
end

function TroopGenerator.Army:GetLifethread()
    return self.m_Lifethread;
end

function TroopGenerator.Army:SetLifethread(_Lifethread)
    self.m_Lifethread = (type(_Lifethread) ~= "table" and {_Lifethread}) or _Lifethread;
    return self;
end

-- ~~~ Find enemies ~~~ --

function TroopGenerator.Army:GetEnemiesInArea(_Position, _Area)
    return TroopGenerator.AI:GetEnemiesInArea(self.m_PlayerID, _Position, _Area);
end

function TroopGenerator.Army:GetEnemiesInRodeLength(_Position)
    return self:GetEnemiesInArea(_Position, self:GetRodeLength());
end

-- ~~~ Movement ~~~ --

function TroopGenerator.Army:Stop()
    for k, v in pairs(self.m_Member) do
        v:Stop();
    end
end

function TroopGenerator.Army:AttackMove(_Position)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    for k, v in pairs(self.m_Member) do
        if v:IsAlive() and not v:IsWalking() and not v:IsFighting() then
            v:AttackMove(_Position);
        end
    end
end

function TroopGenerator.Army:Attack(_Target)
    for k, v in pairs(self.m_Member) do
        if v:IsAlive() then
            v:Attack(_Target);
        end
    end
end

function TroopGenerator.Army:Move(_Position)
    for k, v in pairs(self.m_Member) do
        if v:IsAlive() and not v:IsWalking() then
            v:Move(_Position);
        end
    end
end

-- ~~~ Control ~~~ --

function TroopGenerator.Army:IsAttackAllowed()
    return self.m_AttackAllowed == true;
end

function TroopGenerator.Army:SetAttackAllowed(_Flag)
    self.m_AttackAllowed = _Flag == true;
    return self;
end

function TroopGenerator.Army:IsDefenceAllowed()
    return self.m_DefenceAllowed == true;
end

function TroopGenerator.Army:SetDefenceAllowed(_Flag)
    self.m_DefenceAllowed = _Flag == true;
    return self;
end

function TroopGenerator.Army:GetTarget()
    return self.m_AttackTarget;
end

function TroopGenerator.Army:SetTarget(_AttackTarget)
    self.m_AttackTarget = _AttackTarget;
    return self;
end

function TroopGenerator.Army:GetGuardStartTime()
    return self.m_GuardStartTime;
end

function TroopGenerator.Army:SetGuardStartTime(_Time)
    self.m_GuardStartTime = _Time;
    return self;
end

function TroopGenerator.Army:GetGuardTime()
    return self.m_GuardTime;
end

function TroopGenerator.Army:SetGuardTime(_Time)
    self.m_GuardTime = _Time;
    return self;
end

function TroopGenerator.Army:GetPath()
    return self.m_Path;
end

function TroopGenerator.Army:SetPath(_Path)
    self.m_Path = _Path;
    return self;
end

function TroopGenerator.Army:GetAnchor()
    if self:GetCurrentWaypoint() then
        return self:GetCurrentWaypoint();
    else
        return self.m_HomePosition;
    end
end

function TroopGenerator.Army:GetCurrentWaypoint()
    return self.m_Path[self.m_Waypoint];
end

function TroopGenerator.Army:GetWaypoint()
    return self.m_Waypoint;
end

function TroopGenerator.Army:SetWaypoint(_Waypoint)
    self.m_Waypoint = _Waypoint;
    if self.m_Waypoint > table.getn(self.m_Path) then
        self.m_Waypoint = table.getn(self.m_Path);
    end
    return self;
end

function TroopGenerator.Army:NextWaypoint(_Loop)
    self.m_Waypoint = self.m_Waypoint +1;
    if self.m_Waypoint > table.getn(self.m_Path) then
        if _Loop then
            self.m_Waypoint = 1;
        else
            self.m_Waypoint = table.getn(self.m_Path);
        end
    end
    return self;
end

-- ~~~ Areas ~~~ --

function TroopGenerator.Army:GetRodeLength()
    return self.m_RodeLength;
end

function TroopGenerator.Army:SetRodeLength(_Area)
    self.m_RodeLength = _Area;
    return self;
end

function TroopGenerator.Army:GetPersecutionRange()
    return self.m_PersecutionArea;
end

function TroopGenerator.Army:SetPersecutionRange(_Area)
    self.m_PersecutionArea = _Area;
    return self;
end

-- ~~~ Strength ~~~ --

function TroopGenerator.Army:GetStrength()
    return self.m_Strength;
end

function TroopGenerator.Army:SetStrength(_Strength)
    self.m_Strength = _Strength;
    return self;
end

function TroopGenerator.Army:CalculateStrength()
    local CurrentStrength = 0;
    for i= 1, table.getn(self.m_Member), 1 do
        local ID = GetID(self.m_Member[i]:GetScriptName());
        CurrentStrength = CurrentStrength + self:GetUnitPowerLevel(Logic.GetEntityType(ID));
        if Logic.IsLeader(ID) == 1 then
            CurrentStrength = CurrentStrength + Logic.LeaderGetNumberOfSoldiers(ID);
        end
    end
    return CurrentStrength;
end

function TroopGenerator.Army:GetUnitPowerLevel(_EntityType)
    if Logic.IsEntityTypeInCategory(_EntityType, EntityCategories.Cannon) == 1 then
        if _EntityType == Entities.PV_Cannon2 then
            return 3;
        elseif _EntityType == Entities.PV_Cannon3 then
            return 6;
        elseif _EntityType == Entities.PV_Cannon4 then
            return 10;
        end
    end
    if Logic.IsEntityTypeInCategory(_EntityType, EntityCategories.CavalryHeavy) == 1 then
        return 3;
    end
    return 1;
end

function TroopGenerator.Army:DoesRetreat()
    if self.m_Strength > 0 then
        return self:CalculateStrength() / self:GetStrength() <= self:GetRetreatStrength();
    end
    return false;
end

function TroopGenerator.Army:GetRetreatStrength()
    return self.m_RetreatStrength;
end

function TroopGenerator.Army:SetRetreatStrength(_Strength)
    self.m_RetreatStrength = _Strength;
    return self;
end

function TroopGenerator.Army:GetMaxTroopCount()
    return self.m_TroopCount;
end

function TroopGenerator.Army:SetMaxTroopCount(_Strength)
    self.m_TroopCount = _Strength;
    return self;
end

function TroopGenerator.Army:HasFullStrength()
    local MemberCount = table.getn(self.m_Member);
    if self.m_TroopCount > MemberCount then
        return false;
    end
    for i= 1, MemberCount, 1 do
        local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(GetID(self.m_Member[i]:GetScriptName()));
        local MaximumSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(GetID(self.m_Member[i]:GetScriptName()));
        if MaximumSoldiers > CurrentSoldiers then
            return false;
        end
    end
    return true;
end

function TroopGenerator.Army:GetTroopCount()
    return table.getn(self.m_Member);
end

function TroopGenerator.Army:GetMembers()
    return self.m_Member;
end

function TroopGenerator.Army:CountMembersInCategory(_Category)
    local Amount = 0;
    for i= 1, table.getn(self.m_Member), 1 do
        local ID = GetID(self.m_Member[i]);
        if Logic.IsEntityInCategory(ID, _Category) == 1 then
            Amount = Amount +1;
        end
    end
    return Amount;
end

-- ~~~ Soldiers ~~~ --

function TroopGenerator.Army:KillAllGroups()
    for i= table.getn(self.m_Member), 1, -1 do
        self.m_Member[i]:Kill();
    end
end

function TroopGenerator.Army:BindGroup(_Group)
    local Name = QuestTools.CreateNameForEntity(_Group);
    if self:GetTroopCount() < self:GetMaxTroopCount() then
        if not TroopGenerator.AI:IsEntityHidenFromAI(self.m_PlayerID, Name) then
            if TroopGenerator.AI:GetArmyEntityIsEmployedIn(Name) == 0 then
                table.insert(self.m_Member, new(TroopGenerator.Group, Name));
                return true;
            end
        end
    end
    return false;
end

function TroopGenerator.Army:UnbindGroup(_Group)
    for i= table.getn(self.m_Member), 1, -1 do
        if self.m_Member[i]:GetScriptName() == _Group:GetScriptName() then
            table.remove(self.m_Member, i);
        end
    end
end

function TroopGenerator.Army:UnbindAllGroups()
    for i= table.getn(self.m_Member), 1, -1 do
        self:UnbindGroup(self.m_Member[i]);
    end
end

-- Behaviors --

function TroopGenerator.Army:OnMemberIsAttackedBehavior(_Attacker, _Defender)
    local TypeName = Logic.GetEntityTypeName(Logic.GetEntityType(_Attacker));
    if string.find(TypeName, "Tower") ~= nil then
        return;
    end
    for k, v in pairs(self:GetMembers()) do
        v:PrioritizedAttack(_Attacker);
    end
end

function TroopGenerator.Army:OnTypeToRecruitSelectedBehavior(_Catalog)
    if table.getn(_Catalog) == 0 then
        return;
    end
    self:SetTroopIterator(math.random(1, table.getn(_Catalog)));
end

function TroopGenerator.Army:OnTypeToSpawnSelectedBehavior(_Catalog)
    if table.getn(_Catalog) == 0 then
        return;
    end
    self:SetTroopIterator(self:GetTroopIterator() +1);
    if self:GetTroopIterator() > table.getn(_Catalog) then
        self:SetTroopIterator(1);
    end
end

function TroopGenerator.Army:OnAttackTargetClearedBehavior()
    local Enemies = self:GetEnemiesInRodeLength(self:GetAnchor());
    return table.getn(Enemies) == 0;
end

function TroopGenerator.Army:OnAttackTargetSelectedBehavior(_TargetList)
    local TargetList = copy(_TargetList);
    local sort = function(a, b)
        return QuestTools.GetDistance(a, self:GetHomePosition()) < QuestTools.GetDistance(b, self:GetHomePosition());
    end
    table.sort(TargetList, sort);
    return TargetList;
end

function TroopGenerator.Army:OnWaypointSelectedBehavior(_Waypoints)
    if table.getn(_Waypoints) == 0 then
        _Waypoints = {self:GetHomePosition()};
    end
    self:SetPath(_Waypoints);
    self:SetWaypoint(math.random(1, table.getn(_Waypoints)));
end

function TroopGenerator.Army:SetOnMemberIsAttackedBehavior(_Behavior)
    self.OnMemberIsAttackedBehavior = _Behavior;
    return self;
end

function TroopGenerator.Army:SetOnTypeToSpawnSelectedBehavior(_Behavior)
    self.OnTypeToSpawnSelectedBehavior = _Behavior;
    return self;
end

function TroopGenerator.Army:SetOnTypeToRecruitSelectedBehavior(_Behavior)
    self.OnTypeToRecruitSelectedBehavior = _Behavior;
    return self;
end

function TroopGenerator.Army:SetOnAttackTargetClearedBehavior(_Behavior)
    self.OnAttackTargetClearedBehavior = _Behavior;
    return self;
end

function TroopGenerator.Army:SetOnAttackTargetSelectedBehavior(_Behavior)
    self.OnAttackTargetSelectedBehavior = _Behavior;
    return self;
end

function TroopGenerator.Army:SetOnWaypointSelectedBehavior(_Behavior)
    self.OnWaypointSelectedBehavior = _Behavior;
    return self;
end

-- Respawning and recruiting --

function TroopGenerator.Army:GetTroopCatalog()
    return self.m_TroopCatalog;
end

function TroopGenerator.Army:SetTroopCatalog(_List)
    self.m_TroopCatalog = _List;
    return self;
end

function TroopGenerator.Army:GetTroopIterator()
    return self.m_TroopInterator;
end

function TroopGenerator.Army:SetTroopIterator(_Value)
    self.m_TroopInterator = _Value;
    return self;
end

function TroopGenerator.Army:GetLastRespawn(_Time)
    return self.m_LastRespawn;
end

function TroopGenerator.Army:SetLastRespawn(_Time)
    self.m_LastRespawn = _Time;
    return self;
end

function TroopGenerator.Army:IsInitialSpawn()
    return self.m_InitialSpawn == false;
end

function TroopGenerator.Army:SetHasInitialSpawned()
    self.m_InitialSpawn = true;
    return self;
end

function TroopGenerator.Army:GetRespawnTime()
    return self.m_RespawnTime;
end

function TroopGenerator.Army:DoesRespawn()
    return self.m_DoesRespawn == true;
end

function TroopGenerator.Army:IsIndependedFromLifethread()
    return self.m_Independed == true;
end

function TroopGenerator.Army:GetFreeReachableBarracksInUpgradeCategory(_UnitType)
    local List = {};
    local Key;
    if string.find(Logic.GetEntityTypeName(_UnitType), "Cannon") ~= nil then
        Key = QuestTools.GetKeyByValue(_UnitType, Entities);
    else
        Key = QuestTools.GetKeyByValue(_UnitType, UpgradeCategories);
    end
    if Key then
        local Types = {Logic.GetBuildingTypesInUpgradeCategory(ArmyTroopTypeToBarracks[Key])};
        for i= 2, Types[1]+1, 1 do
            local Buildings = {Logic.GetPlayerEntities(self:GetPlayerID(), Types[i], 16)};
            for j= 2, Buildings[1]+1, 1 do
                local x, y, z = Logic.EntityGetPos(Buildings[j]);
                if  Logic.IsConstructionComplete(Buildings[j]) == 1
                and not InterfaceTool_IsBuildingDoingSomething(Buildings[j])
                and Logic.GetPlayerEntitiesInArea(self:GetPlayerID(), 0, x, y, 800, 4) < 4 then
                    local Position = QuestTools.GetReachablePosition(self:GetHomePosition(), Buildings[j]);
                    if Position then
                        table.insert(List, Buildings[j]);
                    end
                end
            end
        end
    end
    return List;
end

function TroopGenerator.Army:BuyUnit(_UnitType)
    if not self:HasSpaceForUnit(_UnitType) then
        return;
    end
    local List = self:GetFreeReachableBarracksInUpgradeCategory(_UnitType);
    if table.getn(List) > 0 then
        local IsFoundry = string.find(Logic.GetEntityTypeName(Logic.GetEntityType(List[1])), "Foundry") ~= nil;
        if not IsFoundry then
            if TroopGenerator.AI:DoesIgnoreMilitaryCosts(self:GetPlayerID()) then
                self:CheatLeaderCosts(_UnitType);
            end
            Logic.BarracksBuyLeader(List[1], _UnitType);
        else
            if TroopGenerator.AI:DoesIgnoreMilitaryCosts(self:GetPlayerID()) then
                self:CheatCannonCosts(_UnitType);
            end
            local PlayerID = GUI.GetPlayerID();
            local SelectedEntities = {GUI.GetSelectedEntities()};
            GUI.SetControlledPlayer(self:GetPlayerID());
            GUI.BuyCannon(List[1], _UnitType);
            GUI.SetControlledPlayer(PlayerID);
            Logic.PlayerSetGameStateToPlaying(PlayerID);
            Logic.ForceFullExplorationUpdate();
            for i = 1, table.getn(SelectedEntities), 1 do
                GUI.SelectEntity(SelectedEntities[i]);
            end
        end
    end
end

function TroopGenerator.Army:HasSpaceForUnit(_UnitType)
    if TroopGenerator.AI:DoesIgnoreVillageCenterLimit(self:GetPlayerID()) then
        return true;
    end

    -- Calculage current usage
    local MaximumUsage = Logic.GetPlayerAttractionLimit(self:GetPlayerID());
    local CurrentUsage = Logic.GetPlayerAttractionUsage(self:GetPlayerID());
    local Usage = MaximumUsage -CurrentUsage;
    -- Calculate future usage (reserved space for soldiers)
    for k, v in pairs(QuestTools.GetAllLeader(self:GetPlayerID())) do
        local MaximumSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(v);
        local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(v);
        Usage = Usage + (MaximumSoldiers - CurrentSoldiers);
    end

    return Usage >= self:GetSpaceNeededForUnit(_UnitType);
end

function TroopGenerator.Army:GetSpaceNeededForUnit(_UnitType)
    if string.find(Logic.GetEntityTypeName(_UnitType), "Cannon") ~= nil then
        return 5;
    end
    local LeaderType = Logic.GetSettlerTypeByUpgradeCategory(_UnitType, self:GetPlayerID());
    local LeaderTypeName = Logic.GetEntityTypeName(LeaderType);
    if string.find(LeaderTypeName, "Evil") ~= nil then
        return 17;
    end
    if string.find(LeaderTypeName, "Cavalry") ~= nil then
        return 8;
    end
    if string.find(LeaderTypeName, "Sword3") ~= nil or string.find(LeaderTypeName, "Sword4") ~= nil
    or string.find(LeaderTypeName, "PoleArm3") ~= nil or string.find(LeaderTypeName, "PoleArm4") ~= nil
    or string.find(LeaderTypeName, "Bow3") ~= nil or string.find(LeaderTypeName, "Bow4") ~= nil
    or string.find(LeaderTypeName, "Rifle2") ~= nil then
        return 9;
    end
    return 5;
end

function TroopGenerator.Army:CheatLeaderCosts(_UnitType)
    QuestTools.RemoveResourcesFromPlayer(
        self:GetPlayerID(),
        QuestTools.GetMilitaryCostsTable(self:GetPlayerID(), _UnitType)
    );
end

function TroopGenerator.Army:CheatCannonCosts(_UnitType)
    local CannonCosts = {};
    local CannonUpCat = ArmyCannonTypeToUpgradeCategory[Logic.GetEntityTypeName(_UnitType)];
    if CannonUpCat then
        QuestTools.RemoveResourcesFromPlayer(
            self:GetPlayerID(),
            QuestTools.GetMilitaryCostsTable(self:GetPlayerID(), CannonUpCat)
        );
    end
end

function TroopGenerator.Army:CheatSoldierCosts(_UnitType, _Amount)
    _Amount = Amount or 16;
    if ArmyLeaderToSoldierUpgradeCategory[_UnitType] then
        local SoldierCosts = QuestTools.GetSoldierCostsTable(self:GetPlayerID(), ArmyLeaderToSoldierUpgradeCategory[_UnitType]);
        for i= 1, Amount, 1 do
            QuestTools.RemoveResourcesFromPlayer(self:GetPlayerID(), SoldierCosts);
        end
    end
end

function TroopGenerator.Army:GetChosenTypeToRecruit()
    local CatalogSize = table.getn(self.m_TroopCatalog);
    if CatalogSize == 0 then
        return;
    end
    return self.m_TroopCatalog[self:GetTroopIterator()];
end

function TroopGenerator.Army:SpawnTroop()
    if self:GetTroopCount() >= self:GetMaxTroopCount() then
        return false;
    end
    local CatalogSize = table.getn(self.m_TroopCatalog);
    if CatalogSize == 0 then
        return false;
    end
    self:OnTypeToSpawnSelectedBehavior(self:GetTroopCatalog());
    local TroopID = self:CreateGroup(
        self.m_PlayerID,
        self.m_TroopCatalog[self.m_TroopInterator][1],
        16,
        GetPosition(self.m_HomePosition),
        self.m_TroopCatalog[self.m_TroopInterator][2] or 3
    );
    local ScriptName = QuestTools.CreateNameForEntity(TroopID);
    self:BindGroup(ScriptName);
    self:SetStrength(self:CalculateStrength());
    return true;
end

function TroopGenerator.Army:RefillWeakGroups(_Cheat)
    for i= table.getn(self.m_Member), 1, -1 do
        local ScriptName = self.m_Member[i]:GetScriptName();
        if IsExisting(ScriptName) then
            if self.m_Member[i]:IsRefillable() then
                if IsNear(ScriptName, self.m_HomePosition, 2000) then
                    if _Cheat then
                        self.m_Member[i]:Refill();
                    else
                        local SoldierUpCat = Logic.LeaderGetSoldierUpgradeCategory(GetID(self.m_Member[i]:GetScriptName()));
                        local SoldierCosts = QuestTools.GetSoldierCostsTable(self:GetPlayerID(), SoldierUpCat);
                        if QuestTools.HasEnoughResources(self:GetPlayerID(), SoldierCosts) then
                            QuestTools.RemoveResourcesFromPlayer(_PlayerID, SoldierCosts);
                            self.m_Member[i]:Refill();
                        end
                    end
                else
                    local Position = QuestTools.GetReachablePosition(ScriptName, self.m_HomePosition);
                    if Position then
                        self.m_Member[i]:Move(Position)
                    else
                        self.m_Member[i]:Kill();
                    end
                end
            end
        end
    end
end

function TroopGenerator.Army:CreateGroup(_PlayerID, _LeaderType, _MaxSoldiers, _Position, _Experience)
    return AI.Entity_CreateFormation(
        _PlayerID,
        _LeaderType,
        0,
        _MaxSoldiers,
        _Position.X,
        _Position.Y,
        0,
        0,
        _Experience,
        _MaxSoldiers
    );
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ~~~                       TroopGenerator.Group                         ~~~ --
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

-- States of an member
GroupState = {
    Default     = 1,
    Scattered   = 2,
}

---
-- List of targeting priorities for the different categories of enemies. The
-- higher the number the higher the priority. Negative values are setting the
-- priority below the average. This can be used to ignore enemy categories
-- if better targets are available.
-- 
-- <p><b>Note:</b> Use EntityCategories here!</p>
--
-- @field Cannon       Attack priority for cannons
-- @field HeavyCavalry Attack priority for heavy cavalry
-- @field Sword        Attack priority for swordsmen
-- @field Spear        Attack priority for spearmen
-- @field Ranged       Attack priority for bowmen and light cavalry
-- @field Rifle        Attack priority for marksmen
-- @within Constants
--
GroupTargetingPriorities = {};

-- Attack priority for cannons.
GroupTargetingPriorities.Cannon = {
    ["MilitaryBuilding"] = 10,
    ["EvilLeader"] = 5,
    ["VillageCenter"] = 4,
    ["Headquarters"] = 3,
    ["LongRange"] = 2,
    ["Melee"] = 2,
};

-- Attack priority for heavy cavalry.
GroupTargetingPriorities.HeavyCavalry = {
    ["Hero"] = 6,
    ["MilitaryBuilding"] = 5,
    ["Cannon"] = 5,
    ["LongRange"] = 4,
    ["Hero10"] = 4,
    ["Hero4"] = 4,
    ["Sword"] = 3,
    ["Hero4"] = 1,
    ["Spear"] = -100,
};

-- Attack priority for swordmen.
GroupTargetingPriorities.Sword = {
    ["Hero"] = 6,
    ["Spear"] = 5,
    ["Cannon"] = 5,
    ["LongRange"] = 3,
    ["MilitaryBuilding"] = 1,
    ["CavalryHeavy"] = -100,
};

-- Attack priority for spearmen.
GroupTargetingPriorities.Spear = {
    ["CavalryHeavy"] = 6,
    ["MilitaryBuilding"] = 5,
    ["CavalryLight"] = 3,
    ["Hero"] = 2,
    ["Sword"] = -2,
    ["LongRange"] = -100,
    ["Sword"] = -100,
};

-- Attack priority for bowmen.
GroupTargetingPriorities.Ranged = {
    ["MilitaryBuilding"] = 15,
    ["Hero10"] = 6,
    ["Hero4"] = 6,
    ["VillageCenter"] = 4,
    ["Headquarters"] = 4,
    ["CavalryHeavy"] = 3,
    ["CavalryLight"] = 2,
    ["Hero"] = 2,
};

-- Attack priority for marksmen.
GroupTargetingPriorities.Rifle = {
    ["MilitaryBuilding"] = 15,
    ["Hero10"] = 6,
    ["EvilLeader"] = 6,
    ["VillageCenter"] = 4,
    ["Headquarters"] = 4,
    ["LongRange"] = 2,
    ["Cannon"] = 2,
    ["Melee"] = -100,
};

TroopGenerator.Group = {
    m_PersecutionArea = 5000,
    m_PrioritizedTarget = {
        Target   = 0,
        TimeLeft = 0,
    },
};

function TroopGenerator.Group:construct(_ScriptName)
    self.m_ScriptName       = _ScriptName;
    self.m_State            = GroupState.Default;
end
class(TroopGenerator.Group);

-- ~~~ Behavior ~~~ --

function TroopGenerator.Group:TargetEnemiesInSight(_EnemyList, _Army)
    local ID = GetID(self.m_ScriptName);
    -- Check if member is too far away from the army position
    if QuestTools.GetDistance(_Army:GetAnchor(), _Army:GetPosition()) > _Army:GetRodeLength() then
        if QuestTools.GetDistance(self.m_ScriptName, _Army:GetPosition()) > 3000 then
            return false;
        end
    end
    -- Call hero controller
    if Logic.IsEntityInCategory(ID, EntityCategories.Hero) == 1 then
        -- TODO: Implement
        -- Heros need special treatment because they have to use their skills.
        -- This is currently out of scoupe because heroes are not added to an
        -- army by default.
        return false;
    end

    -- Call evil units troop controller
    if Logic.IsEntityInCategory(ID, EntityCategories.EvilLeader) == 1 then
        if Logic.GetEntityType(ID) == Entities.CU_Evil_LeaderSkirmisher then
            return self:TargetEnemiesInSightOfMember(_EnemyList, GroupTargetingPriorities.Ranged);
        end
        return self:TargetEnemiesInSightOfMember(_EnemyList, GroupTargetingPriorities.Sword);
    end
    -- Call heavy cavalry troop controller
    if Logic.IsEntityInCategory(ID, EntityCategories.CavalryHeavy) == 1 then
        return self:TargetEnemiesInSightOfMember(_EnemyList, GroupTargetingPriorities.HeavyCavalry);
    end
    -- Call normal melee troop controller
    if Logic.IsEntityInCategory(ID, EntityCategories.Sword) == 1 then
        return self:TargetEnemiesInSightOfMember(_EnemyList, GroupTargetingPriorities.Sword);
    end
    -- Call normal melee troop controller
    if Logic.IsEntityInCategory(ID, EntityCategories.Spear) == 1 then
        return self:TargetEnemiesInSightOfMember(_EnemyList, GroupTargetingPriorities.Spear);
    end
    -- Call rifle troop controller
    if Logic.IsEntityInCategory(ID, EntityCategories.Rifle) == 1 then
        return self:TargetEnemiesInSightOfMember(_EnemyList, GroupTargetingPriorities.Rifle);
    end
    -- Call bow troop controller
    if Logic.IsEntityInCategory(ID, EntityCategories.LongRange) == 1 then
        return self:TargetEnemiesInSightOfMember(_EnemyList, GroupTargetingPriorities.Ranged);
    end
    -- Call cannon troop controller
    if Logic.IsEntityInCategory(ID, EntityCategories.Cannon) == 1 then
        return self:TargetEnemiesInSightOfMember(_EnemyList, GroupTargetingPriorities.Cannon);
    end
    -- Default false
    return false;
end

function TroopGenerator.Group:TargetEnemiesInSightOfMember(_EnemyList, _Priority)
    if table.getn(_EnemyList) == 0 then
        return false;
    end
    local EnemyList = self:SortEnemiesByPriority(_EnemyList, _Priority);
    self:Attack(EnemyList[1]);
    return true;
end

function TroopGenerator.Group:SortEnemiesByPriority(_EnemyList, _Priority)
    local EnemyList = copy(_EnemyList);
    local SortFunction = function(a, b)
        local Sight     = (self:GetSight()+3000)/1000;
        local Distance1 = QuestTools.GetDistance(a, self.m_ScriptName) / 1000;
        local Priority1 = (Sight-Distance1);
        for k, v in pairs(QuestTools.GetEntityCategoriesAsString(a)) do
            Priority1 = Priority1 + (_Priority[v] or 0);
        end
        local Distance2 = QuestTools.GetDistance(b, self.m_ScriptName) / 1000;
        local Priority2 = (Sight-Distance2);
        for k, v in pairs(QuestTools.GetEntityCategoriesAsString(b)) do
            Priority2 = Priority2 + (_Priority[v] or 0);
        end
        return Priority1 > Priority2;
    end
    table.sort(EnemyList, SortFunction);
    return EnemyList;
end

function TroopGenerator.Group:ChoseFormation(_Function)
    if _Function then
        _Function(self);
        return;
    end
    local ID = GetID(self:GetScriptName());
    if Logic.IsEntityInCategory(ID, EntityCategories.EvilLeader) == 1 then
        return;
    elseif Logic.IsEntityInCategory(ID, EntityCategories.Spear) == 1
    or     Logic.IsEntityInCategory(ID, EntityCategories.Sword) == 1 then
        Logic.LeaderChangeFormationType(ID, 2);
        return;
    elseif Logic.IsEntityInCategory(ID, EntityCategories.CavalryHeavy) == 1 then
        Logic.LeaderChangeFormationType(ID, 6);
        return;
    end
    Logic.LeaderChangeFormationType(ID, 4);
end

-- ~~~ Methods ~~~ --

function TroopGenerator.Group:GetScriptName()
    return self.m_ScriptName;
end

function TroopGenerator.Group:GetPlayer()
    return Logic.EntityGetPlayer(GetID(self.m_ScriptName));
end

function TroopGenerator.Group:GetSight()
    return Logic.GetEntityExplorationRange(GetID(self.m_ScriptName)) * 100;
end

function TroopGenerator.Group:GetEnemiesInSight()
    local AllEnemiesInSight = {};
    local PlayerID = self:GetPlayer();
    for i= 1, 8, 1 do
        if i ~= PlayerID and Logic.GetDiplomacyState(PlayerID, i) == Diplomacy.Hostile then
            local x, y, z = Logic.EntityGetPos(GetID(self.m_ScriptName));
            local PlayerEntities = {Logic.GetPlayerEntitiesInArea(i, 0, x, y, self:GetSight()+3000, 16)};
            for j= 2, PlayerEntities[1]+1, 1 do
                if  ((Logic.IsBuilding(PlayerEntities[j]) == 1 or Logic.IsLeader(PlayerEntities[j]) == 1) or
                     (Logic.IsHero(PlayerEntities[j]) == 1 and Logic.GetCamouflageTimeLeft(PlayerEntities[j]) == 0))
                and Logic.GetEntityHealth(PlayerEntities[j]) > 0 then
                    local ArmyID = TroopGenerator.AI:GetArmyEntityIsEmployedIn(PlayerEntities[j]);
                    if ArmyID == 0 then
                        table.insert(AllEnemiesInSight, PlayerEntities[j]);
                    else
                        if TroopGenerator.AI[i].Armies[ArmyID] and TroopGenerator.AI[i].Armies[ArmyID]:GetState() ~= ArmyStates.Retreat then
                            table.insert(AllEnemiesInSight, PlayerEntities[j]);
                        end
                    end
                end
            end
        end
    end
    return AllEnemiesInSight;
end

function TroopGenerator.Group:GetState()
    return self.m_State;
end

function TroopGenerator.Group:SetState(_State)
    self.m_State = _State;
    return self;
end

function TroopGenerator.Group:GetPriorityMap()
    local ID = GetID(self.m_ScriptName);
    if Logic.IsEntityInCategory(ID, EntityCategories.Cannon) == 1 then
        return GroupTargetingPriorities.Cannon;
    elseif Logic.IsEntityInCategory(ID, EntityCategories.LongRange) == 1 then
        return GroupTargetingPriorities.Ranged;
    end
    return GroupTargetingPrioritiesMelee;
end

function TroopGenerator.Group:Move(_Position)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    Logic.MoveSettler(GetID(self.m_ScriptName), _Position.X, _Position.Y);
    return self;
end

function TroopGenerator.Group:Attack(_Target)
    Logic.GroupAttack(GetID(self.m_ScriptName), GetID(_Target));
    return self;
end

function TroopGenerator.Group:PrioritizedAttack(_Target, _Time)
    _Time = _Time or 15;
    if self.m_PrioritizedTarget.Target ~= 0 then
        return;
    end
    self.m_PrioritizedTarget.Target   = GetID(_Target);
    self.m_PrioritizedTarget.TimeLeft = _Time;
    self:AttackMove(_Target);
end

function TroopGenerator.Group:PrioritizedAttackController(_Army)
    local ID = self.m_PrioritizedTarget.Target;
    if not IsExisting(ID) or Logic.GetEntityHealth(ID) == 0 then
        self.m_PrioritizedTarget.Target = 0;
        self.m_PrioritizedTarget.TimeLeft = 0;
        return false;
    end
    self.m_PrioritizedTarget.TimeLeft = self.m_PrioritizedTarget.TimeLeft -1;
    if self.m_PrioritizedTarget.TimeLeft < 1 then
        self.m_PrioritizedTarget.Target = 0;
        self.m_PrioritizedTarget.TimeLeft = 0;
        self:Move(_Army:GetPosition());
        return false;
    end
    if not self:IsFighting() then
        self:AttackMove(ID);
    end
    return true;
end

function TroopGenerator.Group:AttackMove(_Position)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    Logic.GroupAttackMove(GetID(self.m_ScriptName), _Position.X, _Position.Y);
    return self;
end

function TroopGenerator.Group:Stop()
    GUI.SettlerStand(GetID(self.m_ScriptName));
end

function TroopGenerator.Group:Destroy()
    DestroyEntity(self.m_ScriptName);
end

function TroopGenerator.Group:Kill()
    local ID = GetID(self.m_ScriptName);
    if IsExisting(self.m_ScriptName) then
        if Logic.IsLeader(ID) == 1 then
            local Soldiers = {Logic.GetSoldiersAttachedToLeader(ID)};
            for i=2, Soldiers[1] +1, 1 do
                Logic.HurtEntity(Soldiers[i], Logic.GetEntityHealth(Soldiers[i]));
            end
        end
        Logic.HurtEntity(ID, Logic.GetEntityHealth(ID));
    end
end

function TroopGenerator.Group:Refill()
    if not self:IsFull() then
        local CanRecruit = true;
        local PlayerID   = Logic.EntityGetPlayer(GetID(self.m_ScriptName));

        -- Check attraction limit
        if not TroopGenerator.AI:DoesIgnoreVillageCenterLimit(PlayerID) then
            local MaximumUsage = Logic.GetPlayerAttractionLimit(PlayerID);
            local CurrentUsage = Logic.GetPlayerAttractionUsage(PlayerID);
            CanRecruit = (MaximumUsage - CurrentUsage) > 1;
        end

        if CanRecruit then
            Tools.CreateSoldiersForLeader(GetID(self.m_ScriptName), 1);
        end
    end
end

function TroopGenerator.Group:IsAlive()
    return IsExisting(self.m_ScriptName) and Logic.GetEntityHealth(GetID(self.m_ScriptName)) > 0;
end

function TroopGenerator.Group:IsAttackingPriorizedTarget()
    return self.m_PrioritizedTarget.Target ~= 0;
end

function TroopGenerator.Group:IsDoingSomething()
    return self:IsFighting() or self:IsTraining() or self:IsWalking();
end

function TroopGenerator.Group:IsFighting()
    local Task = Logic.GetCurrentTaskList(GetID(self.m_ScriptName));
    return self:IsAlive() and Task and string.find(Task, "BATTLE") ~= nil;
end

function TroopGenerator.Group:IsFull()
    local ID = GetID(self.m_ScriptName);
    return Logic.LeaderGetNumberOfSoldiers(ID) == Logic.LeaderGetMaxNumberOfSoldiers(ID);
end

function TroopGenerator.Group:IsRefillable()
    local ID = GetID(self.m_ScriptName);
    if Logic.IsLeader(ID) == 0 or Logic.LeaderGetMaxNumberOfSoldiers(ID) == 0 then
        return false;
    end
    if not self:IsAlive() or self:IsFighting() or self:IsTraining() or self:IsFull() then
        return false;
    end
    return true;
end

function TroopGenerator.Group:IsNear(_ArmyPosition, _Distance)
    return self:IsAlive() and QuestTools.GetDistance(self.m_ScriptName, _ArmyPosition) <= _Distance;
end

function TroopGenerator.Group:IsTraining()
    return self:IsAlive() and IsExisting(Logic.LeaderGetBarrack(GetID(self.m_ScriptName))) == true;
end

function TroopGenerator.Group:IsWalking()
    return self:IsAlive() and Logic.IsEntityMoving(GetID(self.m_ScriptName)) == true;
end

