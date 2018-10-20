-- ########################################################################## --
-- #  Behavior templates                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This is an abstraction layer of the quest system, allowing the user to
-- create quests much more simple. Also some behavior are recoded and there
-- is a better AI control script for armies than the default controller.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.questsystem</li>
-- <li>qsb.interaction</li>
-- <li>qsb.information</li>
-- </ul>
--
-- @set sort=true
--

-- Quests and tools --

---
-- Creates an quest from the given description.
--
-- Description contains of the following entries:
-- <ul>
-- <li><b>Name:</b> Name of quest</li>
-- <li><b>Receiver:</b> Player that receives the quest</li>
-- <li><b>Time:</b> Time, until the quest is automatically over</li>
-- <li><b>Description:</b> Quest information displayed in the quest book</li>
-- </ul>
-- After the fields the behavior constructors are called.
--
-- @param _Data [table] Quest description
-- @return [number] Quest id
-- @return [table] Quest instance
--
-- @usage CreateQuest {
--     Name = "SomeQuestName",
--     Description = {
--         Title = "Name of quest",
--         Text  = "Description of quest",
--         Type  = MAINQUEST_OPEN,
--         Info  = 1
--     },
--
--     Goal_DestroyAllPlayerUnits(2),
--     Reward_Victory(),
--     Trigger_Time(0)
-- }
--
function CreateQuest(_Data)
    local QuestName   = _Data.Name;
    local Receiver    = _Data.Receiver;
    local Time        = _Data.Time;
    local Description = _Data.Description;

    local QuestObjectives = {};
    local QuestConditions = {};
    local QuestRewards = {};
    local QuestReprisals = {};

    for i= 1, table.getn(_Data), 1 do
        if _Data[i].GetGoalTable then
            table.insert(QuestObjectives, copy(_Data[i]:GetGoalTable()));
        elseif _Data[i].GetTriggerTable then
            table.insert(QuestConditions, copy(_Data[i]:GetTriggerTable()));
        elseif _Data[i].GetRewardTable then
            table.insert(QuestRewards, copy(_Data[i]:GetRewardTable()));
        elseif _Data[i].GetReprisalTable then
            table.insert(QuestReprisals, copy(_Data[i]:GetReprisalTable()));
        end
    end

    return new(QuestTemplate, QuestName, Receiver, Time, QuestObjectives, QuestConditions, QuestRewards, QuestReprisals, Description);
end

---
-- Creates an AI player and sets the technology level.
--
-- Use this function or the behavior to initalize the AI. An AI must first be
-- initalized before an army can be created.
--
-- @param _PlayerID [number] PlayerID
-- @param _TechLevel [number] Technology level [1|4]
--
-- @usage CreateAIPlayer(2, 4);
--
function CreateAIPlayer(_PlayerID, _TechLevel)
    QuestSystemBehavior:CreateAI(_PlayerID, _TechLevel);
end

---
-- Disables or enables the ability to attack for the army. This function can
-- be used to forbid an army to attack even if there are valid targets.
--
-- @param _PlayerID [number] ID of player
-- @param _ArmyID [number] ID of army
-- @param _Flag [boolean] Ability to attack
-- 
-- @usage ArmyDisableAttackAbility(2, 1, true)
--
function ArmyDisableAttackAbility(_PlayerID, _ArmyID, _Flag)
    QuestSystemBehavior:ArmyDisableAttackAbility(_PlayerID, _ArmyID, _Flag);
end

---
-- Disables or enables the ability to patrol between positions. This
-- function can be used to forbid an army to attack even if there are
-- valid targets.
--
-- @param _PlayerID [number] ID of player
-- @param _ArmyID [number] ID of army
-- @param _Flag [boolean] Ability to attack
-- 
-- @usage ArmyDisablePatrolAbility(2, 1, true)
--
function ArmyDisablePatrolAbility(_PlayerID, _ArmyID, _Flag)
    QuestSystemBehavior:ArmyDisablePatrolAbility(_PlayerID, _ArmyID, _Flag);
end

---
-- Initalizes an army that is recruited by the AI player.
-- Armies can also be created with the behavior interface. This is a simple
-- type of army that can be configured by placing and naming script entities.
-- The army name must be unique for the player!
--
-- The AI player must be initalized first!
--
-- For the troop types either define a table of upgrade categories or use the
-- constants from the QuestSystemBehavior.ArmyCategories table.
--
-- Use script entities named with PlayerX_AttackTargetY to define positions
-- that will be attacked by the army. Replace X with the player ID and Y with
-- a unique number starting by 1.
--
-- Also you can use entities named with PlayerX_PatrolPointY to define
-- positions were the army will patrol. Also replace X with the player ID and
-- Y with a unique number starting by 1.
--
-- @param _ArmyName [String] Army identifier
-- @param _PlayerID [number] Owner of army
-- @param _Strength [number] Strength of army [1|8]
-- @param _Position [string] Home Position of army
-- @param _RodeLength [number] Action range of the army
-- @param _TroopTypes [table] Upgrade categories to recruit
-- @return [number] Army ID
--
-- @usage CreateAIPlayer("Foo", 2, 8, "armyPos1", 5000, QuestSystemBehavior.ArmyCategories.City);
--
function CreateAIPlayerArmy(_ArmyName, _PlayerID, _Strength, _Position, _RodeLength, _TroopTypes)
    if QuestSystemBehavior.Data.AiArmyNameToId[_ArmyName] then
        return;
    end
    local ID = QuestSystemBehavior:CreateAIArmy(_PlayerID, _Strength, _Position, _RodeLength, _TroopTypes);
    if ID then
        QuestSystemBehavior.Data.AiArmyNameToId[_ArmyName] = ID;
    end
    return ID;
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
-- @param _ArmyName [String] Army identifier
-- @param _PlayerID [number] Owner of army.
-- @param _Strength [number] Strength of army [1|8]
-- @param _Position [string] Home Position of army
-- @param _LifeThread [string] Name of generator
-- @param _RodeLength [number] Action range of the army
-- @param _RespawnTime [number] Time till troops are refreshed
-- @param ... [number] List of types to spawn
--
-- @usage CreateAIPlayerSpawnArmy(
--     "Bar", 2, 8, "armyPos1", "lifethread", 5000,
--     Entities.PU_LeaderSword2,
--     Entities.PU_LeaderBow2,
--     Entities.PV_Cannon2
-- );
--
function CreateAIPlayerSpawnArmy(_ArmyName, _PlayerID, _Strength, _Position, _LifeThread, _RodeLength, _RespawnTime, ...)
    if QuestSystemBehavior.Data.AiArmyNameToId[_ArmyName] then
        return;
    end
    local EntityTypes = {unpack(arg)};
    assert(table.getn(EntityTypes) > 0);
    local ID = QuestSystemBehavior:CreateAISpawnArmy(_PlayerID, _Strength, _Position, _LifeThread, _RodeLength, EntityTypes, _RespawnTime);
    if ID then
        QuestSystemBehavior.Data.AiArmyNameToId[_ArmyName] = ID;
    end
    return ID;
end

-- Helper --

-- Has no use while mapping, so it's not documented.
function dbg(_Quest, _Behavior, _Message)
    GUI.AddStaticNote(string.format("DEBUG: %s:%s: %s", _Quest.m_QuestName, _Behavior.Data.Name, tostring(_Message)));
end

---
-- Finds all entities numbered from 1 to n with a common prefix.
-- @param _Prefix [string] Prefix of scriptnames
-- @return [table] List of entities
--
function GetEntitiesByPrefix(_Prefix)
    local list = {};
    local i = 1;
    local bFound = true;
    while (bFound) do
        local entity = GetID(_Prefix ..i);
        if entity ~= 0 then
            table.insert(list, entity);
        else
            bFound = false;
        end
        i = i + 1;
    end
    return list;
end

---
-- Finds all entities of the player that have the type.
-- @param _PlayerID [number] ID of player
-- @param _EntityType [number] Type to search
-- @return [table] List of entities
--
function GetPlayerEntities(_PlayerID, _EntityType)
    local PlayerEntities = {}
    if _EntityType ~= 0 then
        local n,eID = Logic.GetPlayerEntities(_PlayerID, _EntityType, 1);
        if (n > 0) then
            local firstEntity = eID;
            repeat
                table.insert(PlayerEntities,eID)
                eID = Logic.GetNextEntityOfPlayerOfType(eID);
            until (firstEntity == eID);
        end
    elseif _EntityType == 0 then
        for k,v in pairs(Entities) do
            if string.find(k, "PU_") or string.find(k, "PB_") or string.find(k, "CU_") or string.find(k, "CB_")
            or string.find(k, "XD_DarkWall") or string.find(k, "XD_Wall") or string.find(k, "PV_") then
                local n,eID = Logic.GetPlayerEntities(_PlayerID, v, 1);
                if (n > 0) then
                local firstEntity = eID;
                repeat
                    table.insert(PlayerEntities,eID)
                    eID = Logic.GetNextEntityOfPlayerOfType(eID);
                until (firstEntity == eID);
                end
            end
        end
    end
    return PlayerEntities
end

-- Behavior --

QuestSystemBehavior = {
    Data = {
        RegisteredQuestBehaviors = {},
        SystemInitalized = false;
        Version = "1.0.0",

        SaveLoadedActions = {},
        PlayerColorAssigment = {},
        CreatedAiPlayers = {},
        CreatedAiArmies = {},
        AiArmyNameToId = {},
        CustomVariables = {},
    }
}

---
-- Installs the questsystem. This function is a substitude for the original
-- method QuestSystem:InstallQuestSystem and will call the original first.
-- After that the behavior are initalized.
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:PrepareQuestSystem()
    if not self.Data.SystemInitalized then
        self.Data.SystemInitalized = true;

        QuestSystem:InstallQuestSystem();
        Interaction:Install();
        Information:Install();
        self:CreateBehaviorConstructors();

        Mission_OnSaveGameLoaded_Orig_QuestSystemBehavior = Mission_OnSaveGameLoaded;
        Mission_OnSaveGameLoaded = function()
            Mission_OnSaveGameLoaded_Orig_QuestSystemBehavior();
            QuestSystemBehavior:CallSaveLoadActions();
        end

        -- Restore player colors
        self:AddSaveLoadActions(QuestSystemBehavior.UpdatePlayerColorAssigment);
    end
end

---
-- Calls all loaded actions after a save is loaded.
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:CallSaveLoadActions()
    for k, v in pairs(self.Data.SaveLoadedActions) do
        v[1](v);
    end
end

---
-- Adds an action that is performed after a save is loaded.
-- @param _Function [function] Action
-- @param ... [mixed] Data
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:AddSaveLoadActions(_Function, ...)
    table.insert(self.Data.SaveLoadedActions, {_Function, unpack(copy(arg))});
end

---
-- Registers a behavior.
-- @param _Behavior [table] Behavior pseudo class
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:RegisterBehavior(_Behavior)
    table.insert(QuestSystemBehavior.Data.RegisteredQuestBehaviors, _Behavior.Data.Name);
end

---
-- Generates the behavior constructor methods for all registered behavior.
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:CreateBehaviorConstructors()
    for i= 1, table.getn(QuestSystemBehavior.Data.RegisteredQuestBehaviors), 1 do
        if _G["b_" ..QuestSystemBehavior.Data.RegisteredQuestBehaviors[i]] then
            _G["b_" ..QuestSystemBehavior.Data.RegisteredQuestBehaviors[i]].New = function(self, ...)
                local Behavior = copy(_G["b_" ..self.Data.Name]);
                for i= 1, table.getn(arg), 1 do
                    Behavior:AddParameter(i, arg[i]);
                end
                return Behavior;
            end
        else
            GUI.AddStaticNote("b_" ..QuestSystemBehavior.Data.RegisteredQuestBehaviors[i].. " does not exist!");
        end
    end
end

---
-- Creates a AI player and upgrades the troops according to the technology
-- level.
-- @param _PlayerID [number] ID of player
-- @param _TechLevel [number] Technology level
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:CreateAI(_PlayerID, _TechLevel)
    if self.Data.CreatedAiPlayers[_PlayerID] then
        return;
    end

    -- Create Player
    local description 	= {
        serfLimit	  	= 12,
        resourceFocus 	= nil,
        rebuild		  	= {delay = 0},
        extracting	  	= false,
        repairing	  	= true,
        constructing  	= true,
        resources	  	= {gold = 30000, clay = 3000, wood = 9000, stone = 3000, iron = 9000, sulfur = 9000},
        refresh   	  	= {gold = 800,   clay =   40, wood =   40, stone =   40, iron =  400, sulfur =  400, updateTime	= 15},
    }
    SetupPlayerAi(_PlayerID, description);

    -- Upgrade troops
    local CannonEntityType = Entities["PV_Cannon".._TechLevel];
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

    -- Save Player data
    self.Data.CreatedAiPlayers[_PlayerID] = {
        TechnologyLevel = _TechLevel,
        CannonType = Entities["PV_Cannon".._TechLevel],
    };
end

---
-- Upgrades an existing AI player with a higher technology level.
-- @param _PlayerID [number] ID of player
-- @param _NewTechLevel [number] Technology level
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:UpgradeAI(_PlayerID, _NewTechLevel)
    if self.Data.CreatedAiPlayers[_PlayerID] then
        local OldLevel = self.Data.CreatedAiPlayers[_PlayerID].TechnologyLevel;
        if _NewTechLevel > 0 and _NewTechLevel < 5 and OldLevel < _NewTechLevel then
            -- Upgrade troops
            local CannonEntityType = Entities["PV_Cannon".._NewTechLevel];
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

            -- Save Player data
            self.Data.CreatedAiPlayers[_PlayerID] = {
                TechnologyLevel = _NewTechLevel,
                CannonType = Entities["PV_Cannon".._NewTechLevel],
            };
        end
    end
end

---
-- Table of army categories
-- @field City City troop types
-- @field BlackKnight Black knight troop types
-- @field Bandit Bandit troop types
-- @field Barbarian Barbarian troop types
-- @field Nephilim Nephilim troop types
-- @within Constants
--
QuestSystemBehavior.ArmyCategories = {
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
    Nephilim = {
        UpgradeCategories.Evil_LeaderBearman,
        UpgradeCategories.Evil_LeaderSkirmisher
    },
};

---
-- Disables or enables the ability to attack for the army. This function can
-- be used to forbid an army to attack even if there are valid targets.
-- @param _PlayerID [number] ID of player
-- @param _ArmyID [number] ID of army
-- @param _Flag [boolean] Ability to attack
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:ArmyDisableAttackAbility(_PlayerID, _ArmyID, _Flag)
    if QuestSystemBehavior.Data.CreatedAiArmies[_PlayerID] then
        local army = QuestSystemBehavior.Data.CreatedAiArmies[_PlayerID][_ArmyID];
        if army and army.Advanced then
            army.Advanced.AttackDisabled = _Flag == true;
            army.Advanced.AnchorChanged = false;
        end
    end
end

---
-- Disables or enables the ability to patrol between positions. This
-- function can be used to forbid an army to attack even if there are
-- valid targets.
-- @param _PlayerID [number] ID of player
-- @param _ArmyID [number] ID of army
-- @param _Flag [boolean] Ability to attack
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:ArmyDisablePatrolAbility(_PlayerID, _ArmyID, _Flag)
    if QuestSystemBehavior.Data.CreatedAiArmies[_PlayerID] then
        local army = QuestSystemBehavior.Data.CreatedAiArmies[_PlayerID][_ArmyID];
        if army and army.Advanced then
            army.Advanced.PatrolDisabled = _Flag == true;
            army.Advanced.AnchorChanged = false;
        end
    end
end

---
-- Creates an army for the AI that is recruited from the barracks of the player.
-- The cannon type is automatically set by the technology level of the AI.
-- @param _PlayerID [number] ID of player
-- @param _Strength [number] Strength of army
-- @param _Position [string] Home area center
-- @param _RodeLength [number] Rode length
-- @param _TroopTypes [table] Allowed troops
-- @return [number] Army ID
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:CreateAIArmy(_PlayerID, _Strength, _Position, _RodeLength, _TroopTypes)
    self.Data.CreatedAiArmies[_PlayerID] = self.Data.CreatedAiArmies[_PlayerID] or {};
    _Strength = (_Strength < 0 and 1) or (_Strength > 8 and 8) or _Strength;

    -- Check created AI
    if not self.Data.CreatedAiPlayers[_PlayerID] then
        return;
    end

    -- Get army ID
    local ArmyID = table.getn(self.Data.CreatedAiArmies[_PlayerID]) +1;
    if ArmyID > 10 then
        return;
    end

    -- Get attack positions
    local AttackPositions = GetEntitiesByPrefix("Player" .._PlayerID.. "_AttackTarget");
    for i= 1, table.getn(AttackPositions), 1 do
        AttackPositions[i] = Logic.GetEntityName(AttackPositions[i]);
    end
    if table.getn(AttackPositions) == 0 then
        AttackPositions = nil;
    end

    -- Get patrol points
    local PatrolPoints = GetEntitiesByPrefix("Player" .._PlayerID.. "_PatrolPoint");
    for i= 1, table.getn(PatrolPoints), 1 do
        PatrolPoints[i] = Logic.GetEntityName(PatrolPoints[i]);
    end
    if table.getn(PatrolPoints) == 0 then
        PatrolPoints = {_Position};
    end

    -- Set allowed types
    if not _TroopTypes then
        _TroopTypes = copy(QuestSystemBehavior.ArmyCategories.City);
    end
    assert(type(_TroopTypes) == "table", "CreateAIArmy: _TroopTypes must be a table!");
    table.insert(_TroopTypes, self.Data.CreatedAiPlayers[_PlayerID].CannonType);

    -- Create army
    local army 				     = {};
    army.player 			     = _PlayerID;
    army.id					     = ArmyID;
    army.strength			     = _Strength;
    army.position			     = GetPosition(_Position);
    army.rodeLength			     = _RodeLength;
    army.retreatStrength	     = math.ceil(_Strength/3);
    army.baseDefenseRange	     = _RodeLength * 0.7;
    army.outerDefenseRange	     = _RodeLength * 1.5;
    army.AllowedTypes		     = _TroopTypes;

    army.Advanced                = {};
    army.Advanced.attackPosition = AttackPositions;
    army.Advanced.patrolPoints   = PatrolPoints;

    table.insert(self.Data.CreatedAiArmies[_PlayerID], army);
    SetupAITroopGenerator("QuestSystemBehavior_AiArmies_" .._PlayerID.. "_" ..ArmyID, self.Data.CreatedAiArmies[_PlayerID][ArmyID]);
    Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", "QuestSystemBehavior_AiArmiesController", 1, 0, {_PlayerID, ArmyID});

    -- Default values
    AI.Army_BeAlwaysAggressive(_PlayerID, ArmyID);
    AI.Army_SetScatterTolerance(_PlayerID, ArmyID, 4);

    return ArmyID;
end

---
-- Creates an army for the AI that is spawned from a life thread building.
-- @param _PlayerID [number] ID of player
-- @param _Strength [number] Strength of army
-- @param _Position [string] Home area center
-- @param _LifeThread [string] Name of generator
-- @param _RodeLength [number] Rode length
-- @param _EntityTypes [table] Spawned troops
-- @param _RespawnTime [number] Time to respawn
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:CreateAISpawnArmy(_PlayerID, _Strength, _Position, _LifeThread, _RodeLength, _EntityTypes, _RespawnTime)
    self.Data.CreatedAiArmies[_PlayerID] = self.Data.CreatedAiArmies[_PlayerID] or {};
    _Strength = (_Strength < 0 and 1) or (_Strength > 8 and 8) or _Strength;

    -- Check created AI
    if not self.Data.CreatedAiPlayers[_PlayerID] then
        return;
    end

    -- Get army ID
    local ArmyID = table.getn(self.Data.CreatedAiArmies[_PlayerID]) +1;
    if ArmyID > 10 then
        return;
    end

    -- Get attack positions
    local AttackPositions = GetEntitiesByPrefix("Player" .._PlayerID.. "_AttackTarget");
    for i= 1, table.getn(AttackPositions), 1 do
        AttackPositions[i] = Logic.GetEntityName(AttackPositions[i]);
    end
    if table.getn(AttackPositions) == 0 then
        AttackPositions = nil;
    end

    -- Get patrol points
    local PatrolPoints = GetEntitiesByPrefix("Player" .._PlayerID.. "_PatrolPoint");
    for i= 1, table.getn(PatrolPoints), 1 do
        PatrolPoints[i] = Logic.GetEntityName(PatrolPoints[i]);
    end
    if table.getn(PatrolPoints) == 0 then
        PatrolPoints = {_Position};
    end

    -- Convert spawned types list
    assert(type(_EntityTypes) == "table", "CreateAISpawnArmy: _TroopTypes must be a table!");
    local SpawnedTypes = {};
    for i= 1, table.getn(_EntityTypes), 1 do
        table.insert(SpawnedTypes, {_EntityTypes[i], 16});
    end

    -- Create army
    local army 				     = {};
    army.player 			     = _PlayerID;
    army.id					     = ArmyID;
    army.strength			     = _Strength;
    army.position			     = GetPosition(_Position);
    army.rodeLength			     = _RodeLength;
    army.refresh 			     = true;
    army.retreatStrength	     = math.ceil(_Strength/3);
    army.baseDefenseRange	     = _RodeLength * 0.7;
    army.outerDefenseRange	     = _RodeLength * 1.5;

    army.spawnPos 		 	     = GetPosition(_Position);
    army.spawnGenerator 		 = _LifeThread;
    army.spawnTypes 			 = SpawnedTypes;
    army.respawnTime 		     = _RespawnTime;
    army.maxSpawnAmount 		 = math.ceil(_Strength/3);
    army.endless 			     = true;
    army.noEnemy 			     = true;
    army.noEnemyDistance 	     = 700;

    army.Advanced                = {};
    army.Advanced.attackPosition = AttackPositions;
    army.Advanced.patrolPoints   = PatrolPoints;

    table.insert(self.Data.CreatedAiArmies[_PlayerID], army);
    SetupAITroopSpawnGenerator("QuestSystemBehavior_AiArmies_" .._PlayerID.. "_" ..ArmyID, self.Data.CreatedAiArmies[_PlayerID][ArmyID]);
    Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", "QuestSystemBehavior_AiArmiesController", 1, 0, {_PlayerID, ArmyID});

    -- Default values
    AI.Army_BeAlwaysAggressive(_PlayerID, ArmyID);
    AI.Army_SetScatterTolerance(_PlayerID, ArmyID, 4);

    return ArmyID;
end

-- Controller --

QuestSystemBehavior.ArmyState          = {};
QuestSystemBehavior.ArmyState.Default  = 1;
QuestSystemBehavior.ArmyState.Refresh  = 2;
QuestSystemBehavior.ArmyState.Select   = 3;
QuestSystemBehavior.ArmyState.Attack   = 4;
QuestSystemBehavior.ArmyState.Fallback = 5;
QuestSystemBehavior.ArmyState.Patrol   = 6;

function QuestSystemBehavior_AiArmiesController(_PlayerID, _ArmyID)
    local army = QuestSystemBehavior.Data.CreatedAiArmies[_PlayerID][_ArmyID];
    local all  = QuestSystemBehavior.Data.CreatedAiArmies[_PlayerID];

    if army.Advanced ~= nil then
        if army.Advanced.State == nil then
			army.Advanced.State = QuestSystemBehavior.ArmyState.Default;
        end

        -- Army is waiting for a command
        if army.Advanced.State == QuestSystemBehavior.ArmyState.Default then
            -- Army must select an attack target
            if army.Advanced.attackPosition and army.Advanced.AttackDisabled ~= true then
                army.Advanced.State = QuestSystemBehavior.ArmyState.Select;
            else
                -- Army must patrol
                army.Advanced.State = QuestSystemBehavior.ArmyState.Patrol;
            end

        -- Army is selecting a target
        elseif army.Advanced.State == QuestSystemBehavior.ArmyState.Select then
            local underProcessing = {};
			for k,v in pairs(all) do
				if k ~= _ID and all[k].Advanced.Target ~= nil then
					table.insert(underProcessing, all[k].Advanced.Target);
				end
            end

            -- Select a attack target
            if army.Advanced.AttackDisabled ~= true and army.Advanced.attackPosition then
                for i=1,table.getn(army.Advanced.attackPosition),1 do
                    local atkPos = army.Advanced.attackPosition[i];
                    if  AreEnemiesInArea(army.player, GetPosition(atkPos), army.rodeLength)
                    and army.Advanced.Target == nil and not IstDrin(atkPos, underProcessing) then
                        Redeploy(army, GetPosition(atkPos));
                        army.Advanced.Target = atkPos;
                        army.Advanced.State = QuestSystemBehavior.ArmyState.Attack;
                        break;
                    end
                end
            end

            -- No target found? Go to patrol
            if army.Advanced.Target == nil then
                army.Advanced.State = QuestSystemBehavior.ArmyState.Patrol;
            end

        -- Army is attacking a target
        elseif army.Advanced.State == QuestSystemBehavior.ArmyState.Attack then
            -- Army needs to be refreshed
            if IsWeak(army) or IsDead(army) then
                army.Advanced.State = QuestSystemBehavior.ArmyState.Fallback;
                Redeploy(army, army.position);
            else
                -- Attack is not allowed
                if army.Advanced.AttackDisabled == true then
                    army.Advanced.State = QuestSystemBehavior.ArmyState.Default;
                    Redeploy(army, army.position);
                else
                    -- All enemies dead? Wait for command
                    if not AreEnemiesInArea(army.player, GetPosition(army.Advanced.Target), army.rodeLength) then
                        army.Advanced.State = QuestSystemBehavior.ArmyState.Default;
                        army.Advanced.Target = nil;
                    end
                end
            end

        -- Army patrols between points
        elseif army.Advanced.State == QuestSystemBehavior.ArmyState.Patrol then
            -- Army needs to be refreshed
            if IsVeryWeak(army) or IsDead(army) then
				army.Advanced.State = QuestSystemBehavior.ArmyState.Fallback;
                Redeploy(army, army.position);
            else
                -- Initial patrol station
                -- First waypoint ever is selected by random
                if army.Advanced.Waypoint == nil then
                    army.Advanced.Waypoint = math.random(1, table.gent(army.Advanced.patrolPoints));
                    army.Advanced.AnchorChanged = nil;
                    army.Advanced.StartTime = Logic.GetTime();
                end

                -- Set anchor position
                if not army.Advanced.AnchorChanged then
                    if army.Advanced.PatrolDisabled then
                        -- Army walkes back to base position
                        Redeploy(army, GetPosition(army.position));
                    else
                        -- Army walks to waypoint
                        Redeploy(army, GetPosition(army.Advanced.patrolPoints[army.Advanced.Waypoint]));
                    end
                    army.Advanced.AnchorChanged = true;
                end

                -- Army is moving to next patrol station
                if army.Advanced.StartTime + 5*60 < Logic.GetTime() then
                    army.Advanced.AnchorChanged = nil;
                    army.Advanced.Waypoint = army.Advanced.Waypoint +1;
                    if army.Advanced.Waypoint > table.getn(army.Advanced.patrolPoints) then
                        army.Advanced.Waypoint = 1;
                    end
                    army.Advanced.StartTime = Logic.GetTime();
                end

                army.Advanced.State = QuestSystemBehavior.ArmyState.Select;
			end

        -- Army is weak and returns
        elseif army.Advanced.State == QuestSystemBehavior.ArmyState.Fallback then
            -- Army needs to be refreshed
            if IsDeadWrapper(army) or IsArmyNear(army, army.position) then
                army.Advanced.State = QuestSystemBehavior.ArmyState.Refresh;
            end

        -- Army is refreshing troops
        elseif army.Advanced.State == QuestSystemBehavior.ArmyState.Refresh then
            army.Advanced.Target = nil;
            -- Army has recovered
			if HasFullStrength(army) then
                army.Advanced.State = QuestSystemBehavior.ArmyState.Default;
				Redeploy(army, army.position);
			end
        end
    else
        Advance(army);
    end
end

-- Save Actions --

function QuestSystemBehavior.UpdatePlayerColorAssigment()
    for i= 1, 8, 1 do
        local Color = QuestSystemBehavior.Data.PlayerColorAssigment[i];
        if Color then
            Display.SetPlayerColor(i, Color);
        end
    end
end

-- -------------------------------------------------------------------------- --
-- Vanilla Behavior                                                           --
-- -------------------------------------------------------------------------- --

---
-- Calls a user function as objective.
-- @param _FunctionName [string] function to call
-- @within Goals
--
function Goal_MapScriptFunction(...)
    return b_Goal_MapScriptFunction:New(unpack(arg));
end

b_Goal_MapScriptFunction = {
    Data = {
        Name = "Goal_MapScriptFunction",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_MapScriptFunction:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Goal_MapScriptFunction:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_MapScriptFunction:CustomFunction(_Quest)
    return _G[self.Data.CustomFunction](self, _Quest);
end

function b_Goal_MapScriptFunction:Debug(_Quest)
    if type(self.Data.CustomFunction) ~= "string" or _G[self.Data.CustomFunction] == nil then
        dbg(_Quest, self, "Function ist invalid:" ..tostring(self.Data.CustomFunction));
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Goal_MapScriptFunction);

-- -------------------------------------------------------------------------- --

---
-- The quest is immediately won.
-- @within Goals
--
function Goal_InstantSuccess(...)
    return b_Goal_InstantSuccess:New(unpack(arg));
end

b_Goal_InstantSuccess = {
    Data = {
        Name = "Goal_InstantSuccess",
        Type = Objectives.InstantSuccess
    },
};

function b_Goal_InstantSuccess:AddParameter(_Index, _Parameter)
end

function b_Goal_InstantSuccess:GetGoalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_InstantSuccess);

-- -------------------------------------------------------------------------- --

---
-- The quest is immediately lost.
-- @within Goals
--
function Goal_InstantFailure(...)
    return b_Goal_InstantFailure:New(unpack(arg));
end

b_Goal_InstantFailure = {
    Data = {
        Name = "Goal_InstantFailure",
        Type = Objectives.InstantSuccess
    },
};

function b_Goal_InstantFailure:AddParameter(_Index, _Parameter)
end

function b_Goal_InstantFailure:GetGoalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_InstantFailure);

-- -------------------------------------------------------------------------- --

---
-- The quest is never finished.
-- @within Goals
--
function Goal_NoChange(...)
    return b_Goal_NoChange:New(unpack(arg));
end

b_Goal_NoChange = {
    Data = {
        Name = "Goal_NoChange",
        Type = Objectives.NoChange
    },
};

function b_Goal_NoChange:AddParameter(_Index, _Parameter)
end

function b_Goal_NoChange:GetGoalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_NoChange);

-- -------------------------------------------------------------------------- --

---
-- The goal is won after the hero is comatose or the entity/army is destroyed.
-- @param _Target [string|table] Target (Army, hero, unit)
-- @within Goals
--
function Goal_Destroy(...)
    return b_Goal_Destroy:New(unpack(arg));
end

b_Goal_Destroy = {
    Data = {
        Name = "Goal_Destroy",
        Type = Objectives.Destroy
    },
};

function b_Goal_Destroy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Target = _Parameter;
    end
end

function b_Goal_Destroy:GetGoalTable()
    return {self.Data.Type, self.Data.Target};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Destroy);

-- -------------------------------------------------------------------------- --

---
-- The goal is won after the player creates entities in the area.
-- @param _EntityType [string] Entity type
-- @param _Position [string] Area center
-- @param _Area [number] Checked area size
-- @param _Amount [number] Amount to create
-- @param _Marker [boolean] Use pointer
-- @param _NewOwner [number] Change owner after completion
-- @within Goals
--
function Goal_Create(...)
    return b_Goal_Create:New(unpack(arg));
end

b_Goal_Create = {
    Data = {
        Name = "Goal_Create",
        Type = Objectives.Create
    },
};

function b_Goal_Create:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.EntityType = Entities[_Parameter];
    elseif _Index == 2 then
        self.Data.Position = _Parameter;
    elseif _Index == 3 then
        self.Data.Area = _Parameter;
    elseif _Index == 4 then
        self.Data.Amount = _Parameter;
    elseif _Index == 5 then
        self.Data.Marker = _Parameter;
    elseif _Index == 6 then
        self.Data.NewOwner = _Parameter;
    end
end

function b_Goal_Create:GetGoalTable()
    return {self.Data.Type, self.Data.EntityType, self.Data.Position, self.Data.Area, self.Data.Amount, self.Data.Marker, self.Data.NewOwner};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Create);

-- -------------------------------------------------------------------------- --

---
-- The goal is won after the receiver has the diplomatic state to the player.
-- @param _TargetPlayer [number] Entity type
-- @param _State [string] Diplomacy state name
-- @within Goals
--
function Goal_Diplomacy(...)
    return b_Goal_Diplomacy:New(unpack(arg));
end

b_Goal_Diplomacy = {
    Data = {
        Name = "Goal_Diplomacy",
        Type = Objectives.Diplomacy
    },
};

function b_Goal_Diplomacy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.State = Diplomacy[_Parameter];
    end
end

function b_Goal_Diplomacy:GetGoalTable()
    return {self.Data.Type, self.Data.PlayerID, self.Data.State};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Diplomacy);

-- -------------------------------------------------------------------------- --

---
-- The goal is won after the receiver produces some resources.
-- @param _ResourceType [string] Name of resource
-- @param _Amount [number] Amount of resource
-- @param _ExcludeRaw [boolean] Don't count raw type (default true)
-- @within Goals
--
function Goal_Produce(...)
    return b_Goal_Produce:New(unpack(arg));
end

b_Goal_Produce = {
    Data = {
        Name = "Goal_Produce",
        Type = Objectives.Produce
    },
};

function b_Goal_Produce:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ResourceType = ResourceType[_Parameter];
    elseif _Index == 2 then
        self.Data.Amount = _Parameter;
    elseif _Index == 3 then
        self.Data.ExcludeRaw = (_Parameter == nil and true) or _Parameter;
    end
end

function b_Goal_Produce:GetGoalTable()
    return {self.Data.Type, self.Data.ResourceType, self.Data.Amount, self.Data.ExcludeRaw};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Produce);

-- -------------------------------------------------------------------------- --

---
-- This goal is automatically won, after the time limit is up. Until then the
-- unit or hero must be protected.
-- @param _Target [string] Target to protect
-- @within Goals
--
function Goal_Protect(...)
    return b_Goal_Protect:New(unpack(arg));
end

b_Goal_Protect = {
    Data = {
        Name = "Goal_Protect",
        Type = Objectives.Protect
    },
};

function b_Goal_Protect:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Target = _Parameter;
    end
end

function b_Goal_Protect:GetGoalTable()
    return {self.Data.Type, self.Data.Target};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Protect);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the entity has reached (or left) the target.
-- @param _Entity [string] Entity to move
-- @param _Target [string] Target to reach
-- @param _Distance [number] Distance between entities
-- @param _LowerThan [boolean] Be lower than distance
-- @within Goals
--
function Goal_EntityDistance(...)
    return b_Goal_EntityDistance:New(unpack(arg));
end

b_Goal_EntityDistance = {
    Data = {
        Name = "Goal_EntityDistance",
        Type = Objectives.EntityDistance
    },
};

function b_Goal_EntityDistance:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Target = _Parameter;
    elseif _Index == 3 then
        self.Data.Distance = _Parameter;
    elseif _Index == 4 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.LowerThan = _Parameter;
    end
end

function b_Goal_EntityDistance:GetGoalTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Target, self.Data.Distance, self.Data.LowerThan};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_EntityDistance);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player has an amount of worker.
-- @param _Amount [number] Amount to reach
-- @param _LowerThan [boolean] Be lower than
-- @param _OtherPlayer [number] Other player
-- @within Goals
--
function Goal_WorkerCount(...)
    return b_Goal_WorkerCount:New(unpack(arg));
end

b_Goal_WorkerCount = {
    Data = {
        Name = "Goal_WorkerCount",
        Type = Objectives.Workers
    },
};

function b_Goal_WorkerCount:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Amount = _Parameter;
    elseif _Index == 2 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.BeLowerThan = _Parameter;
    elseif _Index == 3 then
        self.Data.OtherPlayer = _Parameter;
    end
end

function b_Goal_WorkerCount:GetGoalTable()
    return {self.Data.Type, self.Data.Amount, self.Data.BeLowerThan, self.Data.OtherPlayer};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_WorkerCount);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player has an amount of motivation.
-- @param _Amount [number] Amount to reach
-- @param _LowerThan [boolean] Be lower than
-- @param _OtherPlayer [number] Other player
-- @within Goals
--
function Goal_Motivation(...)
    return b_Goal_Motivation:New(unpack(arg));
end

b_Goal_Motivation = {
    Data = {
        Name = "Goal_Motivation",
        Type = Objectives.Motivation
    },
};

function b_Goal_Motivation:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Amount = _Parameter;
    elseif _Index == 2 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.BeLowerThan = _Parameter;
    elseif _Index == 3 then
        self.Data.OtherPlayer = _Parameter;
    end
end

function b_Goal_Motivation:GetGoalTable()
    return {self.Data.Type, self.Data.Amount, self.Data.BeLowerThan, self.Data.OtherPlayer};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Motivation);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player has an amount of settlers.
-- @param _Amount [number] Amount to reach
-- @param _LowerThan [boolean] Be lower than
-- @param _OtherPlayer [number] Other player
-- @within Goals
--
function Goal_SettlerCount(...)
    return b_Goal_SettlerCount:New(unpack(arg));
end

b_Goal_SettlerCount = {
    Data = {
        Name = "Goal_SettlerCount",
        Type = Objectives.Settlers
    },
};

function b_Goal_SettlerCount:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Amount = _Parameter;
    elseif _Index == 2 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.BeLowerThan = _Parameter;
    elseif _Index == 3 then
        self.Data.OtherPlayer = _Parameter;
    end
end

function b_Goal_SettlerCount:GetGoalTable()
    return {self.Data.Type, self.Data.Amount, self.Data.BeLowerThan, self.Data.OtherPlayer};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_SettlerCount);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player has an amount of soldiers.
-- @param _Amount [number] Amount to reach
-- @param _LowerThan [boolean] Be lower than
-- @param _OtherPlayer [number] Other player
-- @within Goals
--
function Goal_SoldierCount(...)
    return b_Goal_SoldierCount:New(unpack(arg));
end

b_Goal_SoldierCount = {
    Data = {
        Name = "Goal_SoldierCount",
        Type = Objectives.Settlers
    },
};

function b_Goal_SoldierCount:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Amount = _Parameter;
    elseif _Index == 2 then
        if type(_Parameter) == "string" then
            _Parameter = _Parameter == "<";
        end
        self.Data.BeLowerThan = _Parameter;
    elseif _Index == 3 then
        self.Data.OtherPlayer = _Parameter;
    end
end

function b_Goal_SoldierCount:GetGoalTable()
    return {self.Data.Type, self.Data.Amount, self.Data.BeLowerThan, self.Data.OtherPlayer};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_SoldierCount);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the player reached an amount of units.
-- @param _EntityType [string] Entity type name
-- @param _Amount [number] Amount to reach
-- @within Goals
--
function Goal_Units(...)
    return b_Goal_Units:New(unpack(arg));
end

b_Goal_Units = {
    Data = {
        Name = "Goal_Units",
        Type = Objectives.Units
    },
};

function b_Goal_Units:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.UnitType = Entities[_Parameter];
    elseif _Index == 2 then
        self.Data.Amount = _Parameter;
    end
end

function b_Goal_Units:GetGoalTable()
    return {self.Data.Type, self.Data.UnitType, self.Data.Amount};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Units);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver has researched the technology.
-- @param _Technology [string] Technology name
-- @within Goals
--
function Goal_Technology(...)
    return b_Goal_Technology:New(unpack(arg));
end

b_Goal_Technology = {
    Data = {
        Name = "Goal_Technology",
        Type = Objectives.Technology
    },
};

function b_Goal_Technology:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Technology = Technologies[_Parameter];
    end
end

function b_Goal_Technology:GetGoalTable()
    return {self.Data.Type, self.Data.Technology};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Technology);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver has upgraded their headquarters.
-- @param _Level [number] Upgrades (1 or 2)
-- @within Goals
--
function Goal_UpgradeHeadquarters(...)
    return b_Goal_UpgradeHeadquarters:New(unpack(arg));
end

b_Goal_UpgradeHeadquarters = {
    Data = {
        Name = "Goal_UpgradeHeadquarters",
        Type = Objectives.Headquarters
    },
};

function b_Goal_UpgradeHeadquarters:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Level = _Parameter;
    end
end

function b_Goal_UpgradeHeadquarters:GetGoalTable()
    return {self.Data.Type, self.Data.Level};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_UpgradeHeadquarters);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after a hero of the receiver talked to the character.
-- It can be any hero or a special named hero.
-- @param _Target [string] Target entity
-- @param _Hero [string] Optional required hero
-- @param _Message [string] Optional wrong hero message
-- @within Goals
--
function Goal_NPC(...)
    return b_Goal_NPC:New(unpack(arg));
end

b_Goal_NPC = {
    Data = {
        Name = "Goal_NPC",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_NPC:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Target = _Parameter;
    elseif _Index == 2 then
        if _Parameter == "" then
            _Parameter = nil;
        end
        self.Data.Hero = _Parameter;
    elseif _Index == 3 then
        if _Parameter == "" then
            _Parameter = nil;
        end
        self.Data.Message = _Parameter;
    end
end

function b_Goal_NPC:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_NPC:CustomFunction(_Quest)
    if not IsExisting(self.Data.Target) then
        return false;
    end
    if not self.Data.NPC then
        self.Data.NPC = new(NonPlayerCharacter, self.Data.Target):SetHero(self.Data.Hero):SetHeroInfo(self.Data.Message):Activate();
    end
    if self.Data.NPC:TalkedTo() then
        return true;
    end
end

function b_Goal_NPC:Debug(_Quest)
    if Logic.IsSettler(GetID(self.Data.Target)) == 0 then
        dbg(_Quest, self, "NPCs must be settlers!");
        return true;
    end
    if self.Data.Hero and (IsExisting(self.Data.Hero) == false or Logic.IsHero(GetID(self.Data.Hero)) == 0) then
        dbg(_Quest, self, "Hero '" ..self.Data.Hero.. "' is invalid!");
        return true;
    end
    if self.Data.Hero and self.Data.Message == nil then
        dbg(_Quest, self, "Wrong hero message is missing!");
        return true;
    end
    return false;
end

function b_Goal_NPC:Reset(_Quest)
    if self.Data.NPC then
        self.Data.NPC:Deactivate();
    end
    self.Data.NPC = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Goal_NPC);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver destroyed some entities of type of the
-- player.
-- @param _PlayerID [number] Owner of entities
-- @param _TypeName [string] Entity type name
-- @param _Amount [number] Amount to destroy
-- @within Goals
--
function Goal_DestroyType(...)
    return b_Goal_DestroyType:New(unpack(arg));
end

b_Goal_DestroyType = {
    Data = {
        Name = "Goal_DestroyType",
        Type = Objectives.DestroyType
    },
};

function b_Goal_DestroyType:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.TypeName = Entities[_Parameter];
    elseif _Index == 3 then
        self.Data.Amount = _Parameter;
    end
end

function b_Goal_DestroyType:GetGoalTable()
    return {self.Data.Type, self.Data.PlayerID, self.Data.TypeName, self.Data.Amount};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyType);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver destroyed some entities of category of
-- the player.
-- @param _PlayerID [number] Owner of entities
-- @param _TypeName [string] Entity type name
-- @param _Amount [number] Amount to destroy
-- @within Goals
--
function Goal_DestroyCategory(...)
    return b_Goal_DestroyCategory:New(unpack(arg));
end

b_Goal_DestroyCategory = {
    Data = {
        Name = "Goal_DestroyCategory",
        Type = Objectives.DestroyCategory
    },
};

function b_Goal_DestroyCategory:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.CategoryName = EntityCategories[_Parameter];
    elseif _Index == 3 then
        self.Data.Amount = _Parameter;
    end
end

function b_Goal_DestroyCategory:GetGoalTable()
    return {self.Data.Type, self.Data.PlayerID, self.Data.CategoryName, self.Data.Amount};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyCategory);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver payed the tribute.
-- @param _Resource [string] Tribute resource
-- @param _Amount [number] Tribute high
-- @param _Message [number] Tribute message
-- @within Goals
--
function Goal_Tribute(...)
    return b_Goal_Tribute:New(unpack(arg));
end

b_Goal_Tribute = {
    Data = {
        Name = "Goal_Tribute",
        Type = Objectives.Tribute
    },
};

function b_Goal_Tribute:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Resource = ResourceType[_Parameter];
    elseif _Index == 2 then
        self.Data.Amount = _Parameter;
    elseif _Index == 3 then
        self.Data.Message = _Parameter;
    end
end

function b_Goal_Tribute:GetGoalTable()
    return {self.Data.Type, {self.Data.Resource, self.Data.Amount}, self.Data.Message};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_Tribute);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after the receiver changed the weather to the state.
-- @param _State [number] Weather state
-- @within Goals
--
function Goal_WeatherState(...)
    return b_Goal_WeatherState:New(unpack(arg));
end

b_Goal_WeatherState = {
    Data = {
        Name = "Goal_WeatherState",
        Type = Objectives.WeatherState
    },
};

function b_Goal_WeatherState:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.StateID = _Parameter;
    end
end

function b_Goal_WeatherState:GetGoalTable()
    return {self.Data.Type, self.Data.StateID};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_WeatherState);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after some offers of a merchant are bought.
-- @param _Merchant [number] Merchant npc
-- @param _Offer [number] Index of offer
-- @param _Amount [number] Amount to buy
-- @within Goals
--
function Goal_BuyOffer(...)
    return b_Goal_BuyOffer:New(unpack(arg));
end

b_Goal_BuyOffer = {
    Data = {
        Name = "Goal_BuyOffer",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_BuyOffer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    elseif _Index == 2 then
        self.Data.Offer = _Parameter;
    elseif _Index == 3 then
        self.Data.Amount = _Parameter;
    end
end

function b_Goal_BuyOffer:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_BuyOffer:CustomFunction(_Quest)
    if not Interaction.IO[self.Data.Merchant] then
        return false;
    end
    if Interaction.IO[self.Data.Merchant]:GetTradingVolume(self.Data.Offer) >= self.Data.Amount then
        return true;
    end
end

QuestSystemBehavior:RegisterBehavior(b_Goal_BuyOffer);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after all units of a player are destroyed.
-- @param _PlayerID [number] id of player
-- @within Goals
--
function Goal_DestroyAllPlayerUnits(...)
    return b_Goal_DestroyAllPlayerUnits:New(unpack(arg));
end

b_Goal_DestroyAllPlayerUnits = {
    Data = {
        Name = "Goal_DestroyAllPlayerUnits",
        Type = Objectives.DestroyAllPlayerUnits
    },
};

function b_Goal_DestroyAllPlayerUnits:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    end
end

function b_Goal_DestroyAllPlayerUnits:GetGoalTable()
    return {self.Data.Type, self.Data.PlayerID};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyAllPlayerUnits);

-- -------------------------------------------------------------------------- --

---
-- Calls a user function as reprisal.
-- @param _FunctionName [string] function to call
-- @within Reprisals
--
function Reprisal_MapScriptFunction(...)
    return b_Reprisal_MapScriptFunction:New(unpack(arg));
end

b_Reprisal_MapScriptFunction = {
    Data = {
        Name = "Reprisal_MapScriptFunction",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_MapScriptFunction:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Reprisal_MapScriptFunction:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_MapScriptFunction:CustomFunction(_Quest)
    _G[self.Data.CustomFunction](self, _Quest);
end

function b_Reprisal_MapScriptFunction:Debug(_Quest)
    if type(self.Data.CustomFunction) ~= "string" or _G[self.Data.CustomFunction] == nil then
        dbg(_Quest, self, "Function ist invalid:" ..tostring(self.Data.CustomFunction));
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_MapScriptFunction);

-- -------------------------------------------------------------------------- --

---
-- The receiver loses the game.
-- @within Reprisals
--
function Reprisal_Defeat(...)
    return b_Reprisal_Defeat:New(unpack(arg));
end

b_Reprisal_Defeat = {
    Data = {
        Name = "Reprisal_Defeat",
        Type = Callbacks.Defeat
    },
};

function b_Reprisal_Defeat:AddParameter(_Index, _Parameter)
end

function b_Reprisal_Defeat:GetReprisalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Defeat);

-- -------------------------------------------------------------------------- --

---
-- The receiver wins the game.
-- @within Reprisals
--
function Reprisal_Victory(...)
    return b_Reprisal_Victory:New(unpack(arg));
end

b_Reprisal_Victory = {
    Data = {
        Name = "Reprisal_Victory",
        Type = Callbacks.Victory
    },
};

function b_Reprisal_Victory:AddParameter(_Index, _Parameter)
end

function b_Reprisal_Victory:GetReprisalTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Victory);

-- -------------------------------------------------------------------------- --

---
-- Starts the briefing. The briefing function must return the briefing id.
-- @param _FunctionName [string] function to call
-- @within Reprisals
--
function Reprisal_Briefing(...)
    return b_Reprisal_Briefing:New(unpack(arg));
end

b_Reprisal_Briefing = {
    Data = {
        Name = "Reprisal_Briefing",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_Briefing:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Briefing = _Parameter;
    end
end

function b_Reprisal_Briefing:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_Briefing:CustomFunction(_Quest)
    _Quest.m_Briefing = _G[self.Data.Briefing](self, _Quest);
end

function b_Reprisal_Briefing:Debug(_Quest)
    if type(self.Data.Briefing) ~= "string" or _G[self.Data.Briefing] == nil then
        dbg(_Quest, self, "Briefing functtion ist invalid:" ..tostring(self.Data.Briefing));
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Briefing);

-- -------------------------------------------------------------------------- --

---
-- Changes the owner of the entity.
-- @param _Entity [string] Entity to change
-- @param _Owner [number] Owner of entity
-- @within Reprisals
--
function Reprisal_ChangePlayer(...)
    return b_Reprisal_ChangePlayer:New(unpack(arg));
end

b_Reprisal_ChangePlayer = {
    Data = {
        Name = "Reprisal_ChangePlayer",
        Type = Callbacks.ChangePlayer
    },
};

function b_Reprisal_ChangePlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Owner = _Parameter;
    end
end

function b_Reprisal_ChangePlayer:GetReprisalTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Owner};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_ChangePlayer);

-- -------------------------------------------------------------------------- --

---
-- Displays a text message on the screen.
-- @param _Message [string] Message to display
-- @within Reprisals
--
function Reprisal_Message(...)
    return b_Reprisal_Message:New(unpack(arg));
end

b_Reprisal_Message = {
    Data = {
        Name = "Reprisal_Message",
        Type = Callbacks.Message
    },
};

function b_Reprisal_Message:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Message = _Parameter;
    end
end

function b_Reprisal_Message:GetReprisalTable()
    return {self.Data.Type, self.Data.Message};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Message);

-- -------------------------------------------------------------------------- --

---
-- Replaces the entity with a XD_ScriptEntity.
-- @param _Entity [string] Entity to destroy
-- @within Reprisals
--
function Reprisal_DestroyEntity(...)
    return b_Reprisal_DestroyEntity:New(unpack(arg));
end

b_Reprisal_DestroyEntity = {
    Data = {
        Name = "Reprisal_DestroyEntity",
        Type = Callbacks.DestroyEntity
    },
};

function b_Reprisal_DestroyEntity:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    end
end

function b_Reprisal_DestroyEntity:GetReprisalTable()
    return {self.Data.Type, self.Data.Entity};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_DestroyEntity);

-- -------------------------------------------------------------------------- --

---
-- Destroys the effect with the given effect name.
-- @param _Effect [string] Effect to destroy
-- @within Reprisals
--
function Reprisal_DestroyEffect(...)
    return b_Reprisal_DestroyEffect:New(unpack(arg));
end

b_Reprisal_DestroyEffect = {
    Data = {
        Name = "Reprisal_DestroyEffect",
        Type = Callbacks.DestroyEffect
    },
};

function b_Reprisal_DestroyEffect:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Effect = _Parameter;
    end
end

function b_Reprisal_DestroyEffect:GetReprisalTable()
    return {self.Data.Type, self.Data.Effect};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_DestroyEffect);

-- -------------------------------------------------------------------------- --

---
-- Changes the diplomacy state between two players.
-- @param _PlayerID1 [number] First player id
-- @param _PlayerID2 [number] Second player id
-- @param _Diplomacy [string] Diplomacy state name
-- @within Reprisals
--
function Reprisal_Diplomacy(...)
    return b_Reprisal_Diplomacy:New(unpack(arg));
end

b_Reprisal_Diplomacy = {
    Data = {
        Name = "Reprisal_Diplomacy",
        Type = Callbacks.Diplomacy
    },
};

function b_Reprisal_Diplomacy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID1 = _Parameter;
    elseif _Index == 2 then
        self.Data.PlayerID2 = _Parameter;
    elseif _Index == 3 then
        self.Data.Diplomacy = Diplomacy[_Parameter];
    end
end

function b_Reprisal_Diplomacy:GetReprisalTable()
    return {self.Data.Type, self.Data.PlayerID1, self.Data.PlayerID2, self.Data.Diplomacy};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Diplomacy);

-- -------------------------------------------------------------------------- --

---
-- Removes the description of a quest from the quest book.
-- @param _QuestName [string] Quest name
-- @within Reprisals
--
function Reprisal_RemoveQuest(...)
    return b_Reprisal_RemoveQuest:New(unpack(arg));
end

b_Reprisal_RemoveQuest = {
    Data = {
        Name = "Reprisal_RemoveQuest",
        Type = Callbacks.RemoveQuest
    },
};

function b_Reprisal_RemoveQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_RemoveQuest:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_RemoveQuest);

-- -------------------------------------------------------------------------- --

---
-- Let the quest succeed.
-- @param _QuestName [string] Quest name
-- @within Reprisals
--
function Reprisal_QuestSucceed(...)
    return b_Reprisal_QuestSucceed:New(unpack(arg));
end

b_Reprisal_QuestSucceed = {
    Data = {
        Name = "Reprisal_QuestSucceed",
        Type = Callbacks.QuestSucceed
    },
};

function b_Reprisal_QuestSucceed:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestSucceed:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestSucceed);

-- -------------------------------------------------------------------------- --

---
-- Let the quest fail.
-- @param _QuestName [string] Quest name
-- @within Reprisals
--
function Reprisal_QuestFail(...)
    return b_Reprisal_QuestFail:New(unpack(arg));
end

b_Reprisal_QuestFail = {
    Data = {
        Name = "Reprisal_QuestFail",
        Type = Callbacks.QuestFail
    },
};

function b_Reprisal_QuestFail:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestFail:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestFail);

-- -------------------------------------------------------------------------- --

---
-- Interrupts the quest.
-- @param _QuestName [string] Quest name
-- @within Reprisals
--
function Reprisal_QuestInterrupt(...)
    return b_Reprisal_QuestInterrupt:New(unpack(arg));
end

b_Reprisal_QuestInterrupt = {
    Data = {
        Name = "Reprisal_QuestInterrupt",
        Type = Callbacks.QuestInterrupt
    },
};

function b_Reprisal_QuestInterrupt:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestInterrupt:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestInterrupt);

-- -------------------------------------------------------------------------- --

---
-- Activates the quest.
-- @param _QuestName [string] Quest name
-- @within Reprisals
--
function Reprisal_QuestActivate(...)
    return b_Reprisal_QuestActivate:New(unpack(arg));
end

b_Reprisal_QuestActivate = {
    Data = {
        Name = "Reprisal_QuestActivate",
        Type = Callbacks.QuestActivate
    },
};

function b_Reprisal_QuestActivate:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestActivate:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestActivate);

-- -------------------------------------------------------------------------- --

---
-- Restarts the quest.
-- @param _QuestName [string] Quest name
-- @within Reprisals
--
function Reprisal_QuestRestart(...)
    return b_Reprisal_QuestRestart:New(unpack(arg));
end

b_Reprisal_QuestRestart = {
    Data = {
        Name = "Reprisal_QuestRestart",
        Type = Callbacks.QuestRestart
    },
};

function b_Reprisal_QuestRestart:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestRestart:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestRestart);

-- -------------------------------------------------------------------------- --

---
-- Changes the state of a technology.
-- @param _Technology [string] Technology name
-- @param _State [string] Technology state name
-- @within Reprisals
--
function Reprisal_Technology(...)
    return b_Reprisal_Technology:New(unpack(arg));
end

b_Reprisal_Technology = {
    Data = {
        Name = "Reprisal_Technology",
        Type = Callbacks.Technology
    },
};

function b_Reprisal_Technology:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Technology = Technologies[_Parameter];
    elseif _Index == 2 then
        self.Data.State = TechnologyStates[_Parameter];
    end
end

function b_Reprisal_Technology:GetReprisalTable()
    return {self.Data.Type, self.Data.Technology, self.Data.State};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Technology);

-- -------------------------------------------------------------------------- --

---
-- Removes the exploration of an area.
-- @param _AreaCenter [string] Center of exploration
-- @within Reprisals
--
function Reprisal_ConcealArea(...)
    return b_Reprisal_ConcealArea:New(unpack(arg));
end

b_Reprisal_ConcealArea = {
    Data = {
        Name = "Reprisal_ConcealArea",
        Type = Callbacks.ConcealArea
    },
};

function b_Reprisal_ConcealArea:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.AreaCenter = _Parameter;
    end
end

function b_Reprisal_ConcealArea:GetReprisalTable()
    return {self.Data.Type, self.Data.AreaCenter};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_ConcealArea);

-- -------------------------------------------------------------------------- --

---
-- Moves an entity to the destination.
-- @param _Entity [string] Entity to move
-- @param _Destination [string] Moving target of entity
-- @within Reprisals
--
function Reprisal_Move(...)
    return b_Reprisal_Move:New(unpack(arg));
end

b_Reprisal_Move = {
    Data = {
        Name = "Reprisal_Move",
        Type = Callbacks.Move
    },
};

function b_Reprisal_Move:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Destination = _Parameter;
    end
end

function b_Reprisal_Move:GetReprisalTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Destination};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_Move);

-- -------------------------------------------------------------------------- --

---
-- Calls a user function as reward.
-- @param _FunctionName [string] function to call
-- @within Rewards
--
function Reward_MapScriptFunction(...)
    return b_Reward_MapScriptFunction:New(unpack(arg));
end

b_Reward_MapScriptFunction = {
    Data = {
        Name = "Reward_MapScriptFunction",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_MapScriptFunction:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Reward_MapScriptFunction:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_MapScriptFunction:CustomFunction(_Quest)
    _G[self.Data.CustomFunction](self, _Quest);
end

function b_Reward_MapScriptFunction:Debug(_Quest)
    if type(self.Data.CustomFunction) ~= "string" or _G[self.Data.CustomFunction] == nil then
        dbg(_Quest, self, "Function ist invalid:" ..tostring(self.Data.CustomFunction));
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reward_MapScriptFunction);

-- -------------------------------------------------------------------------- --

---
-- The receiver loses the game.
-- @within Rewards
--
function Reward_Defeat(...)
    return b_Reward_Defeat:New(unpack(arg));
end

b_Reward_Defeat = copy(b_Reprisal_Defeat);
b_Reward_Defeat.Data.Name = "Reward_Defeat";
b_Reward_Defeat.Data.Type = Callbacks.Defeat;
b_Reward_Defeat.GetReprisalTable = nil;

function b_Reward_Defeat:GetRewardTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Defeat);

-- -------------------------------------------------------------------------- --

---
-- The receiver wins the game.
-- @within Rewards
--
function Reward_Victory(...)
    return b_Reward_Victory:New(unpack(arg));
end

b_Reward_Victory = copy(b_Reprisal_Victory);
b_Reward_Victory.Data.Name = "Reward_Victory";
b_Reward_Victory.Data.Type = Callbacks.Victory;
b_Reward_Victory.GetReprisalTable = nil;

function b_Reward_Victory:GetRewardTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Victory);

-- -------------------------------------------------------------------------- --

---
-- Starts the briefing. The briefing function must return the briefing id.
-- @param _FunctionName [string] function to call
-- @within Rewards
--
function Reward_Briefing(...)
    return b_Reward_Briefing:New(unpack(arg));
end

b_Reward_Briefing = copy(b_Reprisal_Briefing);
b_Reward_Briefing.Data.Name = "Reward_Briefing";
b_Reward_Briefing.Data.Type = Callbacks.MapScriptFunction;
b_Reward_Briefing.GetReprisalTable = nil;

function b_Reward_Briefing:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Briefing);

-- -------------------------------------------------------------------------- --

---
-- Changes the owner of the entity.
-- @param _Entity [string] Entity to change
-- @param _Owner [number] Owner of entity
-- @within Rewards
--
function Reward_ChangePlayer(...)
    return b_Reward_ChangePlayer:New(unpack(arg));
end

b_Reward_ChangePlayer = copy(b_Reprisal_ChangePlayer);
b_Reward_ChangePlayer.Data.Name = "Reward_ChangePlayer";
b_Reward_ChangePlayer.Data.Type = Callbacks.ChangePlayer;
b_Reward_ChangePlayer.GetReprisalTable = nil;

function b_Reward_ChangePlayer:GetRewardTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Owner};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_ChangePlayer);

-- -------------------------------------------------------------------------- --

---
-- Displays a text message on the screen.
-- @param _Message [string] Message to display
-- @within Rewards
--
function Reward_Message(...)
    return b_Reward_Message:New(unpack(arg));
end

b_Reward_Message = copy(b_Reprisal_Message);
b_Reward_Message.Data.Name = "Reward_Message";
b_Reward_Message.Data.Type = Callbacks.Message;
b_Reward_Message.GetReprisalTable = nil;

function b_Reward_Message:GetRewardTable()
    return {self.Data.Type, self.Data.Message};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Message);

-- -------------------------------------------------------------------------- --

---
-- Replaces the entity with a XD_ScriptEntity.
-- @param _Entity [string] Entity to destroy
-- @within Rewards
--
function Reward_DestroyEntity(...)
    return b_Reward_DestroyEntity:New(unpack(arg));
end

b_Reward_DestroyEntity = copy(b_Reprisal_DestroyEntity);
b_Reward_DestroyEntity.Data.Name = "Reward_DestroyEntity";
b_Reward_DestroyEntity.Data.Type = Callbacks.DestroyEntity;
b_Reward_DestroyEntity.GetReprisalTable = nil;

function b_Reward_DestroyEntity:GetRewardTable()
    return {self.Data.Type, self.Data.Entity};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_DestroyEntity);

-- -------------------------------------------------------------------------- --

---
-- Destroys the effect with the given effect name.
-- @param _Effect [string] Effect to destroy
-- @within Rewards
--
function Reward_DestroyEffect(...)
    return b_Reward_DestroyEffect:New(unpack(arg));
end

b_Reward_DestroyEffect = copy(b_Reprisal_DestroyEffect);
b_Reward_DestroyEffect.Data.Name = "Reward_DestroyEffect";
b_Reward_DestroyEffect.Data.Type = Callbacks.DestroyEffect;
b_Reward_DestroyEffect.GetReprisalTable = nil;

function b_Reward_DestroyEffect:GetRewardTable()
    return {self.Data.Type, self.Data.Effect};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_DestroyEffect);

-- -------------------------------------------------------------------------- --

---
-- Changes the diplomacy state between two players.
-- @param _PlayerID1 [number] First player id
-- @param _PlayerID2 [number] Second player id
-- @param _Diplomacy [string] Diplomacy state name
-- @within Rewards
--
function Reward_Diplomacy(...)
    return b_Reward_Diplomacy:New(unpack(arg));
end

b_Reward_Diplomacy = copy(b_Reprisal_Diplomacy);
b_Reward_Diplomacy.Data.Name = "Reward_Diplomacy";
b_Reward_Diplomacy.Data.Type = Callbacks.Diplomacy;
b_Reward_Diplomacy.GetReprisalTable = nil;

function b_Reward_Diplomacy:GetRewardTable()
    return {self.Data.Type, self.Data.PlayerID1, self.Data.PlayerID2, self.Data.Diplomacy};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Diplomacy);

-- -------------------------------------------------------------------------- --

---
-- Removes the description of a quest from the quest book.
-- @param _QuestName [string] Quest name
-- @within Rewards
--
function Reward_RemoveQuest(...)
    return b_Reward_RemoveQuest:New(unpack(arg));
end

b_Reward_RemoveQuest = copy(b_Reprisal_RemoveQuest);
b_Reward_RemoveQuest.Data.Name = "Reward_RemoveQuest";
b_Reward_RemoveQuest.Data.Type = Callbacks.RemoveQuest;
b_Reward_RemoveQuest.GetReprisalTable = nil;

function b_Reward_RemoveQuest:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_RemoveQuest);

-- -------------------------------------------------------------------------- --

---
-- Let the quest succeed.
-- @param _QuestName [string] Quest name
-- @within Rewards
--
function Reward_QuestSucceed(...)
    return b_Reward_QuestSucceed:New(unpack(arg));
end

b_Reward_QuestSucceed = copy(b_Reprisal_QuestSucceed);
b_Reward_QuestSucceed.Data.Name = "Reward_QuestSucceed";
b_Reward_QuestSucceed.Data.Type = Callbacks.QuestSucceed;
b_Reward_QuestSucceed.GetReprisalTable = nil;

function b_Reward_QuestSucceed:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestSucceed);

-- -------------------------------------------------------------------------- --

---
-- Let the quest fail.
-- @param _QuestName [string] Quest name
-- @within Rewards
--
function Reward_QuestFail(...)
    return b_Reward_QuestFail:New(unpack(arg));
end

b_Reward_QuestFail = copy(b_Reprisal_QuestFail);
b_Reward_QuestFail.Data.Name = "Reward_QuestFail";
b_Reward_QuestFail.Data.Type = Callbacks.QuestFail;
b_Reward_QuestFail.GetReprisalTable = nil;

function b_Reward_QuestFail:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestFail);

-- -------------------------------------------------------------------------- --

---
-- Interrupts the quest.
-- @param _QuestName [string] Quest name
-- @within Rewards
--
function Reward_QuestInterrupt(...)
    return b_Reward_QuestInterrupt:New(unpack(arg));
end

b_Reward_QuestInterrupt = copy(b_Reprisal_QuestInterrupt);
b_Reward_QuestInterrupt.Data.Name = "Reward_QuestInterrupt";
b_Reward_QuestInterrupt.Data.Type = Callbacks.QuestInterrupt;
b_Reward_QuestInterrupt.GetReprisalTable = nil;

function b_Reward_QuestInterrupt:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestInterrupt);

-- -------------------------------------------------------------------------- --

---
-- Activates the quest.
-- @param _QuestName [string] Quest name
-- @within Rewards
--
function Reward_QuestActivate(...)
    return b_Reward_QuestActivate:New(unpack(arg));
end

b_Reward_QuestActivate = copy(b_Reprisal_QuestActivate);
b_Reward_QuestActivate.Data.Name = "Reward_QuestActivate";
b_Reward_QuestActivate.Data.Type = Callbacks.QuestActivate;
b_Reward_QuestActivate.GetReprisalTable = nil;

function b_Reward_QuestActivate:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestActivate);

-- -------------------------------------------------------------------------- --

---
-- Restarts the quest.
-- @param _QuestName [string] Quest name
-- @within Rewards
--
function Reward_QuestRestart(...)
    return b_Reward_QuestRestart:New(unpack(arg));
end

b_Reward_QuestRestart = copy(b_Reprisal_QuestRestart);
b_Reward_QuestRestart.Data.Name = "Reward_QuestRestart";
b_Reward_QuestRestart.Data.Type = Callbacks.QuestRestart;
b_Reward_QuestRestart.GetReprisalTable = nil;

function b_Reward_QuestRestart:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestRestart);

-- -------------------------------------------------------------------------- --

---
-- Changes the state of a technology.
-- @param _Technology [string] Technology name
-- @param _State [string] Technology state name
-- @within Rewards
--
function Reward_Technology(...)
    return b_Reward_Technology:New(unpack(arg));
end

b_Reward_Technology = copy(b_Reprisal_Technology);
b_Reward_Technology.Data.Name = "Reward_Technology";
b_Reward_Technology.Data.Type = Callbacks.Technology;
b_Reward_Technology.GetReprisalTable = nil;

function b_Reward_Technology:GetRewardTable()
    return {self.Data.Type, self.Data.Technology, self.Data.State};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Technology);

-- -------------------------------------------------------------------------- --

---
-- Removes the exploration of an area.
-- @param _AreaCenter [string] Center of exploration
-- @within Rewards
--
function Reward_ConcealArea(...)
    return b_Reward_ConcealArea:New(unpack(arg));
end

b_Reward_ConcealArea = copy(b_Reprisal_ConcealArea);
b_Reward_ConcealArea.Data.Name = "Reward_ConcealArea";
b_Reward_ConcealArea.Data.Type = Callbacks.ConcealArea;
b_Reward_ConcealArea.GetReprisalTable = nil;

function b_Reward_ConcealArea:GetRewardTable()
    return {self.Data.Type, self.Data.AreaCenter};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_ConcealArea);

-- -------------------------------------------------------------------------- --

---
-- Moves an entity to the destination.
-- @param _Entity [string] Entity to move
-- @param _Destination [string] Moving target of entity
-- @within Rewards
--
function Reward_Move(...)
    return b_Reward_Move:New(unpack(arg));
end

b_Reward_Move = copy(b_Reprisal_Move);
b_Reward_Move.Data.Name = "Reward_Move";
b_Reward_Move.Data.Type = Callbacks.Move;
b_Reward_Move.GetReprisalTable = nil;

function b_Reward_Move:GetRewardTable()
    return {self.Data.Type, self.Data.Entity, self.Data.Destination};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Move);

-- -------------------------------------------------------------------------- --

---
-- Replaces an script entity with a new entity of the chosen type.
-- @param _ScriptName [string] Script name of entity
-- @param _EntityType [string] Entity type name
-- @within Rewards
--
function Reward_CreateEntity(...)
    return b_Reward_CreateEntity:New(unpack(arg));
end

b_Reward_CreateEntity = {
    Data = {
        Name = "Reward_CreateEntity",
        Type = Callbacks.CreateEntity
    },
};

function b_Reward_CreateEntity:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ScriptName = _Parameter;
    elseif _Index == 2 then
        self.Data.EntityType = Entities[_Parameter];
    end
end

function b_Reward_CreateEntity:GetRewardTable()
    return {self.Data.Type, self.Data.ScriptName, self.Data.EntityType};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateEntity);

-- -------------------------------------------------------------------------- --

---
-- Replaces an script entity with a military group of the chosen type.
-- @param _ScriptName [string] Script name of entity
-- @param _EntityType [string] Entity type name
-- @param _Soldiers [number] Amount of soldiers
-- @within Rewards
--
function Reward_CreateGroup(...)
    return b_Reward_CreateGroup:New(unpack(arg));
end

b_Reward_CreateGroup = {
    Data = {
        Name = "Reward_CreateGroup",
        Type = Callbacks.CreateGroup
    },
};

function b_Reward_CreateGroup:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ScriptName = _Parameter;
    elseif _Index == 2 then
        self.Data.EntityType = Entities[_Parameter];
    elseif _Index == 3 then
        self.Data.EntityType = _Parameter;
    end
end

function b_Reward_CreateGroup:GetRewardTable()
    return {self.Data.Type, self.Data.ScriptName, self.Data.EntityType, self.Data.SoldierCount};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateGroup);

-- -------------------------------------------------------------------------- --

---
-- Creates an effect at the position.
-- @param _EffectName [string] Name for the effect
-- @param _Position [number] Position of effect
-- @param _EffectType [string] Effect type name
-- @within Rewards
--
function Reward_CreateEffect(...)
    return b_Reward_CreateEffect:New(unpack(arg));
end

b_Reward_CreateEffect = {
    Data = {
        Name = "Reward_CreateEffect",
        Type = Callbacks.CreateEffect
    },
};

function b_Reward_CreateEffect:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.EffectName = _Parameter;
    elseif _Index == 2 then
        self.Data.Position = _Parameter;
    elseif _Index == 3 then
        self.Data.EffectType = GGL_Effects[_Parameter];
    end
end

function b_Reward_CreateEffect:GetRewardTable()
    return {self.Data.Type, self.Data.EffectName, self.Data.EffectType, self.Data.Position};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateEffect);

-- -------------------------------------------------------------------------- --

---
-- Give or remove resources from the player.
-- @param _Resource [string] Name for the effect
-- @param _Amount [string] Effect type name
-- @within Rewards
--
function Reward_Resource(...)
    return b_Reward_Resource:New(unpack(arg));
end

b_Reward_Resource = {
    Data = {
        Name = "Reward_Resource",
        Type = Callbacks.Resource
    },
};

function b_Reward_Resource:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Resource = ResourceType[_Parameter];
    elseif _Index == 2 then
        self.Data.Amount = _Parameter;
    end
end

function b_Reward_Resource:GetRewardTable()
    return {self.Data.Type, self.Data.Resource, self.Data.Amount};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_Resource);

-- -------------------------------------------------------------------------- --

---
-- Creates an minimap marker or minimap pulsar at the position.
-- @param _MarkerType [string] Marker type name
-- @param _Position [string] Position of marker
-- @within Rewards
--
function Reward_CreateMarker(...)
    return b_Reward_CreateMarker:New(unpack(arg));
end

b_Reward_CreateMarker = {
    Data = {
        Name = "Reward_CreateMarker",
        Type = Callbacks.CreateMarker
    },
};

function b_Reward_CreateMarker:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.MarkerType = MarkerTypes[_Parameter];
    elseif _Index == 2 then
        self.Data.Position = _Parameter;
    end
end

function b_Reward_CreateMarker:GetRewardTable()
    return {self.Data.Type, self.Data.MarkerType, GetPosition(self.Data.Position)};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateMarker);

-- -------------------------------------------------------------------------- --

---
-- Removes a minimap marker or pulsar at the position.
-- @param _Position [string] Position of marker
-- @within Rewards
--
function Reward_DestroyMarker(...)
    return b_Reward_DestroyMarker:New(unpack(arg));
end

b_Reward_DestroyMarker = {
    Data = {
        Name = "Reward_DestroyMarker",
        Type = Callbacks.DestroyMarker
    },
};

function b_Reward_DestroyMarker:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Position = _Parameter;
    end
end

function b_Reward_DestroyMarker:GetRewardTable()
    return {self.Data.Type, GetPosition(self.Data.Position)};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_DestroyMarker);

-- -------------------------------------------------------------------------- --

---
-- Explores an area around a script entity.
-- @param _AreaCenter [string] Center of exploration
-- @param _Exploration [number] Size of exploration
-- @within Rewards
--
function Reward_RevealArea(...)
    return b_Reward_RevealArea:New(unpack(arg));
end

b_Reward_RevealArea = {
    Data = {
        Name = "Reward_RevealArea",
        Type = Callbacks.RevealArea
    },
};

function b_Reward_RevealArea:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.AreaCenter = _Parameter;
    elseif _Index == 2 then
        self.Data.Explore = _Parameter;
    end
end

function b_Reward_RevealArea:GetRewardTable()
    return {self.Data.Type, self.Data.AreaCenter, self.Data.Explore};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_RevealArea);

-- -------------------------------------------------------------------------- --

---
-- Moves an entity to the destination and replace it with an XD_ScriptEntity
-- once it enters the fog.
-- @param _Entity [string] Entity to move
-- @param _Target [string] Move destination
-- @within Rewards
--
function Reward_MoveAndVanish(...)
    return b_Reward_MoveAndVanish:New(unpack(arg));
end

b_Reward_MoveAndVanish = {
    Data = {
        Name = "Reward_MoveAndVanish",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_MoveAndVanish:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Target = _Parameter;
    end
end

function b_Reward_MoveAndVanish:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_MoveAndVanish:CustomFunction(_Quest)
    Move(self.Data.Entity, self.Data.Target);

    self.Data.JobID = Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_SECOND,
        "",
        "QuestSystemBehavior_MoveAndReplaceController",
        1,
        {},
        {GetID(self.Data.Entity), self.m_Receiver}
    )
end

function b_Reward_MoveAndVanish:Debug(_Quest)
    if not IsExisting(self.Data.Entity) then
        dbg(_Quest, self, "Entity does not exist: " ..self.Data.Entity);
        return true;
    end
    if not IsExisting(self.Data.Target) then
        dbg(_Quest, self, "Destionation does not exist: " ..self.Data.Target);
        return true;
    end
    return false;
end

function b_Reward_MoveAndVanish:Reset(_Quest)
    if self.Data.JobID and JobIsRunning(self.Data.JobID) then
        EndJob(self.Data.JobID);
    end
    self.Data.JobID = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Reward_MoveAndVanish);

-- Move and replace helper
function QuestSystemBehavior_MoveAndReplaceController(_EntityID, _LookingPlayerID)
    if not IsExisting(_EntityID) then
        return true;
    end

    local PlayerID = Logic.EntityGetPlayer(_EntityID);
    local ScriptName = Logic.GetEntityName(_EntityID);
    local x, y, z = Logic.EntityGetPos(_EntityID);
    if Tools.IsEntityOrGroupVisible(_LookingPlayerID, _EntityID) == 0 then
        if Logic.IsLeader(_EntityID) == 1 then
            Logic.DestroyGroupByLeader(_EntityID)
        else
            Logic.DestroyEntity(_EntityID)
        end
        local ID = Logic.CreateEntity(Entities.XD_ScriptEntity, x, y, 0, PlayerID);
        Logic.SetEntityName(ID, ScriptName);
        return true;
    end
end

-- -------------------------------------------------------------------------- --

---
-- Calls a user function as condition.
-- @param _FunctionName [string] function to call
-- @within Triggers
--
function Trigger_MapScriptFunction(...)
    return b_Trigger_MapScriptFunction:New(unpack(arg));
end

b_Trigger_MapScriptFunction = {
    Data = {
        Name = "Trigger_MapScriptFunction",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_MapScriptFunction:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Trigger_MapScriptFunction:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_MapScriptFunction:CustomFunction(_Quest)
    return _G[self.Data.CustomFunction](self, _Quest);
end

function b_Trigger_MapScriptFunction:Debug(_Quest)
    if type(self.Data.CustomFunction) ~= "string" or _G[self.Data.CustomFunction] == nil then
        dbg(_Quest, self, "Function ist invalid:" ..tostring(self.Data.CustomFunction));
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_MapScriptFunction);

-- -------------------------------------------------------------------------- --

---
-- Does never trigger the quest.
-- @param _FunctionName [string] function to call
-- @within Triggers
--
function Trigger_NeverTriggered(...)
    return b_Trigger_NeverTriggered:New(unpack(arg));
end

b_Trigger_NeverTriggered = {
    Data = {
        Name = "Trigger_NeverTriggered",
        Type = Conditions.NeverTriggered
    },
};

function b_Trigger_NeverTriggered:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.CustomFunction = _Parameter;
    end
end

function b_Trigger_NeverTriggered:GetTriggerTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_NeverTriggered);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest x seconds after the game has started.
-- @param _Time [number] Time to wait
-- @within Triggers
--
function Trigger_Time(...)
    return b_Trigger_Time:New(unpack(arg));
end

b_Trigger_Time = {
    Data = {
        Name = "Trigger_Time",
        Type = Conditions.Time
    },
};

function b_Trigger_Time:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Time = _Parameter;
    end
end

function b_Trigger_Time:GetTriggerTable()
    return {self.Data.Type, self.Data.Time};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_Time);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when diplomacy between quest receiver and target player
-- reaches the state.
-- @param _PlayerID [number] Target player id
-- @param _DiplomacyState [string] Diplomacy state
-- @within Triggers
--
function Trigger_Diplomacy(...)
    return b_Trigger_Diplomacy:New(unpack(arg));
end

b_Trigger_Diplomacy = {
    Data = {
        Name = "Trigger_Diplomacy",
        Type = Conditions.Diplomacy
    },
};

function b_Trigger_Diplomacy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.DiplomacyState = Diplomacy[_Parameter];
    end
end

function b_Trigger_Diplomacy:GetTriggerTable()
    return {self.Data.Type, self.Data.PlayerID, self.Data.DiplomacyState};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_Diplomacy);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when the briefing linked to the quest is finished.
-- @param _QuestName [string] Linked quest
-- @within Triggers
--
function Trigger_Briefing(...)
    return b_Trigger_Briefing:New(unpack(arg));
end

b_Trigger_Briefing = {
    Data = {
        Name = "Trigger_Briefing",
        Type = Conditions.Briefing
    },
};

function b_Trigger_Briefing:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Briefing = _Parameter;
    end
end

function b_Trigger_Briefing:GetTriggerTable()
    return {self.Data.Type, self.Data.Briefing};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_Briefing);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest on the next payday of the quest receiver.
-- @within Triggers
--
function Trigger_Payday(...)
    return b_Trigger_Payday:New(unpack(arg));
end

b_Trigger_Payday = {
    Data = {
        Name = "Trigger_Payday",
        Type = Conditions.Payday
    },
};

function b_Trigger_Payday:AddParameter(_Index, _Parameter)
end

function b_Trigger_Payday:GetTriggerTable()
    return {self.Data.Type};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_Payday);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest after an entity has been destroyed. The quest is triggered
-- when the entity is destroyed either by script or by another player.
-- @param _ScriptName [string] Script name of entiry
-- @within Triggers
--
function Trigger_EntityDestroyed(...)
    return b_Trigger_EntityDestroyed:New(unpack(arg));
end

b_Trigger_EntityDestroyed = {
    Data = {
        Name = "Trigger_EntityDestroyed",
        Type = Conditions.EntityDestroyed
    },
};

function b_Trigger_EntityDestroyed:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ScriptName = _Parameter;
    end
end

function b_Trigger_EntityDestroyed:GetTriggerTable()
    return {self.Data.Type, self.Data.ScriptName};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_EntityDestroyed);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when a weather state is activated
-- @param _StateID [number] Weather state to activate
-- @within Triggers
--
function Trigger_WeatherState(...)
    return b_Trigger_WeatherState:New(unpack(arg));
end

b_Trigger_WeatherState = {
    Data = {
        Name = "Trigger_WeatherState",
        Type = Conditions.WeatherState
    },
};

function b_Trigger_WeatherState:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.StateID = _Parameter;
    end
end

function b_Trigger_WeatherState:GetTriggerTable()
    return {self.Data.Type, self.Data.StateID};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_WeatherState);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when two other quest are finished with the same result.
-- @param _QuestNameA [string] First quest
-- @param _QuestNameB [string] Second quest
-- @param _Result [number] Expected quest result
-- @within Triggers
--
function Trigger_QuestAndQuest(...)
    return b_Trigger_QuestAndQuest:New(unpack(arg));
end

b_Trigger_QuestAndQuest = {
    Data = {
        Name = "Trigger_QuestAndQuest",
        Type = Conditions.QuestAndQuest
    },
};

function b_Trigger_QuestAndQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestA = _Parameter;
    elseif _Index == 2 then
        self.Data.QuestB = _Parameter;
    elseif _Index == 3 then
        self.Data.Result = _Parameter;
    end
end

function b_Trigger_QuestAndQuest:GetTriggerTable()
    return {self.Data.Type, self.Data.QuestA, self.Data.QuestB, self.Data.Result};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestAndQuest);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when one or both quest finished with the expected result.
-- @param _QuestNameA [string] First quest
-- @param _QuestNameB [string] Second quest
-- @param _Result [number] Expected quest result
-- @within Triggers
--
function Trigger_QuestOrQuest(...)
    return b_Trigger_QuestOrQuest:New(unpack(arg));
end

b_Trigger_QuestOrQuest = {
    Data = {
        Name = "Trigger_QuestOrQuest",
        Type = Conditions.QuestOrQuest
    },
};

function b_Trigger_QuestOrQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestA = _Parameter;
    elseif _Index == 2 then
        self.Data.QuestB = _Parameter;
    elseif _Index == 3 then
        self.Data.Result = _Parameter;
    end
end

function b_Trigger_QuestOrQuest:GetTriggerTable()
    return {self.Data.Type, self.Data.QuestA, self.Data.QuestB, self.Data.Result};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestOrQuest);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when one quest but not the other finished with the expected
-- result.
-- @param _QuestNameA [string] First quest
-- @param _QuestNameB [string] Second quest
-- @param _Result [number] Expected quest result
-- @within Triggers
--
function Trigger_QuestXorQuest(...)
    return b_Trigger_QuestXorQuest:New(unpack(arg));
end

b_Trigger_QuestXorQuest = {
    Data = {
        Name = "Trigger_QuestXorQuest",
        Type = Conditions.QuestXorQuest
    },
};

function b_Trigger_QuestXorQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestA = _Parameter;
    elseif _Index == 2 then
        self.Data.QuestB = _Parameter;
    elseif _Index == 3 then
        self.Data.Result = _Parameter;
    end
end

function b_Trigger_QuestXorQuest:GetTriggerTable()
    return {self.Data.Type, self.Data.QuestA, self.Data.QuestB, self.Data.Result};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestXorQuest);

-- -------------------------------------------------------------------------- --
-- Custom Behavior                                                            --
-- -------------------------------------------------------------------------- --

---
-- The player must win a quest. If the quest fails this behavior will fail.
-- @param _QuestName [string] Quest name
-- @within Goals
--
function Goal_WinQuest(...)
    return b_Goal_WinQuest:New(unpack(arg));
end

b_Goal_WinQuest = {
    Data = {
        Name = "Goal_WinQuest",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_WinQuest:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Goal_WinQuest:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_WinQuest:CustomFunction(_Quest)
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestID == 0 then
        return false;
    end
    if QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
        if QuestSystem.Quests[QuestID].m_Result == QuestResults.Success then
            return true;
        elseif QuestSystem.Quests[QuestID].m_Result == QuestResults.Failure then
            return false;
        end
    end
end

function b_Goal_WinQuest:Debug(_Quest)
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestID == 0 then
        dbg(_Quest, self, "Quest '" ..self.Data.QuestName.. "' does not exist!");
        return true;
    end
    return false;
end

function b_Goal_WinQuest:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Goal_WinQuest);

-- -------------------------------------------------------------------------- --

---
-- This goal succeeds if the headquarter entity of the player is destroyed.
-- In addition, all buildings and settlers of this player get killed.
-- @param _PlayerID [number] id of player
-- @within Goals
--
function Goal_DestroyPlayer(...)
    return b_Goal_DestroyPlayer:New(unpack(arg));
end

b_Goal_DestroyPlayer = {
    Data = {
        Name = "Goal_DestroyPlayer",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_DestroyPlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.Headquarter = _Parameter;
    end
end

function b_Goal_DestroyPlayer:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_DestroyPlayer:CustomFunction(_Quest)
    if not IsExisting(self.Data.Headquarter) then
        local PlayerEntities = GetPlayerEntities(self.Data.PlayerID, 0);
        for i= 1, table.getn(PlayerEntities), 1 do 
            if Logic.IsSettler(PlayerEntities[i]) == 1 or Logic.IsBuilding(PlayerEntities[i]) == 1 then
                if Logic.GetEntityHealth(PlayerEntities[i]) > 0 then
                    Logic.HurtEntity(PlayerEntities[i], Logic.GetEntityHealth(PlayerEntities[i]));
                end
            end
        end
        return true;
    end
end

function b_Goal_DestroyPlayer:Debug(_Quest)
    if not IsExisting(self.Data.Headquarter) then
        dbg(_Quest, self, "Headquarter of player " ..self.Data.PlayerID.. " is already destroyed!");
        return true;
    end
    return false;
end

function b_Goal_DestroyPlayer:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Goal_DestroyPlayer);

-- -------------------------------------------------------------------------- --

---
-- Restarts the quest and force it to be active immedaitly.
-- @param _QuestName [string] Quest name
-- @within Reprisals
--
function Reprisal_QuestRestartForceActive(...)
    return b_Reprisal_QuestRestartForceActive:New(unpack(arg));
end

b_Reprisal_QuestRestartForceActive = {
    Data = {
        Name = "Reprisal_QuestRestartForceActive",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_QuestRestartForceActive:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestRestartForceActive:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_QuestRestartForceActive:CustomFunction(_Quest)
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestID == 0 then
        return;
    end
    if QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
        QuestSystem.Quests[QuestID].m_State = QuestStates.Inactive;
        QuestSystem.Quests[QuestID].m_Result = QuestResults.Undecided;
        QuestSystem.Quests[QuestID]:Reset();
        Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestSystem.QuestLoop, 1, {}, {QuestSystem.Quests[QuestID].m_QuestID});
        QuestSystem.Quests[QuestID]:Trigger();
    end
end

function b_Reprisal_QuestRestartForceActive:Debug(_Quest)
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestID == 0 then
        dbg(_Quest, self, "Quest '" ..self.Data.QuestName.. "' does not exist!");
        return true;
    end
    return false;
end

function b_Reprisal_QuestRestartForceActive:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestRestart);

-- -------------------------------------------------------------------------- --

---
-- Changes the vulnerablty of a settler or building.
-- @param _ScriptName [string] Entity to affect
-- @param _Flag [boolean] State of vulnerablty
-- @within Reprisals
--
function Reprisal_SetVulnerablity(...)
    return b_Reprisal_SetVulnerablity:New(unpack(arg));
end

b_Reprisal_SetVulnerablity = {
    Data = {
        Name = "Reprisal_SetVulnerablity",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_SetVulnerablity:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Entity = _Parameter;
    elseif _Index == 2 then
        self.Data.Flag = _Parameter;
    end
end

function b_Reprisal_SetVulnerablity:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_SetVulnerablity:CustomFunction(_Quest)
    if not IsExisting(self.Data.Entity) then
        return;
    end
    if self.Data.Flag then
        MakeVulnerable(GetID(self.Data.Entity));
    else
        MakeInvulnerable(GetID(self.Data.Entity));
    end
end

function b_Reprisal_SetVulnerablity:Debug(_Quest)
    local EntityID = GetID(self.Data.Entity);
    if not IsExisting(EntityID) then
        dbg(_Quest, self, "Target entity is destroyed!");
        return true;
    end
    if Logic.IsSettler(EntityID) == 0 and Logic.IsBuilding(EntityID) == 0 then
        dbg(_Quest, self, "Only settlers and buildings allowed!");
        return true;
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_SetVulnerablity);

-- -------------------------------------------------------------------------- --

---
-- Changes the vulnerablty of a settler or building.
-- @param _ScriptName [string] Entity to affect
-- @param _Flag [boolean] State of vulnerablty
-- @within Rewards
--
function Reward_SetVulnerablity(...)
    return b_Reward_SetVulnerablity:New(unpack(arg));
end

b_Reward_SetVulnerablity = copy(b_Reprisal_SetVulnerablity);
b_Reward_SetVulnerablity.Data.Name = "Reward_SetVulnerablity";
b_Reward_SetVulnerablity.Data.Type = Callbacks.MapScriptFunction;
b_Reward_SetVulnerablity.GetReprisalTable = nil;

function b_Reward_SetVulnerablity:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_SetVulnerablity);

-- -------------------------------------------------------------------------- --

---
-- Restarts the quest and force it to be active immedaitly.
-- @param _QuestName [string] Quest name
-- @within Rewards
--
function Reward_QuestRestartForceActive(...)
    return b_Reward_QuestRestartForceActive:New(unpack(arg));
end

b_Reward_QuestRestartForceActive = copy(b_Reprisal_QuestRestartForceActive);
b_Reward_QuestRestartForceActive.Data.Name = "Reward_QuestRestartForceActive";
b_Reward_QuestRestartForceActive.Data.Type = Callbacks.QuestRestartForceActive;
b_Reward_QuestRestartForceActive.GetReprisalTable = nil;

function b_Reward_QuestRestartForceActive:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestRestartForceActive);

-- -------------------------------------------------------------------------- --

---
-- Creates an merchant with up to 4 offers. Each offer purchases a fixed
-- amount of a resource for 1000 units of gold. Default inflation will be used.
-- @param _Merchant [string] Merchant name
-- @param _Offer1 [string] Resourcetype on sale
-- @param _Amount1 [number] Quantity to post
-- @param _Offer2 [string] Resourcetype on sale
-- @param _Amount2 [number] Quantity to post
-- @param _Offer3 [string] Resourcetype on sale
-- @param _Amount3 [number] Quantity to post
-- @param _Offer4 [string] Resourcetype on sale
-- @param _Amount4 [number] Quantity to post
-- @within Rewards
--
function Reward_OpenResourceSale(...)
    return b_Reward_OpenResourceSale:New(unpack(arg));
end

b_Reward_OpenResourceSale = {
    Data = {
        Name = "Reward_OpenResourceSale",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_OpenResourceSale:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    elseif _Index == 2 then
        self.Data.OfferType1 = _Parameter;
    elseif _Index == 3 then
        self.Data.OfferAmount1 = _Parameter;
    elseif _Index == 4 then
        self.Data.OfferType2 = _Parameter;
    elseif _Index == 5 then
        self.Data.OfferAmount2 = _Parameter;
    elseif _Index == 6 then
        self.Data.OfferType3 = _Parameter;
    elseif _Index == 7 then
        self.Data.OfferAmount3 = _Parameter;
    elseif _Index == 8 then
        self.Data.OfferType4 = _Parameter;
    elseif _Index == 9 then
        self.Data.OfferAmount4 = _Parameter;
    end
end

function b_Reward_OpenResourceSale:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_OpenResourceSale:CustomFunction(_Quest)
    local ResourceGoldRatio   = {
        ["Clay"]   = 1250,
        ["Wood"]   = 1400,
        ["Stone"]  = 1150,
        ["Iron"]   = 1100,
        ["Sulfur"] = 850,
    };

    if Interaction.IO[self.Data.Merchant] then
        Interaction.IO[self.Data.Merchant]:Deactivate();
    end

    local NPC = new(NonPlayerMerchant, self.Data.Merchant);
    if self.Data.OfferType1 then
        NPC:AddResourceOffer(ResourceType.Gold, 1000, {[self.Data.OfferType1] = ResourceGoldRatio[self.Data.OfferType1] or 1000}, self.Data.OfferAmount1, 3*60);
    end
    if self.Data.OfferType2 then
        NPC:AddResourceOffer(ResourceType.Gold, 1000, {[self.Data.OfferType2] = ResourceGoldRatio[self.Data.OfferType2] or 1000}, self.Data.OfferAmount2, 3*60);
    end
    if self.Data.OfferType3 then
        NPC:AddResourceOffer(ResourceType.Gold, 1000, {[self.Data.OfferType3] = ResourceGoldRatio[self.Data.OfferType3] or 1000}, self.Data.OfferAmount3, 3*60);
    end
    if self.Data.OfferType4 then
        NPC:AddResourceOffer(ResourceType.Gold, 1000, {[self.Data.OfferType4] = ResourceGoldRatio[self.Data.OfferType4] or 1000}, self.Data.OfferAmount4, 3*60);
    end
    NPC:Activate();
end

function b_Reward_OpenResourceSale:Debug(_Quest)
    for i = 1, 4, 1 do
        if self.Data["OfferType" ..i] and self.Data["OfferType" ..i] == ResourceType.Gold then
            dbg(_Quest, self, "Selling gold is not allowed!");
            return true;
        end
    end
    return false;
end

function b_Reward_OpenResourceSale:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_OpenResourceSale);

-- -------------------------------------------------------------------------- --

---
-- Creates an merchant with up to 4 offers. Each offer sells 1000 units of a
-- resource for a fixed amount of gold. Default inflation will be used.
-- @param _Merchant [string] Merchant name
-- @param _Offer1 [string] Resourcetype on sale
-- @param _Amount1 [number] Quantity to post
-- @param _Offer2 [string] Resourcetype on sale
-- @param _Amount2 [number] Quantity to post
-- @param _Offer3 [string] Resourcetype on sale
-- @param _Amount3 [number] Quantity to post
-- @param _Offer4 [string] Resourcetype on sale
-- @param _Amount4 [number] Quantity to post
-- @within Rewards
--
function Reward_OpenResourcePurchase(...)
    return b_Reward_OpenResourcePurchase:New(unpack(arg));
end

b_Reward_OpenResourcePurchase = {
    Data = {
        Name = "Reward_OpenResourcePurchase",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_OpenResourcePurchase:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    elseif _Index == 2 then
        self.Data.OfferType1 = ResourceType[_Parameter];
    elseif _Index == 3 then
        self.Data.OfferAmount1 = _Parameter;
    elseif _Index == 4 then
        self.Data.OfferType2 = ResourceType[_Parameter];
    elseif _Index == 5 then
        self.Data.OfferAmount2 = _Parameter;
    elseif _Index == 6 then
        self.Data.OfferType3 = ResourceType[_Parameter];
    elseif _Index == 7 then
        self.Data.OfferAmount3 = _Parameter;
    elseif _Index == 8 then
        self.Data.OfferType4 = ResourceType[_Parameter];
    elseif _Index == 9 then
        self.Data.OfferAmount4 = _Parameter;
    end
end

function b_Reward_OpenResourcePurchase:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_OpenResourcePurchase:CustomFunction(_Quest)
    local ResourceGoldRatio   = {
        [ResourceType.Clay]   = 750,
        [ResourceType.Wood]   = 600,
        [ResourceType.Stone]  = 850,
        [ResourceType.Iron]   = 900,
        [ResourceType.Sulfur] = 1150,
    };

    if Interaction.IO[self.Data.Merchant] then
        Interaction.IO[self.Data.Merchant]:Deactivate();
    end

    local NPC = new(NonPlayerMerchant, self.Data.Merchant);
    if self.Data.OfferType1 then
        NPC:AddResourceOffer(self.Data.OfferType1, 1000, {Gold = ResourceGoldRatio[self.Data.OfferType1] or 1000}, self.Data.OfferAmount1, 3*60);
    end
    if self.Data.OfferType2 then
        NPC:AddResourceOffer(self.Data.OfferType2, 1000, {Gold = ResourceGoldRatio[self.Data.OfferType2] or 1000}, self.Data.OfferAmount2, 3*60);
    end
    if self.Data.OfferType3 then
        NPC:AddResourceOffer(self.Data.OfferType3, 1000, {Gold = ResourceGoldRatio[self.Data.OfferType3] or 1000}, self.Data.OfferAmount3, 3*60);
    end
    if self.Data.OfferType4 then
        NPC:AddResourceOffer(self.Data.OfferType4, 1000, {Gold = ResourceGoldRatio[self.Data.OfferType4] or 1000}, self.Data.OfferAmount4, 3*60);
    end
    NPC:Activate();
end

function b_Reward_OpenResourcePurchase:Debug(_Quest)
    for i = 1, 4, 1 do
        if self.Data["OfferType" ..i] and self.Data["OfferType" ..i] == ResourceType.Gold then
            dbg(_Quest, self, "Purchasing gold is not allowed!");
            return true;
        end
    end
    return false;
end

function b_Reward_OpenResourcePurchase:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_OpenResourcePurchase);

-- -------------------------------------------------------------------------- --

---
-- Creates an mercenary merchant with up to 4 offers.
-- Default inflation will be used.
-- @param _Merchant [string] Merchant name
-- @param _Offer1 [string] Resourcetype on sale
-- @param _Cost1 [number] Gold costs
-- @param _Amount1 [number] Quantity to post
-- @param _Offer2 [string] Resourcetype on sale
-- @param _Cost2 [number] Gold costs
-- @param _Amount2 [number] Quantity to post
-- @param _Offer3 [string] Resourcetype on sale
-- @param _Cost3 [number] Gold costs
-- @param _Amount3 [number] Quantity to post
-- @param _Offer4 [string] Resourcetype on sale
-- @param _Cost4 [number] Gold costs
-- @param _Amount4 [number] Quantity to post
-- @within Rewards
--
function Reward_OpenMercenaryMerchant(...)
    return b_Reward_OpenMercenaryMerchant:New(unpack(arg));
end

b_Reward_OpenMercenaryMerchant = {
    Data = {
        Name = "Reward_OpenMercenaryMerchant",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_OpenMercenaryMerchant:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    elseif _Index == 2 then
        self.Data.OfferType1 = Entities[_Parameter];
    elseif _Index == 3 then
        self.Data.OfferCost1 = _Parameter;
    elseif _Index == 4 then
        self.Data.OfferAmount1 = _Parameter;
    elseif _Index == 5 then
        self.Data.OfferType2 = Entities[_Parameter];
    elseif _Index == 6 then
        self.Data.OfferCost2 = _Parameter;
    elseif _Index == 7 then
        self.Data.OfferAmount2 = _Parameter;
    elseif _Index == 8 then
        self.Data.OfferType3 = Entities[_Parameter];
    elseif _Index == 9 then
        self.Data.OfferCost3 = _Parameter;
    elseif _Index == 10 then
        self.Data.OfferAmount3 = _Parameter;
    elseif _Index == 11 then
        self.Data.OfferType4 = Entities[_Parameter];
    elseif _Index == 12 then
        self.Data.OfferCost4 = _Parameter;
    elseif _Index == 13 then
        self.Data.OfferAmount4 = _Parameter;
    end
end

function b_Reward_OpenMercenaryMerchant:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_OpenMercenaryMerchant:CustomFunction(_Quest)
    if Interaction.IO[self.Data.Merchant] then
        Interaction.IO[self.Data.Merchant]:Deactivate();
    end

    local NPC = new(NonPlayerMerchant, self.Data.Merchant);
    if self.Data.OfferType1 then
        NPC:AddTroopOffer(self.Data.OfferType1, {Gold = self.Data.OfferCost1}, self.Data.OfferAmount1, 3*60);
    end
    if self.Data.OfferType2 then
        NPC:AddTroopOffer(self.Data.OfferType2, {Gold = self.Data.OfferCost2}, self.Data.OfferAmount2, 3*60);
    end
    if self.Data.OfferType3 then
        NPC:AddTroopOffer(self.Data.OfferType3, {Gold = self.Data.OfferCost3}, self.Data.OfferAmount3, 3*60);
    end
    if self.Data.OfferType4 then
        NPC:AddTroopOffer(self.Data.OfferType4, {Gold = self.Data.OfferCost4}, self.Data.OfferAmount4, 3*60);
    end
    NPC:Activate();
end

function b_Reward_OpenMercenaryMerchant:Debug(_Quest)
    for i = 1, 4, 1 do
        if self.Data["OfferType" ..i] and (not self.Data["OfferCost" ..i] or not self.Data["OfferAmount" ..i]) then
            dbg(_Quest, self, "Offer " ..i.. " is not correctly configured!");
            return true;
        end
    end
    return false;
end

QuestSystemBehavior:RegisterBehavior(b_Reward_OpenMercenaryMerchant);

-- -------------------------------------------------------------------------- --

---
-- Deactivates any kind of merchant.
-- @param _Merchant [string] Merchant name
-- @within Rewards
--
function Reward_CloseMerchant(...)
    return b_Reward_CloseMerchant:New(unpack(arg));
end

b_Reward_CloseMerchant = {
    Data = {
        Name = "Reward_CloseMerchant",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_CloseMerchant:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Merchant = _Parameter;
    end
end

function b_Reward_CloseMerchant:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_CloseMerchant:CustomFunction(_Quest)
    if Interaction.IO[self.Data.Merchant] then
        Interaction.IO[self.Data.Merchant]:Deactivate();
    end
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CloseMerchant);

-- -------------------------------------------------------------------------- --

---
-- Creates an AI player but don't creates any armies.
--
-- Initalising the AI is nessessary for usung the quest system behavior army
-- controller.
--
-- @param _PlayerID [number] Id of player
-- @param _TechLevel [number] Tech level
-- @within Rewards
--
function Reward_AI_CreateAIPlayer(...)
    return b_Reward_AI_CreateAIPlayer:New(unpack(arg));
end

b_Reward_AI_CreateAIPlayer = {
    Data = {
        Name = "Reward_AI_CreateAIPlayer",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_CreateAIPlayer:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.TechLevel = _Parameter;
    end
end

function b_Reward_AI_CreateAIPlayer:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_CreateAIPlayer:CustomFunction(_Quest)
    QuestSystemBehavior:CreateAI(self.Data.PlayerID, self.Data.TechLevel);
end

function b_Reward_AI_CreateAIPlayer:Debug(_Quest)
    return false;
end

function b_Reward_AI_CreateAIPlayer:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_CreateAIPlayer);

-- -------------------------------------------------------------------------- --

---
-- Defines an army that must be recruited by the AI.
--
-- Use script entities named with PlayerX_AttackTargetY to define positions
-- that will be attacked by the army. Also you can use entities named with
-- PlayerX_PatrolPointY to define positions were the army will patrol.
--
-- @param _ArmyName [string] Army identifier
-- @param _PlayerID [number] Id of player
-- @param _Strength [number] Strength of army
-- @param _Position [string] Army base position
-- @param _RodeLength [number] Average action range
-- @param _TroopType [number] Army troop type
-- @within Rewards
--
function Reward_AI_CreateArmy(...)
    return b_Reward_AI_CreateArmy:New(unpack(arg));
end

b_Reward_AI_CreateArmy = {
    Data = {
        Name = "Reward_AI_CreateArmy",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_CreateArmy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ArmyName = _Parameter;
    elseif _Index == 2 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 3 then
        self.Data.Strength = _Parameter;
    elseif _Index == 4 then
        self.Data.Position = _Parameter;
    elseif _Index == 5 then
        self.Data.RodeLength = _Parameter;
    elseif _Index == 6 then
        _Parameter = _Parameter or "City";
        self.Data.TroopType = QuestSystemBehavior.ArmyCategories[_Parameter];
    end
end

function b_Reward_AI_CreateArmy:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_CreateArmy:CustomFunction(_Quest)
    local ID = QuestSystemBehavior:CreateAIArmy(self.Data.PlayerID, self.Data.Strength, self.Data.Position, self.Data.RodeLength, self.Data.TroopType);
    if ID then
        QuestSystemBehavior.Data.AiArmyNameToId[self.Data.ArmyName] = ID;
    end
end

function b_Reward_AI_CreateArmy:Debug(_Quest)
    if self.Data.ArmyName == "" or self.Data.ArmyName == nil then
        dbg(_Quest, self, "An army got an invalid identifier!");
        return true;
    end
    if QuestSystemBehavior.Data.AiArmyNameToId[self.Data.ArmyName] then
        dbg(_Quest, self, "Army '" ..self.Data.ArmyName.. "' is already created!");
        return true;
    end
    if  QuestSystemBehavior.Data.CreatedAiArmies[self.Data.PlayerID] 
    and table.getn(QuestSystemBehavior.Data.CreatedAiArmies[self.Data.PlayerID]) > 9 then
        dbg(_Quest, self, "Player '" ..self.Data.PlayerID.. "' has to many armies!");
        return true;
    end
    return false;
end

function b_Reward_AI_CreateArmy:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_CreateArmy);

-- -------------------------------------------------------------------------- --

---
-- Defines an army of up to 6 different unit types that is spawned from a
-- generator entiry.
--
-- Use script entities named with PlayerX_AttackTargetY to define positions
-- that will be attacked by the army. Also you can use entities named with
-- PlayerX_PatrolPointY to define positions were the army will patrol.
--
-- @param _ArmyName [string] Army identifier
-- @param _PlayerID [number] Id of player
-- @param _LifeThread [string] Name of generator
-- @param _Strength [number] Strength of army
-- @param _Position [string] Army base position
-- @param _RodeLength [number] Average action range
-- @param _RespawnTime [number] Time till reinforcements spawned
-- @param _TroopType1 [string] Troop type 1
-- @param _TroopType2 [string] Troop type 2
-- @param _TroopType3 [string] Troop type 3
-- @param _TroopType4 [string] Troop type 4
-- @param _TroopType5 [string] Troop type 5
-- @param _TroopType6 [string] Troop type 6
-- @within Rewards
--
function Reward_AI_CreateSpawnArmy(...)
    return b_Reward_AI_CreateSpawnArmy:New(unpack(arg));
end

b_Reward_AI_CreateSpawnArmy = {
    Data = {
        Name = "Reward_AI_CreateSpawnArmy",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_CreateSpawnArmy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.ArmyName = _Parameter;
    elseif _Index == 2 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 3 then
        self.Data.LifeThread = _Parameter;
    elseif _Index == 4 then
        self.Data.Strength = _Parameter;
    elseif _Index == 5 then
        self.Data.Position = _Parameter;
    elseif _Index == 6 then
        self.Data.RodeLength = _Parameter;
    elseif _Index == 7 then
        self.Data.RespawnTime = _Parameter;
    elseif _Index == 8 then
        self.Data.TroopType1 = _Parameter;
    elseif _Index == 9 then
        self.Data.TroopType2 = _Parameter;
    elseif _Index == 10 then
        self.Data.TroopType3 = _Parameter;
    elseif _Index == 11 then
        self.Data.TroopType4 = _Parameter;
    elseif _Index == 12 then
        self.Data.TroopType5 = _Parameter;
    elseif _Index == 13 then
        self.Data.TroopType6 = _Parameter;
    end
end

function b_Reward_AI_CreateSpawnArmy:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_CreateSpawnArmy:CustomFunction(_Quest)
    -- Get types
    local TroopTypes = {};
    for i= 1, 6, 1 do
        if self.Data["TroopType" ..i] and Entities[self.Data["TroopType" ..i]] then
            table.insert(TroopTypes, Entities[self.Data["TroopType" ..i]]);
        end
    end
    -- Create army
    CreateAIPlayerSpawnArmy(
        self.Data.ArmyName, 
        self.Data.PlayerID, 
        self.Data.Strength, 
        self.Data.Position, 
        self.Data.LifeThread, 
        self.Data.RodeLength, 
        self.Data.RespawnTime, 
        unpack(TroopTypes)
    );
end

function b_Reward_AI_CreateSpawnArmy:Debug(_Quest)
    if self.Data.ArmyName == "" or self.Data.ArmyName == nil then
        dbg(_Quest, self, "An army got an invalid identifier!");
        return true;
    end
    if QuestSystemBehavior.Data.AiArmyNameToId[self.Data.ArmyName] then
        dbg(_Quest, self, "Army '" ..self.Data.ArmyName.. "' is already created!");
        return true;
    end
    if  QuestSystemBehavior.Data.CreatedAiArmies[self.Data.PlayerID]
    and table.getn(QuestSystemBehavior.Data.CreatedAiArmies[self.Data.PlayerID]) > 9 then
        dbg(_Quest, self, "Player '" ..self.Data.PlayerID.. "' has to many armies!");
        return true;
    end
    if not IsExisting(self.Data.LifeThread) then
        dbg(_Quest, self, "Army '" ..self.Data.ArmyName.. "' has no life thread!");
        return true;
    end
    
    local ValidMember = false;
    for i= 1, 6, 1 do
        if Entities[self.Data["TroopType" ..i]] ~= nil then
            ValidMember = true;
            break;
        end
    end
    if ValidMember == false then
        dbg(_Quest, self, "Army '" ..self.Data.ArmyName.. "' has no troop types assigned!");
        return true;
    end
    return false;
end

function b_Reward_AI_CreateSpawnArmy:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_CreateSpawnArmy);

-- -------------------------------------------------------------------------- --

---
-- Disables or enables the patrol behavior for armies.
--
-- @param _PlayerID [number] ID of player
-- @param _ArmyName [string] Army identifier
-- @param _Flag [boolean] Patrol disabled
-- @within Rewards
--
function Reward_AI_EnableArmyPatrol(...)
    return b_Reward_AI_EnableArmyPatrol:New(unpack(arg));
end

b_Reward_AI_EnableArmyPatrol = {
    Data = {
        Name = "Reward_AI_EnableArmyPatrol",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_EnableArmyPatrol:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.ArmyName = _Parameter;
    elseif _Index == 3 then
        self.Data.Flag = _Parameter;
    end
end

function b_Reward_AI_EnableArmyPatrol:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_EnableArmyPatrol:CustomFunction(_Quest)
    if QuestSystemBehavior.Data.AiArmyNameToId[self.Data.ArmyName] then
        local ID = QuestSystemBehavior.Data.AiArmyNameToId[self.Data.ArmyName];
        QuestSystemBehavior:ArmyDisablePatrolAbility(self.Data.PlayerID, ID, not self.Data.Flag);
    end
end

function b_Reward_AI_EnableArmyPatrol:Debug(_Quest)
    if not QuestSystemBehavior.Data.AiArmyNameToId[self.Data.ArmyName] then
        dbg(_Quest, self, "Army '" ..self.Data.ArmyName.. "' does not exist!");
        return true;
    end
    return false;
end

function b_Reward_AI_EnableArmyPatrol:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_EnableArmyPatrol);

-- -------------------------------------------------------------------------- --

---
-- Disables or enables the attack behavior for armies.
--
-- @param _PlayerID [number] ID of player
-- @param _ArmyName [string] Army identifier
-- @param _Flag [boolean] Attack disabled
-- @within Rewards
--
function Reward_AI_EnableArmyAttack(...)
    return b_Reward_AI_EnableArmyAttack:New(unpack(arg));
end

b_Reward_AI_EnableArmyAttack = {
    Data = {
        Name = "Reward_AI_EnableArmyAttack",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_AI_EnableArmyAttack:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.ArmyName = _Parameter;
    elseif _Index == 3 then
        self.Data.Flag = _Parameter;
    end
end

function b_Reward_AI_EnableArmyAttack:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_AI_EnableArmyAttack:CustomFunction(_Quest)
    if QuestSystemBehavior.Data.AiArmyNameToId[self.Data.ArmyName] then
        local ID = QuestSystemBehavior.Data.AiArmyNameToId[self.Data.ArmyName];
        QuestSystemBehavior:ArmyDisableAttackAbility(self.Data.PlayerID, ID, not self.Data.Flag);
    end
end

function b_Reward_AI_EnableArmyAttack:Debug(_Quest)
    if not QuestSystemBehavior.Data.AiArmyNameToId[self.Data.ArmyName] then
        dbg(_Quest, self, "Army '" ..self.Data.ArmyName.. "' does not exist!");
        return true;
    end
    return false;
end

function b_Reward_AI_EnableArmyAttack:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_AI_EnableArmyAttack);

-- -------------------------------------------------------------------------- --

---
-- Changes the color of a player.
-- @param _PlayerID [number] ID of player
-- @param _Color [string|number] Color name or Color index
-- @within Rewards
--
function Reward_SetPlayerColor(...)
    return b_Reward_SetPlayerColor:New(unpack(arg));
end

b_Reward_SetPlayerColor = {
    Data = {
        Name = "Reward_SetPlayerColor",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_SetPlayerColor:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.Color = _Parameter;
    end
end

function b_Reward_SetPlayerColor:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_SetPlayerColor:CustomFunction(_Quest)
    QuestSystemBehavior.Data.PlayerColorAssigment[self.Data.PlayerID] = _G[self.Data.Color] or self.Data.Color;
    QuestSystemBehavior.UpdatePlayerColorAssigment();
end

function b_Reward_SetPlayerColor:Debug(_Quest)
    if self.Data.PlayerID < 1 or self.Data.PlayerID > 8 then
        dbg(_Quest, self, "PlayerID is wrong!");
        return true;
    end
    if type(self.Data.Color) ~= "number" and not _G[self.Data.Color] then
        dbg(_Quest, self, "Color does not exist!");
        return true;
    end
    return false;
end

function b_Reward_SetPlayerColor:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_SetPlayerColor);

-- -------------------------------------------------------------------------- --

---
-- Activates the debug mode.
-- @param _UseDebugQuests [boolean] Activates the runtime debug für quests
-- @param _UseCheats [boolean] Activates the cheats
-- @param _UseShell [boolean] Activates the shell
-- @param _UseQuestTrace [boolean] Activates the quest trace
-- @within Rewards
--
function Reward_DEBUG(...)
    return b_Reward_DEBUG:New(unpack(arg));
end

b_Reward_DEBUG = {
    Data = {
        Name = "Reward_DEBUG",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reward_DEBUG:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.UseDebugQuests = _Parameter;
    elseif _Index == 2 then
        self.Data.UseCheats = _Parameter;
    elseif _Index == 3 then
        self.Data.UseShell = _Parameter;
    elseif _Index == 4 then
        self.Data.UseQuestTrace = _Parameter;
    end
end

function b_Reward_DEBUG:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_DEBUG:CustomFunction(_Quest)
    if QuestSystemDebug then
        QuestSystemDebug:Activate(
            self.Data.UseDebugQuests,
            self.Data.UseCheats,
            self.Data.UseShell,
            self.Data.UseQuestTrace
        );
    end
end

function b_Reward_DEBUG:Debug(_Quest)
    return false;
end

function b_Reward_DEBUG:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_DEBUG);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest is successfully finished.
-- @param _QuestName [string] First quest
-- @param _Waittime [number] Time to wait
-- @within Triggers
--
function Trigger_QuestSuccess(...)
    return b_Trigger_QuestSuccess:New(unpack(arg));
end

b_Trigger_QuestSuccess = {
    Data = {
        Name = "Trigger_QuestSuccess",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestSuccess:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestSuccess:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestSuccess:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_Result == QuestResults.Success then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestSuccess:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..self.Data.QuestName);
    end
    return false;
end

function b_Trigger_QuestSuccess:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestSuccess);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest has failed.
-- @param _QuestName [string] First quest
-- @param _Waittime [number] Time to wait
-- @within Triggers
--
function Trigger_QuestFailure(...)
    return b_Trigger_QuestFailure:New(unpack(arg));
end

b_Trigger_QuestFailure = {
    Data = {
        Name = "Trigger_QuestFailure",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestFailure:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestFailure:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestFailure:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_Result == QuestResults.Failure then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestFailure:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..self.Data.QuestName);
    end
    return false;
end

function b_Trigger_QuestFailure:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestFailure);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest is over.
-- @param _QuestName [string] First quest
-- @param _Waittime [number] Time to wait
-- @within Triggers
--
function Trigger_QuestOver(...)
    return b_Trigger_QuestOver:New(unpack(arg));
end

b_Trigger_QuestOver = {
    Data = {
        Name = "Trigger_QuestOver",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestOver:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestOver:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestOver:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_State == QuestStates.Over then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestOver:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..self.Data.QuestName);
    end
    return false;
end

function b_Trigger_QuestOver:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestOver);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest is interrupted.
-- @param _QuestName [string] First quest
-- @param _Waittime [number] Time to wait
-- @within Triggers
--
function Trigger_QuestInterrupted(...)
    return b_Trigger_QuestInterrupted:New(unpack(arg));
end

b_Trigger_QuestInterrupted = {
    Data = {
        Name = "Trigger_QuestInterrupted",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestInterrupted:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestInterrupted:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestInterrupted:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_State == QuestStates.Over and QuestSystem.Quests[QuestID].m_Result == QuestStates.Interrupted then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestInterrupted:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..self.Data.QuestName);
    end
    return false;
end

function b_Trigger_QuestInterrupted:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestInterrupted);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest is active.
-- @param _QuestName [string] First quest
-- @param _Waittime [number] Time to wait
-- @within Triggers
--
function Trigger_QuestActive(...)
    return b_Trigger_QuestActive:New(unpack(arg));
end

b_Trigger_QuestActive = {
    Data = {
        Name = "Trigger_QuestActive",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestActive:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestActive:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestActive:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_State == QuestStates.Active then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestActive:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..self.Data.QuestName);
    end
    return false;
end

function b_Trigger_QuestActive:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestActive);

-- -------------------------------------------------------------------------- --

---
-- Starts the quest when another quest has not been triggered.
-- @param _QuestName [string] First quest
-- @param _Waittime [number] Time to wait
-- @within Triggers
--
function Trigger_QuestNotTriggered(...)
    return b_Trigger_QuestNotTriggered:New(unpack(arg));
end

b_Trigger_QuestNotTriggered = {
    Data = {
        Name = "Trigger_QuestNotTriggered",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_QuestNotTriggered:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    elseif _Index == 2 then
        self.Data.Waittime = _Parameter;
    end
end

function b_Trigger_QuestNotTriggered:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_QuestNotTriggered:CustomFunction(_Quest)
    self.Data.Waittime = self.Data.Waittime or 0;
    local QuestID = GetQuestID(self.Data.QuestName);
    if QuestSystem.Quests[QuestID] and QuestSystem.Quests[QuestID].m_State == QuestStates.Inactive then
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestNotTriggered:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..self.Data.QuestName);
    end
    return false;
end

function b_Trigger_QuestNotTriggered:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestNotTriggered);

-- -------------------------------------------------------------------------- --
-- Custom Variable Behavior                                                   --
-- -------------------------------------------------------------------------- --

---
-- Compares a numeric custom value with number or another custom value.
-- If the values match the condition then the goal is reached.
-- @param _Name [string] Variable identifier
-- @param _Comparison [string] Comparsion operator
-- @param _Value [number] Integer value
-- @within Goals
--
function Goal_CustomVariable(...)
    return b_Goal_CustomVariable:New(unpack(arg));
end

b_Goal_CustomVariable = {
    Data = {
        Name = "Goal_CustomVariable",
        Type = Objectives.MapScriptFunction
    },
};

function b_Goal_CustomVariable:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.VariableName = _Parameter;
    elseif _Index == 2 then
        self.Data.Operator = _Parameter;
    elseif _Index == 3 then
        self.Data.Value = _Parameter;
    end
end

function b_Goal_CustomVariable:GetGoalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Goal_CustomVariable:CustomFunction(_Quest)
    local CustomValue = QuestSystemBehavior.Data.CustomVariables[self.Data.Operator];
    local ComparsionValue = self.Data.Value;
    if type(ComparsionValue) == "string" then
        ComparsionValue = QuestSystemBehavior.Data.CustomVariables[self.Data.Value];
    end

    if CustomValue and ComparsionValue then
        if self.Data.Operator == "==" and CustomValue == ComparsionValue then
            return true;
        elseif self.Data.Operator == "~=" and CustomValue ~= ComparsionValue then
            return true;
        elseif self.Data.Operator == "<" and CustomValue < ComparsionValue then
            return true;
        elseif self.Data.Operator == "<=" and CustomValue <= ComparsionValue then
            return true;
        elseif self.Data.Operator == ">=" and CustomValue >= ComparsionValue then
            return true;
        elseif self.Data.Operator == ">" and CustomValue > ComparsionValue then
            return true;
        end
    end
end

function b_Goal_CustomVariable:Debug(_Quest)
    return false;
end

function b_Goal_CustomVariable:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Goal_CustomVariable);

-- -------------------------------------------------------------------------- --

---
-- Alters a numeric custom value by the given value or value of the given
-- custom variable using the mathematical operation.
-- @param _Name [string] Variable identifier
-- @param _Operator [string] Operator
-- @param _Value [number] Integer value
-- @within Triggers
--
function Reprisal_CustomVariable(...)
    return b_Reprisal_CustomVariable:New(unpack(arg));
end

b_Reprisal_CustomVariable = {
    Data = {
        Name = "Reprisal_CustomVariable",
        Type = Callbacks.MapScriptFunction
    },
};

function b_Reprisal_CustomVariable:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.VariableName = _Parameter;
    elseif _Index == 2 then
        self.Data.Operator = _Parameter;
    elseif _Index == 3 then
        self.Data.Value = _Parameter;
    end
end

function b_Reprisal_CustomVariable:GetReprisalTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reprisal_CustomVariable:CustomFunction(_Quest)
    local OldValue = QuestSystemBehavior.Data.CustomVariables[self.Data.Operator];
    local NewValue = self.Data.Value;
    if type(NewValue) == "string" then
        NewValue = QuestSystemBehavior.Data.CustomVariables[self.Data.Value];
    end

    if OldValue and NewValue then
        if self.Data.Operator == "=" then
            OldValue = NewValue;
        elseif self.Data.Operator == "+" then
            OldValue = OldValue + NewValue;
        elseif self.Data.Operator == "-" then
            OldValue = OldValue - NewValue;
        elseif self.Data.Operator == "*" then
            OldValue = OldValue * NewValue;
        elseif self.Data.Operator == "/" then
            OldValue = OldValue / NewValue;
        elseif self.Data.Operator == "%" then
            OldValue = math.mod(OldValue, NewValue);
        elseif self.Data.Operator == "^" then
            OldValue = OldValue ^ NewValue;
        end
        QuestSystemBehavior.Data.CustomVariables[self.Data.Operator] = OldValue;
    end
end

function b_Reprisal_CustomVariable:Debug(_Quest)
    return false;
end

function b_Reprisal_CustomVariable:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_CustomVariable);

-- -------------------------------------------------------------------------- --

---
-- Alters a numeric custom value by the given value or value of the given
-- custom variable using the mathematical operation.
-- @param _Name [string] Variable identifier
-- @param _Operator [string] Operator
-- @param _Value [number] Integer value
-- @within Triggers
--
function Reprisal_CustomVariable(...)
    return b_Reprisal_CustomVariable:New(unpack(arg));
end

b_Reprisal_CustomVariable = copy(b_Reprisal_CustomVariable);
b_Reprisal_CustomVariable.Data.Name = "Reprisal_CustomVariable";
b_Reprisal_CustomVariable.Data.Type = Callbacks.MapScriptFunction;
b_Reprisal_CustomVariable.GetReprisalTable = nil;

function b_Reprisal_CustomVariable:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_CustomVariable);

-- -------------------------------------------------------------------------- --

---
-- Compares a numeric custom value with number or another custom value.
-- If the values match the condition then the trigger returns true.
-- @param _Name [string] Variable identifier
-- @param _Comparison [string] Comparsion operator
-- @param _Value [number] Integer value
-- @within Triggers
--
function Trigger_CustomVariable(...)
    return b_Trigger_CustomVariable:New(unpack(arg));
end

b_Trigger_CustomVariable = {
    Data = {
        Name = "Trigger_CustomVariable",
        Type = Conditions.MapScriptFunction
    },
};

function b_Trigger_CustomVariable:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.VariableName = _Parameter;
    elseif _Index == 2 then
        self.Data.Operator = _Parameter;
    elseif _Index == 3 then
        self.Data.Value = _Parameter;
    end
end

function b_Trigger_CustomVariable:GetTriggerTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Trigger_CustomVariable:CustomFunction(_Quest)
    local CustomValue = QuestSystemBehavior.Data.CustomVariables[self.Data.Operator];
    local ComparsionValue = self.Data.Value;
    if type(ComparsionValue) == "string" then
        ComparsionValue = QuestSystemBehavior.Data.CustomVariables[self.Data.Value];
    end

    if CustomValue and ComparsionValue then
        if self.Data.Operator == "==" and CustomValue == ComparsionValue then
            return true;
        elseif self.Data.Operator == "~=" and CustomValue ~= ComparsionValue then
            return true;
        elseif self.Data.Operator == "<" and CustomValue < ComparsionValue then
            return true;
        elseif self.Data.Operator == "<=" and CustomValue <= ComparsionValue then
            return true;
        elseif self.Data.Operator == ">=" and CustomValue >= ComparsionValue then
            return true;
        elseif self.Data.Operator == ">" and CustomValue > ComparsionValue then
            return true;
        end
    end
    return false;
end

function b_Trigger_CustomVariable:Debug(_Quest)
    return false;
end

function b_Trigger_CustomVariable:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_CustomVariable);