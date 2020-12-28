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
ArmyBehavior = {
    Decide = 1,
    Attack  = 2,
    Guard   = 3,
    Retreat = 4,
    Refill  = 5,
}

---
-- Table of army behavior.
-- @field EnemyIsInSight Enemies in sight of army
-- @field MemberIsAttacked Enemies attacked a member of the army
-- @field SelectPurchasedType Selects the next purchased type
-- @field SelectSpawnedType Selects the next spawned type
-- @field SelectAttackTarget Selects the attack target
-- @field SelectPatrolTarget Selects the first patrol point
-- @field FormationIsChosen Selects the formation for members
-- @within Constants
--
ArmySubBehavior = {
    EnemyIsInSight      = 1,
    MemberIsAttacked    = 2,
    SelectPurchasedType = 3,
    SelectSpawnedType   = 4,
    SelectAttackTarget  = 5,
    SelectPatrolTarget  = 6,
    FormationIsChosen   = 7,
};

---
-- Table of army categories.
-- @field City City troop types
-- @field BlackKnight Black knight troop types
-- @field Bandit Bandit troop types
-- @field Barbarian Barbarian troop types
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
    TroopGenerator.CreatedAiPlayers[_PlayerID] = true;
    TroopGenerator.AI:CreateAI(_PlayerID, _SerfAmount, _HomePosition, _Strength, _TechLevel, _Construct, _Rebuild);
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
-- @usage ArmyDisableAttackAbility(2, 1, true)
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
-- function can be force an army to stay on its spawnpoint.
--
-- @param[type=number]  _PlayerID ID of player
-- @param               _Army     Name or ID of army
-- @param[type=boolean] _Flag     Ability to attack
-- @within Methods
-- 
-- @usage ArmyDisablePatrolAbility(2, 1, true)
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
        Strength        = _Strength or 8,
        RetreatStrength = 0.3, 
        HomePosition    = _Position,
        FrontalAttack   = false,
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
        Strength                 = _Strength or 8,
        HomePosition             = _Position,
        FrontalAttack            = false,
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
function HideEntityFromAI(_PlayerID, _Entity, _HiddenFlag)
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
function IsEntityHiddenFromAI(_PlayerID, _Entity)
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
function DestroyAIPlayerPatrolPoint(_PlayerID, _ID)
    if not TroopGenerator.CreatedAiPlayers[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    TroopGenerator.AI:RemoveDefenceTarget(_PlayerID, _ID);
end

---
-- Restores all default sub behavior for the army.
-- @param[type=number] _PlayerID ID of player
-- @param[type=number] _ArmyID   ID of army
-- @within Methods
--
function ResetArmySubBehaviors(_PlayerID, _ArmyID)
    if not TroopGenerator.AI[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    if not TroopGenerator.AI[_PlayerID].Armies[_ArmyID] then
        assert(false, "Army " .._ArmyID.. " not initalized for player " .._PlayerID.. "!");
        return;
    end
    TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:CreateDefaultBehavior();
end

---
-- Overrides the sub behavior of the army with the given function.
--
-- <b>Note:</b> Only change sub behavior if you know what you are doing! You
-- might break the army controller!
--
-- <table border="1">
-- <tr>
-- <td><b>Behavior</b></td>
-- <td><b>Description</b></td>
-- </tr>
-- <tr>
-- <td>EnemyIsInSight</td>
-- <td>Called when ever an enemy is in sight. Passes list of enemies to the
-- controller function.</td>
-- </tr>
-- <tr>
-- <td>MemberIsAttacked</td>
-- <td>Called when ever an enemy attacks an member of the army.</td>
-- </tr>
-- <tr>
-- <td>SelectPurchasedType</td>
-- <td><b>Note:</b> Only used if the army purchases troops!</br>
-- Passes the catalog to the controller. The controller must set the catalog
-- iterator.</td>
-- </tr>
-- <tr>
-- <td>SelectSpawnedType</td>
-- <td><b>Note:</b> Only used if the army spawns troops!</br>
-- Passes the catalog to the controller. The controller must set the catalog
-- iterator.</td>
-- </tr>
-- <tr>
-- <td>SelectAttackTarget</td>
-- <td>Passes the list of reachable attack targets to the controller function.
-- The controller must select one position, set it as path and as target.</td>
-- </tr>
-- <tr>
-- <td>SelectPatrolTarget</td>
-- <td>Passes the list of reachable patrol targets to the controller function.
-- The controller must set the path and the first waypoint. Army will loop
-- over the waypoints starting from the selected one.</td>
-- </tr>
-- <tr>
-- <td>FormationIsChosen</td>
-- <td></td>
-- </tr>
-- </table>
--
-- @param[type=number] _PlayerID   ID of player
-- @param[type=number] _ArmyID     ID of army
-- @param[type=number] _Behavior   ID of sub behavior
-- @param[type=number] _Controller Controller function
-- @within Methods
--
function ChangeArmySubBehavior(_PlayerID, _ArmyID, _Behavior, _Controller)
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
    
    if ArmySubBehavior.EnemyIsInSight == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnEnemiesInSightBehavior(_Controller);
    elseif ArmySubBehavior.MemberIsAttacked == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnMemberIsAttackedBehavior(_Controller);
    elseif ArmySubBehavior.SelectPurchasedType == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnTypeToRecruitSelectedBehavior(_Controller);
    elseif ArmySubBehavior.SelectSpawnedType == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnTypeToSpawnSelectedBehavior(_Controller);
    elseif ArmySubBehavior.SelectAttackTarget == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnAttackTargetSelectedBehavior(_Controller);
    elseif ArmySubBehavior.SelectPatrolTarget == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnWaypointSelectedBehavior(_Controller);
    elseif ArmySubBehavior.FormationIsChosen == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnFormationChosenBehavior(_Controller);
    end
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
        repairing    = _Rebuild == true,
        
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
            AI.Entity_ActivateRebuildBehaviour(_PlayerID, 60, 0);
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
    end
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
        _Data.Strength or 8,
        _Data.RetreatStrength or 0.3, 
        _Data.HomePosition,
        _Data.FrontalAttack == true,
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
        _Data.Strength or 8,
        _Data.RetreatStrength or 0.3, 
        _Data.HomePosition,
        _Data.FrontalAttack == true,
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
                        Strength		         = 8,
                        RetreatStrength          = 0.3, 
                        HomePosition             = self[_PlayerID].HomePosition,
                        FrontalAttack            = false,
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

function TroopGenerator.AI:GetNextUnemployedLeader(_PlayerID)
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
        for i= 1, table.getn(self[_PlayerID].Armies), 1 do
            if self[_PlayerID].Armies[i]:GetID() == _ArmyID then
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
            if not IsExisting(_Army:GetLifethread()) then
                local Kill = not _Army:IsIndependedFromLifethread();
                self:DropArmy(_PlayerID, _Army:GetID(), Kill);
                return;
            end
        end

        -- Select action
        if _Army:GetState() == ArmyBehavior.Decide then
            if _Army:IsAttackAllowed() then
                if _Army:GetTarget() == nil then
                    local TargetsAvailable = self:GetAllUnattendedAttackTargets(_PlayerID, _Army:GetID());
                    if table.getn(TargetsAvailable) > 0 then
                        _Army:OnAttackTargetSelectedBehavior(TargetsAvailable);
                        _Army:SetState(ArmyBehavior.Attack);
                        return;
                    end
                else
                    _Army:SetState(ArmyBehavior.Attack);
                end
            end
            if _Army:IsDefenceAllowed() then
                local GuardPath = self:GetArmyDefencePositions(_PlayerID, _Army:GetID());
                _Army:OnWaypointSelectedBehavior(GuardPath);
                _Army:SetState(ArmyBehavior.Guard);
            end
            return;
        end

        -- Attack enemies
        if _Army:GetState() == ArmyBehavior.Attack then
            local Enemies = _Army:GetEnemiesInRodeLength(_Army:GetAnchor());
            if _Army:GetTroopCount() == 0 or _Army:DoesRetreat() then
                _Army:CancelState();
                _Army:SetState(ArmyBehavior.Retreat);
            elseif table.getn(Enemies) == 0 then
                _Army:CancelState();
                _Army:SetState(ArmyBehavior.Decide);
            else
                -- if _Army:IsStretchedTooFar() then
                --     for k, v in pairs(_Army:GetMembers()) do
                --         v:SetState(GroupBehavior.Scattered);
                --     end
                -- end
            end
            return;
        end

        -- Patrol between positions
        if _Army:GetState() == ArmyBehavior.Guard then
            if _Army:GetTroopCount() == 0 or _Army:DoesRetreat() then
                _Army:CancelState();
                _Army:SetState(ArmyBehavior.Retreat);
                _Army:SetGuardStartTime(0);
            elseif not _Army:IsDefenceAllowed() then
                _Army:CancelState();
                _Army:SetState(ArmyBehavior.Decide);
                _Army:SetGuardStartTime(0);
            else
                if _Army:IsAttackAllowed() then
                    if _Army:GetTarget() ~= nil then
                        _Army:SetState(ArmyBehavior.Attack);
                    else
                        local TargetsAvailable = self:GetAllUnattendedAttackTargets(_PlayerID, _Army:GetID());
                        if table.getn(TargetsAvailable) > 0 then
                            _Army:CancelState();
                            _Army:SetState(ArmyBehavior.Decide);
                            _Army:SetGuardStartTime(0);
                            return;
                        end
                    end
                end
                if _Army:GetCurrentWaypoint() == nil then
                    local DefenceTargets = self:GetArmyDefencePositions(_PlayerID, _Army:GetID());
                    if table.getn(DefenceTargets) == 0 then
                        _Army:SetState(ArmyBehavior.Decide);
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
        if _Army:GetState() == ArmyBehavior.Retreat then
            if table.getn(_Army:GetMembers()) == 0 then
                _Army:SetLastRespawn(Logic.GetTime());
                _Army:SetState(ArmyBehavior.Refill);
            elseif QuestTools.GetDistance(_Army:GetPosition(), _Army:GetHomePosition()) <= 2000 then
                _Army:SetLastRespawn(Logic.GetTime());
                _Army:SetState(ArmyBehavior.Refill);
            end
            return;
        end

        -- Refill
        if _Army:GetState() == ArmyBehavior.Refill then
            if _Army:DoesRespawn() then
                if _Army:GetTroopCount() == _Army:GetMaxTroopCount() and _Army:HasFullStrength() then
                    _Army:SetState(ArmyBehavior.Decide);
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
                        _Army:RefillWeakGroups();
                    end
                end
            else
                if _Army:GetTroopCount() == _Army:GetMaxTroopCount() and _Army:HasFullStrength() then
                    _Army:SetStrength(_Army:CalculateStrength());
                    _Army:SetState(ArmyBehavior.Decide);
                else
                    local UnemployedID = self:GetNextUnemployedLeader(_PlayerID);
                    if UnemployedID ~= 0 then
                        _Army:BindGroup(UnemployedID);
                    else
                        if self:IsNecessaryToHireLeader(_PlayerID) then
                            _Army:OnTypeToRecruitSelectedBehavior(_Army:GetTroopCatalog());
                            -- Using BB army in background to recruit troops
                            AI.Army_BuyLeader(_PlayerID, 1, _Army:GetChosenTypeToRecruit());
                            local UnemployedID = self:GetNextUnemployedLeader(_PlayerID);
                            if UnemployedID ~= 0 then
                                local Max = Logic.LeaderGetMaxNumberOfSoldiers(UnemployedID);
                                _Army:BindGroup(UnemployedID);
                            end
                        end
                    end
                    _Army:RefillWeakGroups();
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
                if MemberList[i]:GetState() == GroupBehavior.Default then
                    MemberList[i]:OnFormationChosenBehavior(_Army:GetOnFormationChosenBehavior());
                    if _Army:GetState() == ArmyBehavior.Attack then
                        MemberList[i]:PrioritizedAttackController(_Army);
                        if MemberList[i]:IsFighting() and not MemberList[i]:IsAttackingPriorizedTarget() then
                            if not MemberList[i]:IsNear(_Army:GetPosition(), 4000) then
                                MemberList[i]:SetState(GroupBehavior.Scattered);
                                return;
                            end
                        else
                            if not MemberList[i]:IsNear(_Army:GetPosition(), 1500) then
                                MemberList[i]:SetState(GroupBehavior.Scattered);
                                return;
                            end
                        end
                        if not MemberList[i]:IsFighting() and not MemberList[i]:IsWalking() then
                            local EnemyList = MemberList[i]:GetEnemiesInSight();
                            if table.getn(EnemyList) > 0 then
                                MemberList[i]:OnEnemiesInSightBehavior(EnemyList, _Army:GetOnEnemiesInSightBehavior());
                            else
                                MemberList[i]:AttackMove(_Army:GetCurrentWaypoint());
                            end
                        end
                    elseif _Army:GetState() == ArmyBehavior.Guard then
                        if not MemberList[i]:IsNear(_Army:GetPosition(), 3000) then
                            MemberList[i]:SetState(GroupBehavior.Scattered);
                        end
                    elseif _Army:GetState() == ArmyBehavior.Retreat then
                        MemberList[i]:Move(_Army:GetHomePosition());
                    end
                elseif MemberList[i]:GetState() == GroupBehavior.Scattered then
                    if MemberList[i]:IsNear(_Army:GetPosition(), 500) then
                        MemberList[i]:SetState(GroupBehavior.Default);
                    else
                        MemberList[i]:AttackMove(_Army:GetPosition());
                    end
                end
            end
        end
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ~~~                     TroopGenerator.Army                       ~~~ --
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

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
    _FrontalAttack, _Lifethread, _Independed, _RespawnTime, _TroopCatalog
)
    self.m_ID               = _ID;
    self.m_PlayerID         = _PlayerID;
    self.m_State            = ArmyBehavior.Decide;
    self.m_TroopCount       = _Strength;
    self.m_RodeLength       = _RodeLength;
    self.m_Strength         = 0;
    self.m_RetreatStrength  = _RetreatStrength;
    self.m_HomePosition       = _Spawnpoint;
    self.m_FrontalAttack    = _FrontalAttack == true;
    self.m_Lifethread       = _Lifethread;
    self.m_Independed       = _Independed == true;
    self.m_DoesRespawn      = _RespawnTime ~= nil and _RespawnTime > 0;
    self.m_RespawnTime      = _RespawnTime;
    self.m_TroopCatalog     = _TroopCatalog;
    self.m_TroopInterator   = (table.getn(self.m_TroopCatalog) > 0 and 1) or 0;
    self.m_Path             = {};
    self.m_Waypoint         = 0;
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
        if IsExisting(self:GetLifethread()) then
            return false;
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
    self.m_Lifethread = _Lifethread;
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

function TroopGenerator.Army:DoesFrontalAttack()
    return self.m_FrontalAttack == true;
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
        CurrentStrength = CurrentStrength +1;
        if Logic.IsLeader(ID) == 1 then
            CurrentStrength = CurrentStrength + Logic.LeaderGetNumberOfSoldiers(ID);
        end
    end
    return CurrentStrength;
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

-- ~~~ Gathering ~~~ --

function TroopGenerator.Army:IsAnyScattered()
    if not self:IsFighting() and not self:DoesFrontalAttack() then
        local ArmyPosition = self:GetPosition();
        for k, v in pairs(self.m_Member) do
            if not v:IsNear(ArmyPosition, 3000) then
                return true;
            end
        end
    end
    return false;
end

function TroopGenerator.Army:IsScattered()
    if not self:IsFighting() and not self:DoesFrontalAttack() then
        local ArmyPosition = self:GetPosition();
        local ArmySize = table.getn(self.m_Member);
        for i= 1, ArmySize, 1 do
            if QuestTools.GetDistance(ArmyPosition, self.m_Member[i]:GetScriptName()) > self.m_ScatterArea + 300 * (ArmySize/10) then
                return true;
            end
        end
    end
    return false;
end

function TroopGenerator.Army:IsGathered()
    local ArmyPosition = self:GetPosition();
    local ArmySize = table.getn(self.m_Member);
    for i= 1, ArmySize, 1 do
        if QuestTools.GetDistance(ArmyPosition, self.m_Member[i]:GetScriptName()) > self.m_GatherArea + 300 * (ArmySize/10) then
            return false;
        end
    end
    return true;
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

function TroopGenerator.Army:OnTypeToRecruitSelectedBehavior(_Catalog)
    if table.getn(_Catalog) == 0 then
        return;
    end
    self:SetTroopIterator(math.random(1, table.getn(_Catalog)));
end

function TroopGenerator.Army:OnMemberIsAttackedBehavior(_Attacker, _Defender)
    local TypeName = Logic.GetEntityTypeName(Logic.GetEntityType(_Attacker));
    if string.find(TypeName, "Tower") ~= nil then
        return;
    end
    for k, v in pairs(self:GetMembers()) do
        v:PrioritizedAttack(_Attacker);
    end
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

function TroopGenerator.Army:OnAttackTargetSelectedBehavior(_TargetList)
    local sort = function(a, b)
        return QuestTools.GetDistance(a, self:GetHomePosition()) < QuestTools.GetDistance(b, self:GetHomePosition());
    end
    table.sort(_TargetList, sort);
    self:SetPath({_TargetList[1]});
    self:SetWaypoint(1);
    self:SetTarget(self:GetCurrentWaypoint());
end

function TroopGenerator.Army:OnWaypointSelectedBehavior(_Waypoints)
    if table.getn(_Waypoints) == 0 then
        _Waypoints = {self:GetHomePosition()};
    end
    self:SetPath(_Waypoints);
    self:SetWaypoint(math.random(1, table.getn(_Waypoints)));
end

function TroopGenerator.Army:GetOnEnemiesInSightBehavior()
    return self.OnEnemiesInSightBehavior;
end

function TroopGenerator.Army:SetOnEnemiesInSightBehavior(_Behavior)
    self.OnEnemiesInSightBehavior = _Behavior;
    return self;
end

function TroopGenerator.Army:GetOnFormationChosenBehavior()
    return self.OnFormationChosenBehavior;
end

function TroopGenerator.Army:SetOnFormationChosenBehavior(_Behavior)
    self.OnFormationChosenBehavior = _Behavior;
    return self;
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

function TroopGenerator.Army:RefillWeakGroups()
    for i= table.getn(self.m_Member), 1, -1 do
        local ScriptName = self.m_Member[i]:GetScriptName();
        if IsExisting(ScriptName) then
            if self.m_Member[i]:IsRefillable() then
                if IsNear(ScriptName, self.m_HomePosition, 2000) then
                    self.m_Member[i]:Refill();
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

GroupBehavior = {
    Default     = 1,
    Persecuting = 2,
    Scattered   = 3,
}

GroupPriorityCannon = {
    [EntityCategories.VillageCenter] = 4,
    [EntityCategories.MilitaryBuilding] = 3,
    [EntityCategories.Headquarters] = 2,
    [EntityCategories.LongRange] = 1,
};
GroupPriorityMelee = {
    [EntityCategories.LongRange] = 3,
    [EntityCategories.MilitaryBuilding] = 2,
    [EntityCategories.Hero] = 1,
};
GroupPriorityRanged = {
    [EntityCategories.VillageCenter] = 6,
    [EntityCategories.Headquarters] = 5,
    [EntityCategories.MilitaryBuilding] = 4,
    [EntityCategories.Military] = 3,
    [EntityCategories.Hero] = 2,
    [EntityCategories.Hero10] = 2,
    [EntityCategories.Hero4] = 1,
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
    self.m_State            = GroupBehavior.Default;
end
class(TroopGenerator.Group);

-- ~~~ Behavior ~~~ --

function TroopGenerator.Group:OnEnemiesInSightBehavior(_EnemyList, _Function)
    if _Function then
        _Function(self, _EnemyList);
        return;
    end
    if self:IsAttackingPriorizedTarget() then
        return;
    end
    local EnemyCategoryMap = self:GetPriorityMap();
    local Prioritize = function(a, b)
        local Sight     = (self:GetSight()+3000)/1000;
        local Distance1 = QuestTools.GetDistance(a, self.m_ScriptName) / 1000;
        local Priority1 = (Sight-Distance1);
        for k, v in pairs(QuestTools.GetEntityCategories(a)) do
            Priority1 = Priority1 + (EnemyCategoryMap[v] or 0);
        end
        local Distance2 = QuestTools.GetDistance(b, self.m_ScriptName) / 1000;
        local Priority2 = (Sight-Distance2);
        for k, v in pairs(QuestTools.GetEntityCategories(b)) do
            Priority2 = Priority2 + (EnemyCategoryMap[v] or 0);
        end
        return Priority1 > Priority2;
    end
    table.sort(_EnemyList, Prioritize);
    self:Attack(_EnemyList[1]);
end

function TroopGenerator.Group:OnFormationChosenBehavior(_Function)
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

function TroopGenerator.Group:SetOnEnemiesInSightBehavior(_Function)
    self.OnEnemiesInSightBehavior = _Function;
    return self;
end

function TroopGenerator.Group:SetOnFormationChosenBehavior(_Function)
    self.OnFormationChosenBehavior = _Function;
    return self;
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
                if  (Logic.IsBuilding(PlayerEntities[j]) == 1 or Logic.IsLeader(PlayerEntities[j]) == 1)
                and Logic.GetEntityHealth(PlayerEntities[j]) > 0 then
                    table.insert(AllEnemiesInSight, PlayerEntities[j]);
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
        return GroupPriorityCannon;
    elseif Logic.IsEntityInCategory(ID, EntityCategories.LongRange) == 1 then
        return GroupPriorityRanged;
    end
    return GroupPriorityMelee;
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
        return;
    end
    self.m_PrioritizedTarget.TimeLeft = self.m_PrioritizedTarget.TimeLeft -1;
    if self.m_PrioritizedTarget.TimeLeft < 1 then
        self.m_PrioritizedTarget.Target = 0;
        self.m_PrioritizedTarget.TimeLeft = 0;
        self:Move(_Army:GetPosition());
        return;
    end
    if not self:IsFighting() then
        self:AttackMove(ID);
    end
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
        Tools.CreateSoldiersForLeader(GetID(self.m_ScriptName), 1);
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

