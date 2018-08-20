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
-- @set sort=true
--

-- Quest --

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

-- Helper --

function dbg(_Quest, _Behavior, _Message)
    GUI.AddStaticNote(string.format("DEBUG: %s:%s: %s", _Quest.m_QuestName, _Behavior.Data.Name, tostring(_Message)));
end

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

-- Behavior --

QuestSystemBehavior = {
    Data = {
        RegisteredQuestBehaviors = {},
        SystemInitalized = false;
        Version = "ALPHA",

        CreatedAiPlayers = {},
        CreatedAiArmies = {},
        AllowedTypesDefault = {
            UpgradeCategories.LeaderBow,
			UpgradeCategories.LeaderSword,
			UpgradeCategories.LeaderPoleArm,
			UpgradeCategories.LeaderCavalry,
			UpgradeCategories.LeaderHeavyCavalry,
			UpgradeCategories.LeaderRifle
        }
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
        self:CreateBehaviorConstructors();
    end
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
function QuestSystemBehavior:CreateAi(_PlayerID, _TechLevel)
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
function QuestSystemBehavior:UpgradeAi(_PlayerID, _NewTechLevel)
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
-- Creates an army for the AI that is recruited from the barracks of the player.
-- The cannon type is automatically set by the technology level of the AI.
-- @param _PlayerID [number] ID of player
-- @param _Strength [number] Strength of army
-- @param _Position [string] Home area center
-- @param _RodeLength [number] Rode length
-- @param _TroopTypes [table] Allowed troops
-- @within QuestSystemBehavior
-- @local
--
function QuestSystemBehavior:CreateAiArmy(_PlayerID, _Strength, _Position, _RodeLength, _TroopTypes)
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
        _TroopTypes = copy(self.Data.AllowedTypesDefault);
    end
    assert(type(_TroopTypes) == "table", "CreateAiArmy: _TroopTypes must be a table!");
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
            if army.Advanced.attackPosition then
                army.Advanced.State = QuestSystemBehavior.ArmyState.Select;
            else
                -- Army must patrol
                if army.Advanced.patrolPoints then
                    army.Advanced.State = QuestSystemBehavior.ArmyState.Patrol;
                end
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
            if army.Advanced.attackPosition then
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
                -- All enemies dead? Wait for command
                if not AreEnemiesInArea(army.player, GetPosition(army.Advanced.Target), army.rodeLength) then
                    army.Advanced.State = QuestSystemBehavior.ArmyState.Default;
                    army.Advanced.Target = nil;
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
                if army.Advanced.Waypoint == nil then
                    army.Advanced.Waypoint = 1;
                    army.Advanced.AnchorChanged = nil;
                    army.Advanced.StartTime = Logic.GetTime();
                end

                -- Set anchor position
                if not army.Advanced.AnchorChanged then
                    Redeploy(army, GetPosition(army.Advanced.patrolPoints[army.Advanced.Waypoint]));
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
function Goal_UpgradeHeadquarter(...)
    return b_Goal_UpgradeHeadquarter:New(unpack(arg));
end

b_Goal_UpgradeHeadquarter = {
    Data = {
        Name = "Goal_UpgradeHeadquarter",
        Type = Objectives.Headquarter
    },
};

function b_Goal_UpgradeHeadquarter:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Level = _Parameter;
    end
end

function b_Goal_UpgradeHeadquarter:GetGoalTable()
    return {self.Data.Type, self.Data.Level};
end

QuestSystemBehavior:RegisterBehavior(b_Goal_UpgradeHeadquarter);

-- -------------------------------------------------------------------------- --

---
-- This goal is won, after a hero of the receiver talked to the character.
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
        Type = Objectives.NPC
    },
};

function b_Goal_NPC:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.Target = _Parameter;
    elseif _Index == 2 then
        self.Data.Hero = _Parameter;
    elseif _Index == 3 then
        self.Data.Message = _Parameter;
    end
end

function b_Goal_NPC:GetGoalTable()
    return {self.Data.Type, self.Data.Target, self.Data.Hero, self.Data.Message};
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
        Type = Objectives.BuyOffer
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
    return {self.Data.Type, self.Data.Merchant, self.Data.Offer, self.Data.Amount};
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
        Type = Reprisals.MapScriptFunction
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
        Type = Reprisals.Defeat
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
        Type = Reprisals.Victory
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
        Type = Reprisals.MapScriptFunction
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
        Type = Reprisals.ChangePlayer
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
        Type = Reprisals.Message
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
        Type = Reprisals.DestroyEntity
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
        Type = Reprisals.DestroyEffect
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
        Type = Reprisals.Diplomacy
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
        Type = Reprisals.RemoveQuest
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
        Type = Reprisals.QuestSucceed
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
        Type = Reprisals.QuestFail
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
        Type = Reprisals.QuestInterrupt
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
        Type = Reprisals.QuestActivate
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
        Type = Reprisals.QuestRestart
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
-- Restarts the quest and activates it immediately.
-- @param _QuestName [string] Quest name
-- @within Reprisals
--
function Reprisal_QuestRestartForceActive(...)
    return b_Reprisal_QuestRestartForceActive:New(unpack(arg));
end

b_Reprisal_QuestRestartForceActive = {
    Data = {
        Name = "Reprisal_QuestRestartForceActive",
        Type = Reprisals.QuestRestartForceActive
    },
};

function b_Reprisal_QuestRestartForceActive:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.QuestName = _Parameter;
    end
end

function b_Reprisal_QuestRestartForceActive:GetReprisalTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_QuestRestartForceActive);

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
        Type = Reprisals.Technology
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
function Reprisal_ConcilArea(...)
    return b_Reprisal_ConcilArea:New(unpack(arg));
end

b_Reprisal_ConcilArea = {
    Data = {
        Name = "Reprisal_ConcilArea",
        Type = Reprisals.ConcilArea
    },
};

function b_Reprisal_ConcilArea:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.AreaCenter = _Parameter;
    end
end

function b_Reprisal_ConcilArea:GetReprisalTable()
    return {self.Data.Type, self.Data.AreaCenter};
end

QuestSystemBehavior:RegisterBehavior(b_Reprisal_ConcilArea);

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
        Type = Reprisals.Move
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
        Type = Rewards.MapScriptFunction
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
b_Reward_Defeat.Data.Type = Rewards.Defeat;
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
b_Reward_Victory.Data.Type = Rewards.Victory;
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
b_Reward_Briefing.Data.Type = Rewards.MapScriptFunction;
b_Reward_Briefing.GetReprisalTable = nil;

function b_Reward_Briefing:GetRewardTable()
    return {self.Data.Type, {self.Data.CustomFunction, self}};
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
b_Reward_ChangePlayer.Data.Type = Rewards.ChangePlayer;
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
b_Reward_Message.Data.Type = Rewards.Message;
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
b_Reward_DestroyEntity.Data.Type = Rewards.DestroyEntity;
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
b_Reward_DestroyEffect.Data.Type = Rewards.DestroyEffect;
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
b_Reward_Diplomacy.Data.Type = Rewards.Diplomacy;
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
b_Reward_RemoveQuest.Data.Type = Rewards.RemoveQuest;
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
b_Reward_QuestSucceed.Data.Type = Rewards.QuestSucceed;
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
b_Reward_QuestFail.Data.Type = Rewards.QuestFail;
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
b_Reward_QuestInterrupt.Data.Type = Rewards.QuestInterrupt;
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
b_Reward_QuestActivate.Data.Type = Rewards.QuestActivate;
b_Reward_QuestActivate.GetReprisalTable = nil;

function b_Reward_QuestActivate:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestActivate);

-- -------------------------------------------------------------------------- --

---
-- Restarts the quest and activates it immediately.
-- @param _QuestName [string] Quest name
-- @within Rewards
--
function Reward_QuestRestartForceActive(...)
    return b_Reward_QuestRestartForceActive:New(unpack(arg));
end

b_Reward_QuestRestartForceActive = copy(b_Reprisal_QuestRestartForceActive);
b_Reward_QuestRestartForceActive.Data.Name = "Reward_QuestRestartForceActive";
b_Reward_QuestRestartForceActive.Data.Type = Rewards.QuestRestartForceActive;
b_Reward_QuestRestartForceActive.GetReprisalTable = nil;

function b_Reward_QuestRestartForceActive:GetRewardTable()
    return {self.Data.Type, self.Data.QuestName};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_QuestRestartForceActive);

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
b_Reward_Technology.Data.Type = Rewards.Technology;
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
function Reward_ConcilArea(...)
    return b_Reward_ConcilArea:New(unpack(arg));
end

b_Reward_ConcilArea = copy(b_Reprisal_ConcilArea);
b_Reward_ConcilArea.Data.Name = "Reward_ConcilArea";
b_Reward_ConcilArea.Data.Type = Rewards.ConcilArea;
b_Reward_ConcilArea.GetReprisalTable = nil;

function b_Reward_ConcilArea:GetRewardTable()
    return {self.Data.Type, self.Data.AreaCenter};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_ConcilArea);

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
b_Reward_Move.Data.Type = Rewards.Move;
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
        Type = Rewards.CreateEntity
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
        Type = Rewards.CreateGroup
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
-- @param _EffectType [string] Effect type name
-- @param _Position [number] Position of effect
-- @within Rewards
--
function Reward_CreateEffect(...)
    return b_Reward_CreateEffect:New(unpack(arg));
end

b_Reward_CreateEffect = {
    Data = {
        Name = "Reward_CreateEffect",
        Type = Rewards.CreateEffect
    },
};

function b_Reward_CreateEffect:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.EffectName = _Parameter;
    elseif _Index == 2 then
        self.Data.EntityType = Effects[_Parameter];
    elseif _Index == 3 then
        self.Data.Position = _Parameter;
    end
end

function b_Reward_CreateEffect:GetRewardTable()
    return {self.Data.Type, self.Data.EffectName, self.Data.EntityType, self.Data.Position};
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
        Type = Rewards.Resource
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
        Type = Rewards.CreateMarker
    },
};

function b_Reward_CreateMarker:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.MarkerType = MakerTypes[_Parameter];
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
        Type = Rewards.DestroyMarker
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
function Reward_RevalArea(...)
    return b_Reward_RevalArea:New(unpack(arg));
end

b_Reward_RevalArea = {
    Data = {
        Name = "Reward_RevalArea",
        Type = Rewards.RevalArea
    },
};

function b_Reward_RevalArea:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.AreaCenter = _Parameter;
    elseif _Index == 2 then
        self.Data.Explore = _Parameter;
    end
end

function b_Reward_RevalArea:GetRewardTable()
    return {self.Data.Type, self.Data.AreaCenter, self.Data.Explore};
end

QuestSystemBehavior:RegisterBehavior(b_Reward_RevalArea);

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
        Type = Rewards.MapScriptFunction
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
-- Starts the quest after a player has been killed.
-- @param _PlayerID [number] PlayerID
-- @within Triggers
--
function Trigger_PlayerDestroyed(...)
    return b_Trigger_PlayerDestroyed:New(unpack(arg));
end

b_Trigger_PlayerDestroyed = {
    Data = {
        Name = "Trigger_PlayerDestroyed",
        Type = Conditions.PlayerDestroyed
    },
};

function b_Trigger_PlayerDestroyed:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    end
end

function b_Trigger_PlayerDestroyed:GetTriggerTable()
    return {self.Data.Type, self.Data.PlayerID};
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_PlayerDestroyed);

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
-- Creates an merchant with up to 4 offers. Each offer purchases a fixed
-- amount of a resource for 1000 units of gold. Default inflation will be used.
-- @param _Merchant [string] Merchant name
-- @param _OfferType1 [string] Resourcetype on sale
-- @param _OfferAmount1 [number] Quantity to post
-- @param _OfferType2 [string] Resourcetype on sale
-- @param _OfferAmount2 [number] Quantity to post
-- @param _OfferType3 [string] Resourcetype on sale
-- @param _OfferAmount3 [number] Quantity to post
-- @param _OfferType4 [string] Resourcetype on sale
-- @param _OfferAmount4 [number] Quantity to post
-- @within Rewards
--
function Reward_OpenResourceSale(...)
    return b_Reward_OpenResourceSale:New(unpack(arg));
end

b_Reward_OpenResourceSale = {
    Data = {
        Name = "Reward_OpenResourceSale",
        Type = Rewards.MapScriptFunction
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
-- @param _OfferType1 [string] Resourcetype on sale
-- @param _OfferAmount1 [number] Quantity to post
-- @param _OfferType2 [string] Resourcetype on sale
-- @param _OfferAmount2 [number] Quantity to post
-- @param _OfferType3 [string] Resourcetype on sale
-- @param _OfferAmount3 [number] Quantity to post
-- @param _OfferType4 [string] Resourcetype on sale
-- @param _OfferAmount4 [number] Quantity to post
-- @within Rewards
--
function Reward_OpenResourcePurchase(...)
    return b_Reward_OpenResourcePurchase:New(unpack(arg));
end

b_Reward_OpenResourcePurchase = {
    Data = {
        Name = "Reward_OpenResourcePurchase",
        Type = Rewards.MapScriptFunction
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
-- Creates an merchant with up to 4 offers. Each offer sells 1000 units of a
-- resource for a fixed amount of gold. Default inflation will be used.
-- @param _Merchant [string] Merchant name
-- @param _OfferType1 [string] Resourcetype on sale
-- @param _OfferCost1 [number] Gold costs
-- @param _OfferAmount1 [number] Quantity to post
-- @param _OfferType2 [string] Resourcetype on sale
-- @param _OfferCost2 [number] Gold costs
-- @param _OfferAmount2 [number] Quantity to post
-- @param _OfferType3 [string] Resourcetype on sale
-- @param _OfferCost3 [number] Gold costs
-- @param _OfferAmount3 [number] Quantity to post
-- @param _OfferType4 [string] Resourcetype on sale
-- @param _OfferCost4 [number] Gold costs
-- @param _OfferAmount4 [number] Quantity to post
-- @within Rewards
--
function Reward_OpenMercenaryMerchant(...)
    return b_Reward_OpenMercenaryMerchant:New(unpack(arg));
end

b_Reward_OpenMercenaryMerchant = {
    Data = {
        Name = "Reward_OpenMercenaryMerchant",
        Type = Rewards.MapScriptFunction
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
        Type = Rewards.MapScriptFunction
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
-- @param _PlayerID [number] Id of player
-- @param _TechLevel [number] Tech level
-- @within Rewards
--
function Reward_CreateAi(...)
    return b_Reward_CreateAi:New(unpack(arg));
end

b_Reward_CreateAi = {
    Data = {
        Name = "Reward_CreateAi",
        Type = Rewards.MapScriptFunction
    },
};

function b_Reward_CreateAi:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.TechLevel = _Parameter;
    end
end

function b_Reward_CreateAi:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_CreateAi:CustomFunction(_Quest)
    QuestSystemBehavior:CreateAi(self.Data.PlayerID, self.Data.TechLevel);
end

function b_Reward_CreateAi:Debug(_Quest)
    return false;
end

function b_Reward_CreateAi:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateAi);

-- -------------------------------------------------------------------------- --

---
-- Defines an army that must be recruited by the AI.
-- @param _PlayerID [number] Id of player
-- @param _Strength [number] Strength of army
-- @param _Position [string] Army base position
-- @param _RodeLength [number] Average action range
-- @param _TroopType [number] Army troop type
-- @within Rewards
--
function Reward_CreateAiArmy(...)
    return b_Reward_CreateAiArmy:New(unpack(arg));
end

b_Reward_CreateAiArmy = {
    Data = {
        Name = "Reward_CreateAiArmy",
        Type = Rewards.MapScriptFunction
    },
};

function b_Reward_CreateAiArmy:AddParameter(_Index, _Parameter)
    if _Index == 1 then
        self.Data.PlayerID = _Parameter;
    elseif _Index == 2 then
        self.Data.Strength = _Parameter;
    elseif _Index == 3 then
        self.Data.Position = _Parameter;
    elseif _Index == 4 then
        self.Data.RodeLength = _Parameter;
    elseif _Index == 5 then
        self.Data.TroopType = _Parameter;
    end
end

function b_Reward_CreateAiArmy:GetRewardTable()
    return {self.Data.Type, {self.CustomFunction, self}};
end

function b_Reward_CreateAiArmy:CustomFunction(_Quest)
    QuestSystemBehavior:CreateAiArmy(self.Data.PlayerID, self.Data.Strength, self.Data.Position, self.Data.RodeLength, self.Data.TroopType);
end

function b_Reward_CreateAiArmy:Debug(_Quest)
    return false;
end

function b_Reward_CreateAiArmy:Reset(_Quest)
end

QuestSystemBehavior:RegisterBehavior(b_Reward_CreateAiArmy);

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
    if QuestSystem.Quests[QuestID].m_Result == QuestResults.Success then 
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestSuccess:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..elf.Data.QuestName);
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
    if QuestSystem.Quests[QuestID].m_Result == QuestResults.Failure then 
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestFailure:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..elf.Data.QuestName);
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
    if QuestSystem.Quests[QuestID].m_State == QuestStates.Over then 
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestOver:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..elf.Data.QuestName);
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
    if QuestSystem.Quests[QuestID].m_State == QuestStates.Over and QuestSystem.Quests[QuestID].m_Result == QuestStates.Interrupted then 
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestInterrupted:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..elf.Data.QuestName);
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
    if QuestSystem.Quests[QuestID].m_State == QuestStates.Active then 
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestActive:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..elf.Data.QuestName);
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
    if QuestSystem.Quests[QuestID].m_State == QuestStates.Inactive then 
        self.Data.StartTime = self.Data.StartTime or Logic.GetTime();
        if self.Data.Waittime + self.Data.StartTime < Logic.GetTime() then
            return true;
        end
    end
end

function b_Trigger_QuestNotTriggered:Debug(_Quest)
    if GetQuestID(self.Data.QuestName) == 0 then
        dbg(_Quest, self, "Quest does not exist: " ..elf.Data.QuestName);
    end
    return false;
end

function b_Trigger_QuestNotTriggered:Reset(_Quest)
    self.Data.StartTime = nil;
end

QuestSystemBehavior:RegisterBehavior(b_Trigger_QuestNotTriggered);

