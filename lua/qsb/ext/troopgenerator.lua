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
        Default = 1,
        Advance = 2,
        Attack  = 3,
        Guard   = 4,
        Retreat = 5,
        Refill  = 6,
        Defend  = 7,
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
-- Table of army behavior.
-- @field Enemies in sight of army
-- @field A member is attacked by the enemy
-- @field Selects the next purchased type
-- @field Selects the next spawned type
-- @field Selects the attack target
-- @field Selects the first patrol point
-- @field Selects the formation for members
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
-- ~~~                                 API                                ~~~ --
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
--     Entities.PU_LeaderSword2, 3,
--     Entities.PU_LeaderBow2, 3,
--     Entities.PV_Cannon2, 0
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
    for i= 1, table.getn(arg), 2 do
        table.insert(EntityTypes, {arg[i], arg[i+1]});
    end
    assert(table.getn(EntityTypes) > 0);
    local Instance = TroopGenerator.AI:CreateSpawnArmy {
        PlayerID                 = _PlayerID,
        RodeLength               = _Area or 5000,
        Strength                 = _Strength or 8,
        HomePosition             = _Position,
        FrontalAttack            = false,
        Lifethread               = _Spawner,
        IndependedFromLifethread = false,
        RespawnTime              = _Respawn,
        RodeLength               = _Area,
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
-- <td>Called when ever a member of the army is attacked. Passes the entity ID
-- of the attacker to the controller function.</td>
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
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnMeberAttackedBehavior(_Controller);
    elseif ArmySubBehavior.MemberIsAttacked == _Behavior then
        TroopGenerator.AI[_PlayerID].Armies[_ArmyID]:SetOnEnemiesInSightBehavior(_Controller);
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
    local SerfLimit = 3 * _Strength;
    local Description = {
        serfLimit    = _SerfAmount or SerfLimit,
        constructing = _Construct == true,
        repairing    = _Rebuild == true,
        
        resources = {
            gold   = 7000 * _Strength,
            clay   = 2500 * _Strength,
            iron   = 5000 * _Strength,
            sulfur = 5000 * _Strength,
            stone  = 2500 * _Strength,
            wood   = 3000 * _Strength,
        },
        refresh = {
            updateTime = math.floor((30 / _Strength) +0.5),
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
        end
    end
end

function TroopGenerator.AI:ArmyAttackedController(_PlayerID)
    if self[_PlayerID] then
        local Attacker = Event.GetEntityID1();
        local Defender = Event.GetEntityID2();
        if Logic.EntityGetPlayer(Defender) ~= _PlayerID then
            return;
        end

        local Leader = QuestTools.SoldierGetLeader(Defender);
        local ArmyID = self:GetArmyEntityIsEmployedIn(Leader);
        for i= table.getn(self[_PlayerID].Armies), 1, -1 do
            if ArmyID == self[_PlayerID].Armies[i]:GetID() then
                self[_PlayerID].Armies[i]:CallOnMeberAttackedBehavior(Attacker, Defender);
            end
        end
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
            copy(QuestTools.FindAllEntities(i, 0, _Area, _Position), Enemies);
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
        TroopGenerator.Formation,
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
        TroopGenerator.Formation,
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
                        RodeLength               = 3000,
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
                        if v == Leader[i] then
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

function TroopGenerator.AI:IsNecessaryToHireLeader(_PlayerID)
    if self[_PlayerID] then
        local NeededAmount = self[_PlayerID].Strength * 8;
        local Leader = {};
        Leader = copy(QuestTools.GetAllLeader(_PlayerID), Leader);
        Leader = copy(QuestTools.GetAllCannons(_PlayerID), Leader);
        return NeededAmount > table.getn(Leader);
    end
    return false;
end

function TroopGenerator.AI:GetArmyEntityIsEmployedIn(_Entity)
    local Name1 = QuestTools.CreateNameForEntity(_Entity);
    for i= 1, 8, 1 do
        if self[i] then
            for j= 1, table.getn(self[i].Armies), 1 do
                for k, v in pairs(self[i].Armies[j]:GetMembers()) do
                    local Name2 = QuestTools.CreateNameForEntity(v);
                    if Name1 == Name2 then
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
        -- Update army
        _Army:ClearDead();
        -- Destroy if lifethread is destroyed
        if _Army:DoesRespawn() then
            if not IsExisting(_Army:GetLifethread()) then
                local Kill = not _Army:IsIndependedFromLifethread();
                self:DropArmy(_PlayerID, _Army:GetID(), Kill);
                return;
            end
        end

        local EnemiesInSight = _Army:GetEnemiesInRodeLength(_Army:GetPosition());

        -- Select action
        if _Army:GetState() == TroopGenerator.States.Default then
            if _Army:GetTroopCount() == 0 or _Army:DoesRetreat() then
                _Army:CancelState();
                _Army:SetState(TroopGenerator.States.Retreat);
            else
                for k, v in pairs(_Army:GetMembers()) do
                    _Army:CallOnFormationChosenBehavior(v);
                end
                if _Army:IsAttackAllowed() then
                    if _Army:GetTarget() == nil then
                        local TargetsAvailable = self:GetAllUnattendedAttackTargets(_PlayerID, _Army:GetID());
                        if table.getn(TargetsAvailable) > 0 then
                            _Army:CallOnAttackTargetSelectedBehavior(TargetsAvailable);
                            _Army:SetState(TroopGenerator.States.Attack);
                            return;
                        end
                    else
                        _Army:SetState(TroopGenerator.States.Attack);
                    end
                end
                if _Army:IsDefenceAllowed() then
                    local GuardPath = self:GetArmyDefencePositions(_PlayerID, _Army:GetID());
                    _Army:CallOnWaypointSelectedBehavior(GuardPath);
                    _Army:SetState(TroopGenerator.States.Guard);
                end
            end
            return;
        end

        -- Gather troops
        if _Army:GetState() == TroopGenerator.States.Gather then
            if _Army:GetTroopCount() == 0 or _Army:DoesRetreat() then
                _Army:CancelState();
                _Army:SetState(TroopGenerator.States.Retreat);
            elseif _Army:IsGathered() then
                _Army:SetState(TroopGenerator.States.Default);
            else
                _Army:Move(_Army:GetPosition());
            end
            if table.getn(EnemiesInSight) > 0 then
                _Army:CallOnEnemiesInSightBehavior(EnemiesInSight);
            end
            return;
        end

        -- Attack enemies
        if _Army:GetState() == TroopGenerator.States.Attack then
            local Enemies = _Army:GetEnemiesInRodeLength(_Army:GetAnchor());
            if _Army:GetTroopCount() == 0 or _Army:DoesRetreat() then
                _Army:CancelState();
                _Army:SetState(TroopGenerator.States.Retreat);
            elseif _Army:IsScattered() then
                _Army:SetState(TroopGenerator.States.Gather);
                _Army:Stop();
            elseif table.getn(Enemies) == 0 then
                _Army:CancelState();
                _Army:SetState(TroopGenerator.States.Default);
            else
                _Army:AttackMove(_Army:GetCurrentWaypoint());
            end
            if table.getn(EnemiesInSight) > 0 then
                _Army:CallOnEnemiesInSightBehavior(EnemiesInSight);
            end
            return;
        end

        -- Defend against attackers
        if _Army:GetState() == TroopGenerator.States.Defend then
            if _Army:GetTroopCount() == 0 or _Army:DoesRetreat() then
                _Army:CancelState();
                _Army:SetState(TroopGenerator.States.Retreat);
            elseif (not IsExisting(_Army:GetTarget()) or Logic.GetEntityHealth(GetID(_Army:GetTarget())) == 0)
            or     QuestTools.GetDistance(_Army:GetTarget(), _Army:GetPosition()) > _Army:GetPersecutionRange() then
                _Army:SetState(TroopGenerator.States.Attack);
                _Army:Stop();
            elseif QuestTools.GetDistance(_Army:GetAnchor(), _Army:GetPosition()) > _Army:GetPersecutionRange() then
                if _Army:GetGuardStartTime() + _Army:GetGuardTime() < Logic.GetTime() then
                    _Army:SetState(TroopGenerator.States.Default);
                else
                    _Army:SetState(TroopGenerator.States.Guard);
                end
                _Army:Stop();
            elseif not _Army:IsMoving() and not _Army:IsFighting() then
                if _Army:GetGuardStartTime() + _Army:GetGuardTime() < Logic.GetTime() then
                    _Army:SetState(TroopGenerator.States.Default);
                else
                    _Army:SetState(TroopGenerator.States.Guard);
                end
            end
            if table.getn(EnemiesInSight) > 0 then
                _Army:CallOnEnemiesInSightBehavior(EnemiesInSight);
            end
            return;
        end

        -- Patrol between positions
        if _Army:GetState() == TroopGenerator.States.Guard then
            if _Army:GetTroopCount() == 0 or _Army:DoesRetreat() then
                _Army:CancelState();
                _Army:SetState(TroopGenerator.States.Retreat);
                _Army:SetGuardStartTime(0);
            elseif not _Army:IsDefenceAllowed() then
                _Army:CancelState();
                _Army:SetState(TroopGenerator.States.Default);
                _Army:SetGuardStartTime(0);
            else
                if _Army:IsAttackAllowed() then
                    if _Army:GetTarget() ~= nil then
                        _Army:SetState(TroopGenerator.States.Attack);
                    else
                        local TargetsAvailable = self:GetAllUnattendedAttackTargets(_PlayerID, _Army:GetID());
                        if table.getn(TargetsAvailable) > 0 then
                            _Army:CancelState();
                            _Army:SetState(TroopGenerator.States.Default);
                            _Army:SetGuardStartTime(0);
                            return;
                        end
                    end
                end
                if _Army:GetCurrentWaypoint() == nil then
                    local DefenceTargets = self:GetArmyDefencePositions(_PlayerID, _Army:GetID());
                    if table.getn(DefenceTargets) == 0 then
                        _Army:SetState(TroopGenerator.States.Default);
                        _Army:SetGuardStartTime(0);
                    else
                        _Army:CallOnWaypointSelectedBehavior(DefenceTargets);
                        _Army:SetGuardStartTime(Logic.GetTime());
                    end
                else
                    if _Army:GetGuardStartTime() + _Army:GetGuardTime() < Logic.GetTime() then
                        _Army:Stop();
                        _Army:NextWaypoint(true);
                        _Army:SetGuardStartTime(Logic.GetTime());
                    else
                        if not _Army:IsMoving() and not _Army:IsFighting() then
                            _Army:AttackMove(_Army:GetAnchor());
                        end
                    end
                end
            end
            if table.getn(EnemiesInSight) > 0 then
                _Army:CallOnEnemiesInSightBehavior(EnemiesInSight);
            end
            return;
        end

        -- Retreat
        if _Army:GetState() == TroopGenerator.States.Retreat then
            if table.getn(_Army:GetMembers()) == 0 then
                _Army:SetLastRespawn(Logic.GetTime());
                _Army:SetState(TroopGenerator.States.Refill);
            elseif QuestTools.GetDistance(_Army:GetPosition(), _Army:GetHomePosition()) <= 2000 then
                _Army:SetLastRespawn(Logic.GetTime());
                _Army:SetState(TroopGenerator.States.Refill);
            else
                _Army:Move(_Army:GetHomePosition());
            end
            if table.getn(EnemiesInSight) > 0 then
                _Army:CallOnEnemiesInSightBehavior(EnemiesInSight);
            end
            return;
        end

        -- Refill
        if _Army:GetState() == TroopGenerator.States.Refill then
            if _Army:DoesRespawn() then
                if _Army:GetTroopCount() == _Army:GetMaxTroopCount() and _Army:HasFullStrength() then
                    _Army:SetState(TroopGenerator.States.Default);
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
                    _Army:SetState(TroopGenerator.States.Default);
                else
                    local UnemployedID = self:GetNextUnemployedLeader(_PlayerID);
                    if UnemployedID ~= 0 then
                        _Army:BindGroup(UnemployedID);
                    else
                        if self:IsNecessaryToHireLeader(_PlayerID) then
                            _Army:CallOnTypeToRecruitSelectedBehavior(_Army:GetTroopCatalog());
                            -- Using BB army in background to recruit troops
                            AI.Army_BuyLeader(_PlayerID, 1, _Army:GetChosenTypeToRecruit());
                            local UnemployedID = self:GetNextUnemployedLeader(_PlayerID);
                            if UnemployedID ~= 0 then
                                local Max = Logic.LeaderGetMaxNumberOfSoldiers(UnemployedID);
                                AI.Entity_SetMaxNumberOfSoldiers(UnemployedID, Max);
                                _Army:BindGroup(UnemployedID);
                            end
                        end
                    end
                    _Army:RefillWeakGroups();
                end
            end
            if table.getn(EnemiesInSight) > 0 then
                _Army:CallOnEnemiesInSightBehavior(EnemiesInSight);
            end
        end
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ~~~                     TroopGenerator.Formation                       ~~~ --
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

TroopGenerator.Formation = {
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

function TroopGenerator.Formation:construct(
    _ID, _PlayerID, _RodeLength, _Strength, _RetreatStrength, _Spawnpoint, 
    _FrontalAttack, _Lifethread, _Independed, _RespawnTime, _TroopCatalog
)
    self.m_ID               = _ID;
    self.m_PlayerID         = _PlayerID;
    self.m_State            = TroopGenerator.States.Default;
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

    self:CreateDefaultBehavior();
end
class(TroopGenerator.Formation);

-- ~~~ State ~~~ --

function TroopGenerator.Formation:CancelState()
    self:SetTarget(nil);
    self:SetPath({});
    self:SetWaypoint(0);
    self:SetGuardStartTime(0);
    self:Stop();
end

function TroopGenerator.Formation:GetID()
    return self.m_ID;
end

function TroopGenerator.Formation:GetPlayerID()
    return self.m_PlayerID;
end

function TroopGenerator.Formation:GetState()
    return self.m_State;
end

function TroopGenerator.Formation:SetState(_State)
    self.m_State = _State;
    return self;
end

function TroopGenerator.Formation:IsDead()
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

function TroopGenerator.Formation:IsFighting()
    for i= 1, table.getn(self.m_Member), 1 do
        if IsExisting(v) then
            if string.find(Logic.GetCurrentTaskList(GetID(self.m_Member[i])), "BATTLE") then
                return true;
            end
        end
    end
    return false;
end

function TroopGenerator.Formation:IsMoving()
    for i= 1, table.getn(self.m_Member), 1 do
        if Logic.IsEntityMoving(self.m_Member[i]) == true then
            return true;
        end
    end
    return false;
end

function TroopGenerator.Formation:GetPosition()
    if table.getn(self.m_Member) > 0 then
        return QuestTools.GetGeometricFocus(unpack(self.m_Member));
    end
    return self.m_HomePosition;
end

function TroopGenerator.Formation:GetHomePosition()
    return self.m_HomePosition;
end

function TroopGenerator.Formation:SetHomePosition(_Home)
    self.m_HomePosition = _Home;
    return self;
end

function TroopGenerator.Formation:GetLifethread()
    return self.m_Lifethread;
end

function TroopGenerator.Formation:SetLifethread(_Lifethread)
    self.m_Lifethread = _Lifethread;
    return self;
end

function TroopGenerator.Formation:ClearDead()
    for i= table.getn(self.m_Member), 1, -1 do
        if not IsExisting(self.m_Member[i]) or Logic.GetEntityHealth(GetID(self.m_Member[i])) == 0 then
            table.remove(self.m_Member, i);
        end
    end
end

-- ~~~ Find enemies ~~~ --

function TroopGenerator.Formation:GetEnemiesInArea(_Position, _Area)
    return TroopGenerator.AI:GetEnemiesInArea(self.m_PlayerID, _Position, _Area);
end

function TroopGenerator.Formation:GetEnemiesInRodeLength(_Position)
    return self:GetEnemiesInArea(_Position, self:GetRodeLength());
end

-- ~~~ Movement ~~~ --

function TroopGenerator.Formation:Stop()
    for k, v in pairs(self.m_Member) do
        GUI.SettlerStand(GetID(v));
    end
end

function TroopGenerator.Formation:AttackMove(_Position)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    for k, v in pairs(self.m_Member) do
        if IsExisting(v) then
            if Logic.IsEntityMoving(GetID(v)) == false and not string.find(Logic.GetCurrentTaskList(GetID(v)), "BATTLE") then
                Logic.GroupAttackMove(GetID(v), _Position.X, _Position.Y);
            end
        end
    end
end

function TroopGenerator.Formation:Attack(_Target)
    for k, v in pairs(self.m_Member) do
        if IsExisting(v) then
            Logic.GroupAttack(GetID(v), _Target);
        end
    end
end

function TroopGenerator.Formation:Move(_Position)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    for k, v in pairs(self.m_Member) do
        if IsExisting(v) then
            if Logic.IsEntityMoving(GetID(v)) == false then
                Logic.MoveSettler(GetID(v), _Position.X, _Position.Y);
            end
        end
    end
end

-- ~~~ Control ~~~ --

function TroopGenerator.Formation:IsAttackAllowed()
    return self.m_AttackAllowed == true;
end

function TroopGenerator.Formation:SetAttackAllowed(_Flag)
    self.m_AttackAllowed = _Flag == true;
    return self;
end

function TroopGenerator.Formation:IsDefenceAllowed()
    return self.m_DefenceAllowed == true;
end

function TroopGenerator.Formation:SetDefenceAllowed(_Flag)
    self.m_DefenceAllowed = _Flag == true;
    return self;
end

function TroopGenerator.Formation:DoesFrontalAttack()
    return self.m_FrontalAttack == true;
end

function TroopGenerator.Formation:GetTarget()
    return self.m_AttackTarget;
end

function TroopGenerator.Formation:SetTarget(_AttackTarget)
    self.m_AttackTarget = _AttackTarget;
    return self;
end

function TroopGenerator.Formation:GetGuardStartTime()
    return self.m_GuardStartTime;
end

function TroopGenerator.Formation:SetGuardStartTime(_Time)
    self.m_GuardStartTime = _Time;
    return self;
end

function TroopGenerator.Formation:GetGuardTime()
    return self.m_GuardTime;
end

function TroopGenerator.Formation:SetGuardTime(_Time)
    self.m_GuardTime = _Time;
    return self;
end

function TroopGenerator.Formation:GetPath()
    return self.m_Path;
end

function TroopGenerator.Formation:SetPath(_Path)
    self.m_Path = _Path;
    return self;
end

function TroopGenerator.Formation:GetAnchor()
    if self:GetCurrentWaypoint() then
        return self:GetCurrentWaypoint();
    else
        return self.m_HomePosition;
    end
end

function TroopGenerator.Formation:GetCurrentWaypoint()
    return self.m_Path[self.m_Waypoint];
end

function TroopGenerator.Formation:GetWaypoint()
    return self.m_Waypoint;
end

function TroopGenerator.Formation:SetWaypoint(_Waypoint)
    self.m_Waypoint = _Waypoint;
    if self.m_Waypoint > table.getn(self.m_Path) then
        self.m_Waypoint = table.getn(self.m_Path);
    end
    return self;
end

function TroopGenerator.Formation:NextWaypoint(_Loop)
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

function TroopGenerator.Formation:GetRodeLength()
    return self.m_RodeLength;
end

function TroopGenerator.Formation:SetRodeLength(_Area)
    self.m_RodeLength = _Area;
    return self;
end

function TroopGenerator.Formation:GetPersecutionRange()
    return self.m_PersecutionArea;
end

function TroopGenerator.Formation:SetPersecutionRange(_Area)
    self.m_PersecutionArea = _Area;
    return self;
end

-- ~~~ Strength ~~~ --

function TroopGenerator.Formation:GetStrength()
    return self.m_Strength;
end

function TroopGenerator.Formation:SetStrength(_Strength)
    self.m_Strength = _Strength;
    return self;
end

function TroopGenerator.Formation:CalculateStrength()
    local CurrentStrength = 0;
    for i= 1, table.getn(self.m_Member), 1 do
        local ID = GetID(self.m_Member[i]);
        CurrentStrength = CurrentStrength +1;
        if Logic.IsLeader(ID) == 1 then
            CurrentStrength = CurrentStrength + Logic.LeaderGetNumberOfSoldiers(ID);
        end
    end
    return CurrentStrength;
end

function TroopGenerator.Formation:DoesRetreat()
    if self.m_Strength > 0 then
        return self:CalculateStrength() / self:GetStrength() <= self:GetRetreatStrength();
    end
    return false;
end

function TroopGenerator.Formation:GetRetreatStrength()
    return self.m_RetreatStrength;
end

function TroopGenerator.Formation:SetRetreatStrength(_Strength)
    self.m_RetreatStrength = _Strength;
    return self;
end

function TroopGenerator.Formation:GetMaxTroopCount()
    return self.m_TroopCount;
end

function TroopGenerator.Formation:SetMaxTroopCount(_Strength)
    self.m_TroopCount = _Strength;
    return self;
end

function TroopGenerator.Formation:HasFullStrength()
    local MemberCount = table.getn(self.m_Member);
    if self.m_TroopCount > MemberCount then
        return false;
    end
    for i= 1, MemberCount, 1 do
        local CurrentSoldiers = Logic.LeaderGetNumberOfSoldiers(GetID(self.m_Member[i]));
        local MaximumSoldiers = Logic.LeaderGetMaxNumberOfSoldiers(GetID(self.m_Member[i]));
        if MaximumSoldiers > CurrentSoldiers then
            return false;
        end
    end
    return true;
end

function TroopGenerator.Formation:GetTroopCount()
    return table.getn(self.m_Member);
end

function TroopGenerator.Formation:GetMembers()
    return self.m_Member;
end

-- ~~~ Gathering ~~~ --

function TroopGenerator.Formation:IsScattered()
    if not self:IsFighting() and not self:DoesFrontalAttack() then
        local ArmyPosition = self:GetPosition();
        local ArmySize = table.getn(self.m_Member);
        for i= 1, ArmySize, 1 do
            if QuestTools.GetDistance(ArmyPosition, self.m_Member[i]) > self.m_ScatterArea + 300 * (ArmySize/10) then
                return true;
            end
        end
    end
    return false;
end

function TroopGenerator.Formation:IsGathered()
    local ArmyPosition = self:GetPosition();
    local ArmySize = table.getn(self.m_Member);
    for i= 1, ArmySize, 1 do
        if QuestTools.GetDistance(ArmyPosition, self.m_Member[i]) > self.m_GatherArea + 300 * (ArmySize/10) then
            return false;
        end
    end
    return true;
end

-- ~~~ Soldiers ~~~ --

function TroopGenerator.Formation:KillGroup(_Group)
    if IsExisting(_Group) then
        if Logic.IsLeader(_Group) == 1 then
            local Soldiers = {Logic.GetSoldiersAttachedToLeader(_Group)};
            for i=2, Soldiers[1] +1, 1 do
                Logic.HurtEntity(Soldiers[i], Logic.GetEntityHealth(Soldiers[i]));
            end
        end
        Logic.HurtEntity(_Group, Logic.GetEntityHealth(_Group));
    end
end

function TroopGenerator.Formation:KillAllGroups()
    for i= table.getn(self.m_Member), 1, -1 do
        self:KillGroup(self.m_Member[i]);
    end
end

function TroopGenerator.Formation:BindGroup(_Group)
    local Name = QuestTools.CreateNameForEntity(_Group);
    if self:GetTroopCount() < self:GetMaxTroopCount() then
        if not TroopGenerator.AI:IsEntityHidenFromAI(self.m_PlayerID, Name) then
            if TroopGenerator.AI:GetArmyEntityIsEmployedIn(Name) == 0 then
                table.insert(self.m_Member, _Group);
                return true;
            end
        end
    end
    return false;
end

function TroopGenerator.Formation:UnbindGroup(_Group)
    for i= table.getn(self.m_Member), 1, -1 do
        if self.m_Member[i] == _Group then
            table.remove(self.m_Member, i);
        end
    end
end

function TroopGenerator.Formation:UnbindAllGroups()
    for i= table.getn(self.m_Member), 1, -1 do
        self:UnbindGroup(self.m_Member[i]);
    end
end

-- Behaviors --

function TroopGenerator.Formation:CreateDefaultBehavior()
    -- If a member is attacked then the whole army attacks the attacker.
    self.m_OnMemberAttacked = function(_Data, _Attacker, _Defender)
        if  _Data:GetState() ~= TroopGenerator.States.Attack 
        and _Data:GetState() ~= TroopGenerator.States.Defend
        and _Data:GetState() ~= TroopGenerator.States.Retreat then
            _Data:SetState(TroopGenerator.States.Defend);
            _Data:Attack(_Attacker);
        end
    end

    -- If heroes (expect Ari with active camouflage) are in sight of the army
    -- the army aborts their current attack and directly attack the hero.
    self.m_OnEnemiesInSight = function(_Data, _EnemyList)
        for i= 1, table.getn(_EnemyList), 1 do
            local ID = GetID(_EnemyList[i]);
            if  Logic.IsHero(ID) == 1 and Logic.GetEntityHealth(ID) > 0 
            and Logic.GetCamouflageTimeLeft(ID) == 0 then
                _Data:SetState(TroopGenerator.States.Attack);
                _Data:SetTarget(ID);
                _Data:Attack(ID);
            end
        end
    end

    -- When a unit type is selected for recruiting a random type is chosen.
    -- (Note: List contains upgrade categories for soldiers and entity types
    -- for cannons!)
    self.m_OnTypeToRecruitSelected = function(_Data, _Catalog)
        if table.getn(_Catalog) == 0 then
            return;
        end
        _Data:SetTroopIterator(math.random(1, table.getn(_Catalog)));
    end

    -- When a unit type is selected for spawning the list is iterated and the
    -- type at the index is returned. Iterator is reset to first element after
    -- end of list is reached.
    self.m_OnTypeToSpawnSelected = function(_Data, _Catalog)
        if table.getn(_Catalog) == 0 then
            return;
        end
        _Data:SetTroopIterator(_Data:GetTroopIterator() +1);
        if _Data:GetTroopIterator() > table.getn(_Catalog) then
            _Data:SetTroopIterator(1);
        end
    end

    -- When a target is selected the clostest is chosen.
    self.m_OnAttackTargetSelected = function(_Data, _TargetList)
        local sort = function(a, b)
            return QuestTools.GetDistance(a, _Data:GetHomePosition()) < QuestTools.GetDistance(b, _Data:GetHomePosition());
        end
        table.sort(_TargetList, sort);
        _Data:SetPath({_TargetList[1]});
        _Data:SetWaypoint(1);
        _Data:SetTarget(_Data:GetCurrentWaypoint());
    end

    -- If a waypoint for patrols is selected, a random pint is chosen.
    self.m_OnWaypointSelected = function(_Data, _Waypoints)
        if table.getn(_Waypoints) == 0 then
            _Waypoints = {_Data:GetHomePosition()};
        end
        _Data:SetPath(_Waypoints);
        _Data:SetWaypoint(math.random(1, table.getn(_Waypoints)));
    end

    -- Sets the formation of the army members. Swordmen and spearmen go into
    -- block formation and all other into line formation. Evil leader keep
    -- the original formation.
    self.m_OnFormationChosen = function(_Data, _Group)
        if Logic.IsEntityInCategory(_Group, EntityCategories.EvilLeader) == 1 then
            return;
        elseif Logic.IsEntityInCategory(_Group, EntityCategories.Spear) == 1
        or     Logic.IsEntityInCategory(_Group, EntityCategories.Sword) == 1 then
            Logic.LeaderChangeFormationType(_Group, 2);
            return;
        elseif Logic.IsEntityInCategory(_Group, EntityCategories.CavalryHeavy) == 1 then
            Logic.LeaderChangeFormationType(_Group, 6);
            return;
        end
        Logic.LeaderChangeFormationType(_Group, 2);
    end
end

function TroopGenerator.Formation:CallOnMeberAttackedBehavior(_Attacker, _Defender)
    self.m_OnMemberAttacked(self, _Attacker, _Defender);
end

function TroopGenerator.Formation:SetOnMeberAttackedBehavior(_Behavior)
    self.m_OnMemberAttacked = _Behavior;
    return self;
end

function TroopGenerator.Formation:CallOnEnemiesInSightBehavior(_EnemyList)
    self.m_OnEnemiesInSight(self, _EnemyList);
end

function TroopGenerator.Formation:SetOnEnemiesInSightBehavior(_Behavior)
    self.m_OnEnemiesInSight = _Behavior;
    return self;
end

function TroopGenerator.Formation:CallOnTypeToSpawnSelectedBehavior(_List)
    return self.m_OnTypeToSpawnSelected(self, _List);
end

function TroopGenerator.Formation:SetOnTypeToSpawnSelectedBehavior(_Behavior)
    self.m_OnTypeToSpawnSelected = _Behavior;
    return self;
end

function TroopGenerator.Formation:CallOnTypeToRecruitSelectedBehavior(_List)
    return self.m_OnTypeToRecruitSelected(self, _List);
end

function TroopGenerator.Formation:SetOnTypeToRecruitSelectedBehavior(_Behavior)
    self.m_OnTypeToRecruitSelected = _Behavior;
    return self;
end

function TroopGenerator.Formation:CallOnFormationChosenBehavior(_Group)
    return self.m_OnFormationChosen(self, _Group);
end

function TroopGenerator.Formation:SetOnFormationChosenBehavior(_Behavior)
    self.m_OnFormationChosen = _Behavior;
    return self;
end

function TroopGenerator.Formation:CallOnAttackTargetSelectedBehavior(_List)
    return self.m_OnAttackTargetSelected(self, _List);
end

function TroopGenerator.Formation:SetOnAttackTargetSelectedBehavior(_Behavior)
    self.m_OnAttackTargetSelected = _Behavior;
    return self;
end

function TroopGenerator.Formation:CallOnWaypointSelectedBehavior(_List)
    return self.m_OnWaypointSelected(self, _List);
end

function TroopGenerator.Formation:SetOnWaypointSelectedBehavior(_Behavior)
    self.m_OnWaypointSelected = _Behavior;
    return self;
end

-- Respawning and recruiting --

function TroopGenerator.Formation:GetTroopCatalog()
    return self.m_TroopCatalog;
end

function TroopGenerator.Formation:SetTroopCatalog(_List)
    self.m_TroopCatalog = _List;
    return self;
end

function TroopGenerator.Formation:GetTroopIterator()
    return self.m_TroopInterator;
end

function TroopGenerator.Formation:SetTroopIterator(_Value)
    self.m_TroopInterator = _Value;
    return self;
end

function TroopGenerator.Formation:GetLastRespawn(_Time)
    return self.m_LastRespawn;
end

function TroopGenerator.Formation:SetLastRespawn(_Time)
    self.m_LastRespawn = _Time;
    return self;
end

function TroopGenerator.Formation:IsInitialSpawn()
    return self.m_InitialSpawn == false;
end

function TroopGenerator.Formation:SetHasInitialSpawned()
    self.m_InitialSpawn = true;
    return self;
end

function TroopGenerator.Formation:GetRespawnTime()
    return self.m_RespawnTime;
end

function TroopGenerator.Formation:DoesRespawn()
    return self.m_DoesRespawn == true;
end

function TroopGenerator.Formation:IsIndependedFromLifethread()
    return self.m_Independed == true;
end

function TroopGenerator.Formation:GetChosenTypeToRecruit()
    local CatalogSize = table.getn(self.m_TroopCatalog);
    if CatalogSize == 0 then
        return;
    end
    return self.m_TroopCatalog[self:GetTroopIterator()];
end

function TroopGenerator.Formation:SpawnTroop()
    if self:GetTroopCount() >= self:GetMaxTroopCount() then
        return false;
    end
    local CatalogSize = table.getn(self.m_TroopCatalog);
    if CatalogSize == 0 then
        return false;
    end
    self:CallOnTypeToSpawnSelectedBehavior(self:GetTroopCatalog());
    local TroopID = self:CreateGroup(
        self.m_PlayerID,
        self.m_TroopCatalog[self.m_TroopInterator][1],
        16,
        GetPosition(self.m_HomePosition),
        self.m_TroopCatalog[self.m_TroopInterator][2] or 3
    );
    local ScriptName = QuestTools.CreateNameForEntity(TroopID);
    table.insert(self.m_Member, ScriptName);
    self:SetStrength(self:CalculateStrength());
    return true;
end

function TroopGenerator.Formation:RefillWeakGroups()
    for i= table.getn(self.m_Member), 1, -1 do
        if IsExisting(self.m_Member[i]) then
            local ID = GetID(self.m_Member[i]);
            if self:CanGroupBeRefilled(ID) then
                if IsNear(ID, self.m_HomePosition, 2000) then
                    self:RefillSingleGroup(ID);
                else
                    local Position = QuestTools.GetReachablePosition(ID, self.m_HomePosition);
                    if Position then
                        Logic.MoveSettler(ID, Position.X, Position.Y);
                    else
                        self:KillGroup(ID);
                    end
                end
            end
        end
    end
end

function TroopGenerator.Formation:CanGroupBeRefilled(_Group)
    if Logic.IsLeader(_Group) == 0 or Logic.LeaderGetMaxNumberOfSoldiers(_Group) == 0 then
        return false;
    end
    local BarrackID = Logic.LeaderGetBarrack(_Group);
    if IsExisting(BarrackID) then
        return false;
    end
    if Logic.LeaderGetNumberOfSoldiers(_Group) == Logic.LeaderGetMaxNumberOfSoldiers(_Group) then
        return false;
    end
    if Logic.GetSector(_Group) == 0 then
        return false;
    end
    local Task = Logic.GetCurrentTaskList(_Group);
    if Task and (string.find(Task, "TRAIN") or string.find(Task, "BATTLE") or string.find(Task, "DIE")) then
        return false;
    end
    return true;
end

function TroopGenerator.Formation:RefillSingleGroup(_Group)
    if not self:CanGroupBeRefilled(_Group) then
        return;
    end
    Tools.CreateSoldiersForLeader(_Group, 1);
end

function TroopGenerator.Formation:CreateGroup(_PlayerID, _LeaderType, _MaxSoldiers, _Position, _Experience)
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

