-- ########################################################################## --
-- #  AI Controller                                                         # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module allows to create AI player and armies.
--
-- There is no limit to armies per player nor troops per army.
--
-- Armies have their script behavior defined by attack and defence positions on
-- the map. An AI player can automatically employ armies. Also armies can be
-- hidden from the AI to control them in a own job.
--
-- If you are an beginner you should stick to the options the quest behaviors
-- give you. They are enough in most of the cases.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.quest.questsync</li>
-- <li>qsb.quest.questtools</li>
-- <li>qsb.ai.aitrooprecruiter</li>
-- <li>qsb.ai.aitroopspawner</li>
-- <li>qsb.ai.aiarmy</li>
-- </ul>
--
-- @set sort=true
--

AiController = {
    Players = {},
    CurrentPlayer = 0;

    DefaultUnitsToBuild = {
        UpgradeCategories.LeaderPoleArm,
        UpgradeCategories.LeaderSword,
        UpgradeCategories.LeaderBow,
        UpgradeCategories.LeaderHeavyCavalry,
        UpgradeCategories.LeaderCavalry,
        UpgradeCategories.LeaderRifle,
    },
}

AiControllerArmyNameToID = {};
AiControllerCustomJobID = {};
AiControllerPlayerJobID = nil;

-- -------------------------------------------------------------------------- --

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
-- @usage CreateAIPlayer(2, 4, 8, "HomeP2");
--
function CreateAIPlayer(_PlayerID, _TechLevel, _SerfAmount, _HomePosition, _Strength, _Construct, _Rebuild)
    _SerfAmount = _SerfAmount or 6;
    _Strength = _Strength or 0;

    if _Strength > 0 and (not _HomePosition or not IsExisting(_HomePosition)) then
        Message("DEBUG: If strength is > 0 then a home position mus be set!");
        return;
    end

    if not AiController.Players[_PlayerID] then
        local PlayerEntities = QuestTools.GetPlayerEntities(_PlayerID, 0);
        for i= 1, table.getn(PlayerEntities), 1 do
            if Logic.IsBuilding(PlayerEntities[i]) == 1 then
                AiController:CreatePlayer(_PlayerID, _SerfAmount, _HomePosition, _Strength, _TechLevel, _Construct, _Rebuild);
                return;
            end
        end
    end
    Message("DEBUG: Failed to create AI for player " ..tostring(_PlayerID).. "!");
end

---
-- Destroys an AI player with all of their armies.
--
-- @param[type=number] _PlayerID     PlayerID
-- @within Methods
--
-- @usage DestroyAIPlayer(2);
--
function DestroyAIPlayer(_PlayerID)
    AiController:DestroyPlayer(_PlayerID);
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
-- that will be attacked by the AI. Replace X with the player ID and Y with
-- a unique number starting by 1.
--
-- You can also use entities named with PlayerX_PatrolPointY to define
-- positions were the AI will patrol. Also replace X with the player ID and
-- Y with a unique number starting by 1.
--
-- <b>Note:</b> The AI will decide which targets an army is send to. There
-- isn't a direct connection for one army and one target. If you don't want
-- the AI to controll the army it must be hidden from the AI. In that case you
-- have to provide the army with targets.
--
-- @param[type=string] _ArmyName   Army identifier
-- @param[type=number] _PlayerID   Owner of army
-- @param[type=number] _Strength   Strength of army [1|8]
-- @param[type=string] _Position   Home Position of army
-- @param[type=number] _Area       Action range of the army
-- @return[type=table] Army
-- @within Methods
--
-- @usage CreateAIPlayerArmy("Foo", 2, 8, "armyPos1", 5000);
--
function CreateAIPlayerArmy(_ArmyName, _PlayerID, _Strength, _Position, _Area)
    if not AiController.Players[_PlayerID] then
        Message("DEBUG: Can not create army for player " ..tostring(_PlayerID).. " because AI is not initalized!");
        return;
    end
    if AiControllerArmyNameToID[_ArmyName] then
        Message("DEBUG: Army " ..tostring(_ArmyName).. " has already been created!");
        return;
    end
    local Army = new (AiArmy, _PlayerID, _Position, _Area, _Strength);
    Army.IsRespawningArmy = false;
    table.insert(AiController.Players[_PlayerID].Armies, Army);
    AiControllerArmyNameToID[_ArmyName] = Army.ArmyID;
    AiController:CreateDefendBehavior(_PlayerID, Army.ArmyID);
    return Army;
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
-- that will be attacked by the AI. Replace X with the player ID and Y with
-- a unique number starting by 1.
--
-- You can also use entities named with PlayerX_PatrolPointY to define
-- positions were the AI will patrol. Also replace X with the player ID and
-- Y with a unique number starting by 1.
--
-- <b>Note:</b> The AI will decide to which targets an army is send to. There
-- isn't a direct connection for one army and one target. If you don't want
-- the AI to controll the army it must be hidden from the AI. In that case you
-- have to provide the army with targets.
--
-- @param[type=string] _ArmyName    Army identifier
-- @param[type=number] _PlayerID    Owner of army.
-- @param[type=number] _Strength    Strength of army [1|8]
-- @param[type=string] _Position    Home Position of army
-- @param[type=string] _Spawner     Name of generator
-- @param[type=number] _Area        Action range of the army
-- @param[type=number] _RespawnTime Time till troops are refreshed
-- @param[type=table]  ...          List of types to spawn
-- @return[type=table] Army
-- @within Methods
--
-- @usage CreateAIPlayerSpawnArmy(
--     "Bar", 2, 8, "armyPos1", "lifethread", 5000, 2*60,
--     {Entities.PU_LeaderSword2, 3},
--     {Entities.PU_LeaderBow2, 3},
--     {Entities.PV_Cannon2, 0}
-- );
--
function CreateAIPlayerSpawnArmy(_ArmyName, _PlayerID, _Strength, _Position, _Spawner, _Area, _RespawnTime, ...)
    if not AiController.Players[_PlayerID] then
        Message("DEBUG: Can not create army for player " ..tostring(_PlayerID).. " because AI is not initalized!");
        return;
    end
    if AiControllerArmyNameToID[_ArmyName] then
        Message("DEBUG: Army " ..tostring(_ArmyName).. " has already been created!");
        return;
    end
    if type(_Spawner) ~= "table" then
        _Spawner = {_Spawner};
    end
    local EntityTypes = {};
    for i= 1, table.getn(arg), 1 do
        table.insert(EntityTypes, arg[i]);
    end
    local Army = new (AiArmy, _PlayerID, _Position, _Area, _Strength);
    Army.IsRespawningArmy = true;
    for i= 1, table.getn(_Spawner) do
        local Producer = CreateTroopGenerator {
			ScriptName = _Spawner[i],
			Delay      = _RespawnTime,
			Types      = EntityTypes
		};
        Army:AddProducer(Producer);
    end
    table.insert(AiController.Players[_PlayerID].Armies, Army);
    AiControllerArmyNameToID[_ArmyName] = Army.ArmyID;
    AiController:CreateDefendBehavior(_PlayerID, Army.ArmyID);
    return Army;
end

---
-- Returns the army instance with the passed ID or name.
--
-- @param _Army Name or ID of army
-- @within Methods
-- 
-- @usage local Army = GetArmy("SomeArmy");
--
function GetArmy(_Army)
    return AiController:GetArmy(_Army);
end

---
-- Disbands the given army and removes it from the AI`s list of armies.
--
-- @param               _Army            Name or ID of army
-- @param[type=boolean] _DestroyTroops   Destroy remaining soldiers
-- @param[type=boolean] _DestoryProducer Destroy producer buildings
-- @within Methods
-- 
-- @usage ArmyDisband("SomeArmy", true, true);
--
function ArmyDisband(_Army, _DestroyTroops, _DestoryProducer)
    local Army = GetArmy(_Army);
    if Army then
        if AiController.Players[Army.PlayerID] then
            for i= table.getn(AiController.Players[Army.PlayerID].Armies), 1 , -1 do
                if AiController.Players[Army.PlayerID].Armies[i].ArmyID == Army.ArmyID then
                    table.remove(AiController.Players[Army.PlayerID].Armies, i);
                end
            end
        end
        Army:Disband(_DestroyTroops, _DestoryProducer);
        for k, v in pairs(AiControllerArmyNameToID) do
            if v == Army.ArmyID then
                AiControllerArmyNameToID[k] = nil;
            end
        end
    end
end

---
-- Hides an army from their AI or returns them back. Hidden armies will not
-- be considered when the AI selects targets to attack or to defend. When an
-- army is hidden or returned, all objectives of this army are nullified.
--
-- <b>Note:</b> Armies will be automatically hidden when a custom controller is
-- added to them. Use this only if you want the army to be stationary without
-- receiving any orders. (Bandits camp ect.)
--
-- @param               _Army   Name or ID of army
-- @param[type=boolean] _Flag   Army is hidden
-- @within Methods
-- 
-- @usage ArmySetHiddenFromAI("SomeArmy", true);
--
function ArmySetHiddenFromAI(_Army, _Flag)
    local Army = GetArmy(_Army);
    if Army then
        Army:SetHiddenFromAI(_Flag);
        AiController:CreateDefendBehavior(Army.PlayerID, Army.ArmyID);
    end
end

---
-- Removes the army from candidates for attack operations or rejoins it. When
-- an army is removed or returned, all objectives of this army are nullified.
--
-- Armies that won't go on patrol will remain on their home position when not
-- ordered to patrol.
--
-- <b>Note:</b> This will only affect armies with default controller. If a
-- custom controller is used, this won't have an effect.
--
-- @param               _Army   Name or ID of army
-- @param[type=boolean] _Flag   Army can't attack
-- @within Methods
--
-- @usage ArmySetExemtFromAttack("SomeArmy", true);
--
function ArmySetExemtFromAttack(_Army, _Flag)
    local Army = GetArmy(_Army);
    if Army then
        Army:SetExemtFromAttack(_Flag);
        AiController:CreateDefendBehavior(Army.PlayerID, Army.ArmyID);
    end
end

---
-- Removes the army from candidates for patrol operations or rejoins it. When
-- an army is removed or returned, all objectives of this army are nullified.
--
-- Armies that won't go on patrol will remain on their home position when not
-- chosen for an attack operation.
--
-- <b>Note:</b> This will only affect armies with default controller. If a
-- custom controller is used, this won't have an effect.
--
-- @param               _Army   Name or ID of army
-- @param[type=boolean] _Flag   Army can't patrol
-- @within Methods
--
-- @usage ArmySetExemtFromPatrol("SomeArmy", true);
--
function ArmySetExemtFromPatrol(_Army, _Flag)
    local Army = GetArmy(_Army);
    if Army then
        Army:SetExemtFromPatrol(_Flag);
        AiController:CreateDefendBehavior(Army.PlayerID, Army.ArmyID);
    end
end

---
-- Changes the home of the army.
--
-- The home position must be the name of an reachable script entity or any other
-- blocking free indestructable entity.
--
-- @param               _Army         Name or ID of army
-- @param[type=boolean] _HomePosition Name of home position
-- @within Methods
-- 
-- @usage ArmySetHomePosition("SomeArmy", "NewHome");
--
function ArmySetHomePosition(_Army, _HomePosition)
    if AiControllerArmyNameToID[_Army] then
        _Army = AiControllerArmyNameToID[_Army];
    end
    if AiArmyList[_Army] then
        AiArmyList[_Army].HomePosition = _HomePosition;
    end
end

---
-- Adds an troop producer to the army if not already add.
--
-- @param               _Army     Name or ID of army
-- @param[type=boolean] _Producer Name of Producer
-- @within Methods
-- 
-- @usage ArmyAddTroopProducer("SomeArmy", "BanditTower1");
--
function ArmyAddTroopProducer(_Army, _Producer)
    local Army = GetArmy(_Army);
    if Army then
        local Producer = AiTroopRecruiterList[_Producer];
        if Producer == nil then
            Producer = AiTroopSpawnerList[_Producer];
            if Producer == nil then
                Message("DEBUG: Can not find producer " ..tostring(_Producer).. "!");
                return;
            end
        end
        local ID = GetID(Producer.ScriptName);
        if not IsExisting(ID) then
            Message("DEBUG: Producer " ..tostring(_Producer).. " does not exist!");
            return;
        end
        if Logic.EntityGetPlayer(ID) ~= 0 and Logic.EntityGetPlayer(ID) ~= Army.PlayerID then
            Message("DEBUG: Producer must be of the same player ID as the army!");
            return;
        end
        Army:AddProducer(Producer);
    end
end

---
-- Removes an troop producer from the army.
--
-- <b>Note</b>: Destroyed producers will be automatically discarded by the army.
-- You won't need to remove them manually.
--
-- @param               _Army     Name or ID of army
-- @param[type=boolean] _Producer Name of Producer
-- @within Methods
-- 
-- @usage ArmyRemoveTroopProducer("SomeArmy", "BanditTower1");
--
function ArmyRemoveTroopProducer(_Army, _Producer)
    local Army = GetArmy(_Army);
    if Army then
        Army:DropProducer(_Producer);
    end
end

---
-- Sets the max amount of serfs the AI player will buy.
--
-- <b>Note</b>: If the Ai dont owns an normal HQ then this will not have any
-- effect on it.
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
    AiController:SetDoesRepair(_PlayerID, not _Flag);
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
    AiController:SetDoesConstruct(_PlayerID, not _Flag);
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
    AiController:SetDoesRebuild(_PlayerID, not _Flag);
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
-- Registers an attack target position for the player.
--
-- <b>Note:</b> An AI will send one or more armies per attack target. Which
-- armies are send is decided by the AI. Armies can not be connected to attack
-- positions. By default the AI chooses the target for an army that is closest
-- to it.
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=string] _Position Zielppsition
-- @within Methods
-- 
-- @usage AddAIPlayerAttackTarget(2, "VeryImportantTarget");
--
function AddAIPlayerAttackTarget(_PlayerID, _Position)
    if not AiController.Players[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
    end
    AiController:AddAttackTarget(_PlayerID, GetID(_Position));
end

---
-- Removes the attack target from the AI player and all armies of said player.
-- @param[type=number] _PlayerID ID of player
-- @param[type=string] _Position Zielppsition
-- @within Methods
-- 
-- @usage RemoveAIPlayerAttackTarget(2, "VeryImportantTarget");
--
function RemoveAIPlayerAttackTarget(_PlayerID, _Position)
    if not AiController.Players[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    AiController:RemoveAttackTarget(_PlayerID, GetID(_Position));
end

---
-- Sets the max amount of armies that are send to a single target.
--
-- <b>Note:</b> This applies only to armies that are not hidden from the AI and
-- do not use custom controllers.
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=number] _Max      Amount of armies
-- @within Methods
-- 
-- @usage SetAIPlayerMaxArmiesPerTarget(2, 3);
--
function SetAIPlayerMaxArmiesPerTarget(_PlayerID, _Max)
    if not AiController.Players[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    if not _Max or math.ceil(_Max) < 1 then
        assert(false, "Max amount of armies must be above 0!");
        return;
    end
    AiController.Players[_PlayerID].AttackForceLimit = math.ceil(_Max);
end

---
-- Registers an patrol waypoint position for the player.
--
-- <b>Note:</b> An AI will send one army per patrol waypoint. Which army is send
-- is decided by the AI. Armies can not be connected to patrol waypoints. By
-- default the AI chooses the position for an army that is closest to it. So if
-- you wish to send more than one army to a target place multiple targets.
--
-- @param[type=number] _PlayerID ID of player
-- @param[type=string] _Position Zielposition
-- @within Methods
-- 
-- @usage AddAIPlayerPatrolPoint(2, "VeryImportantTarget");
--
function AddAIPlayerPatrolPoint(_PlayerID, _Position)
    if not AiController.Players[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
    end
    AiController:AddDefenceTarget(_PlayerID, _Position);
end

---
-- Removes the patrol waypoint from the AI player and all armies of said player.
-- @param[type=number] _PlayerID ID of player
-- @param[type=string] _Position       Zielppsition
-- @within Methods
-- 
-- @usage RemoveAIPlayerPatrolPoint(2, "VeryImportantTarget");
--
function RemoveAIPlayerPatrolPoint(_PlayerID, _Position)
    if not AiController.Players[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    AiController:RemoveDefenceTarget(_PlayerID, _Position);
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
    if not AiController.Players[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    AiController:SetUnitsToBuild(_PlayerID, _CategoryList);
end

---
-- Sets if the AI player is ignoring the costs of units when recruiting or
-- refreshing.
-- 
-- <p><b>Note:</b> This is active by default! You can deactivate it if you
-- want the AI to be restricted to the resources. But this is not recommended,
-- because the AI might be to easy to beat.</p>
--
-- @param[type=number]  _PlayerID ID of player
-- @param[type=boolean] _Flag     Does ignore costs
-- @within Methods
-- 
-- @usage SetAIPlayerIgnoreMilitaryCosts(2, false);
--
function SetAIPlayerIgnoreMilitaryCosts(_PlayerID, _Flag)
    if not AiController.Players[_PlayerID] then
        assert(false, "There isn't an AI initalized for player " .._PlayerID.. "!");
        return;
    end
    AiController:SetIgnoreMilitaryUnitCosts(_PlayerID, _Flag);
end

-- -------------------------------------------------------------------------- --

---
-- Sets an manual controller for an army.
--
-- When the controller is set the army is automatically hidden from the AI. If
-- the controller is invalidated by passing nil the army is returned to the AI.
--
-- If the controller is add successfully the ID of the created job is returned.
-- Otherwise nil is returned.
--
-- The controller is called each second and the ID of the army is passed. To
-- access the army data index AiArmyList with the army ID. Inside your function
-- you only need to add behavior to the army.
--
-- <b>Note:</b> This feature is considered advanced level. In most cases the
-- normal AI controller is sufficient to do the job. Use this if you need
-- multiple bases for one AI which will not work with the generic controller.
--
-- <b>Note:</b> See documentation of AiArmy for futher information.
--
-- @param                _Army     Name or ID of army
-- @param[type=function] _Function Controller function
-- @param                ...       Controller argument list
-- @return[type=number] Job ID of controller
-- @within Methods
-- 
-- @usage -- Function reference
-- ArmySetController("SomeArmy", MyControllerFunction);
-- -- Inline function
-- ArmySetController("SomeArmy", function(_ArmyID)
--     -- Do something here
-- end);
--
function ArmySetController(_Army, _Function, ...)
    arg = arg or {};
    local Army = GetArmy(_Army);
    if _Function == nil then
        ArmySetHiddenFromAI(_Army, false);
        if Army and AiControllerCustomJobID[Army.ArmyID] then
            EndJob(AiControllerCustomJobID[Army.ArmyID]);
            AiControllerCustomJobID[Army.ArmyID] = nil;
        end
        return;
    end
    ArmySetHiddenFromAI(_Army, true);

    if Army then
        local ID = QuestTools.StartSimpleJobEx(_Function, Army.ArmyID, unpack(arg));
        AiControllerCustomJobID[Army.ArmyID] = ID
        return ID;
    end
end

-- -------------------------------------------------------------------------- --

function AiController:CreatePlayer(_PlayerID, _SerfAmount, _HomePosition, _Strength, _TechLevel, _Construct, _Rebuild)
    if self.Players[_PlayerID] then
        return;
    end
    if not self.Initalized then
        self.Initalized = true;
        self:OverrideGameEventsForRecruiterUpdate();
    end

    self.Players[_PlayerID] = {
        Armies           = {},
        Producers        = {},
        AttackPos        = {},
        AttackPosMap     = {},
        DefencePos       = {},
        DefencePosMap    = {},
        HomePosition     = _HomePosition,
        TechLevel        = _TechLevel,
        UnitsToBuild     = copy(self.DefaultUnitsToBuild),
        EmploysArmies    = _Strength > 0,
        Strength         = _Strength,
        ArmyStrength     = 12,
        RodeLength       = 4000,
        OuterRange       = 3000,
        LastTick         = 0,
        AttackForceLimit = 1,
        MilitaryCosts    = true,
    };
    table.insert(self.Players[_PlayerID].UnitsToBuild, Entities["PV_Cannon" .._TechLevel]);
    -- Remove rifle
    if _TechLevel < 3 then
        for i= table.getn(self.Players[_PlayerID].UnitsToBuild), 1, -1 do
            if self.Players[_PlayerID].UnitsToBuild[i] == UpgradeCategories.LeaderRifle then
                table.remove(self.Players[_PlayerID].UnitsToBuild, i);
            end
        end
    end

    -- Find default target and patrol points
    for k, v in pairs(QuestTools.GetEntitiesByPrefix("Player" .._PlayerID.. "_AttackTarget")) do
        self:AddAttackTarget(_PlayerID, v);
    end
    for k, v in pairs(QuestTools.GetEntitiesByPrefix("Player" .._PlayerID.. "_PatrolPoint")) do
        self:AddDefenceTarget(_PlayerID, v);
    end
    self:CreateDefaultDefenceTargets(_PlayerID);

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
        extracting   = 0,
        
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
        rebuild	= {
            delay = 2*60
        }
    };
    SetupPlayerAi(_PlayerID, Description);
    
    -- Employ armies
    self:FindProducerBuildings(_PlayerID);
    self:EmployArmies(_PlayerID);
    -- Construct buildings
    self:SetDoesConstruct(_PlayerID, _Construct == true);
    -- Rebuild buildings
    self:SetDoesRebuild(_PlayerID, _Rebuild == true);

    -- Set neutral to all players
    for i= 1, table.getn(Score.Player), 1 do
        if i ~= _PlayerID then
            SetNeutral(i, _PlayerID);
        end
    end

    -- table.getn(Score.Player)
    if not AiControllerPlayerJobID then
        AiControllerPlayerJobID = StartSimpleHiResJobEx(function()
            AiController:ControlPlayerArmies();
        end);
    end
end

function AiController:DestroyPlayer(_PlayerID)
    AI.Player_DisableAi(_PlayerID);
    if self.Players[_PlayerID] then
        return;
    end
    for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
        self.Players[_PlayerID].Armies[i]:Disband(true, false);
    end
    EndJob(self.Players[_PlayerID].JobID);
    self.Players[_PlayerID] = nil;
end

function AiController:GetTime()
    return math.floor(Logic.GetTime() * 10);
end

function AiController:GetArmy(_Army)
    if AiControllerArmyNameToID[_Army] then
        _Army = AiControllerArmyNameToID[_Army];
    end
    return AiArmyList[_Army];
end

-- ~~~ Properties ~~~ --

function AiController:SetDoesRepair(_PlayerID, _Flag)
    if self.Players[_PlayerID] then
        AI.Village_EnableRepairing(_PlayerID, (_Flag == true and 1) or 0);
    end
end

function AiController:SetDoesConstruct(_PlayerID, _Flag)
    if self.Players[_PlayerID] then
        AI.Village_EnableConstructing(_PlayerID, (_Flag == true and 1) or 0);
    end
end

function AiController:SetDoesRebuild(_PlayerID, _Flag)
    if self.Players[_PlayerID] then
        if _Flag == true then
            AI.Entity_ActivateRebuildBehaviour(_PlayerID, 2*60, 0);
        else
            AI.Village_DeactivateRebuildBehaviour(_PlayerID);
        end
    end
end

function AiController:SetIgnoreMilitaryUnitCosts(_PlayerID, _Flag)
    if self.Players[_PlayerID] then
        self.Players[_PlayerID].MilitaryCosts = _Flag == true;
        for k, v in pairs(AiTroopRecruiterList) do
            if v and IsExisting(k) and GetPlayer(k) == _PlayerID then
                v:SetCheatCosts(_Flag == true);
            end
        end
    end
end

function AiController:DoesIgnoreMilitaryCosts(_PlayerID)
    if self.Players[_PlayerID] then
        return self.Players[_PlayerID].MilitaryCosts == true;
    end
    return false;
end

function AiController:UpgradeTroops(_PlayerID, _NewTechLevel)
    if self.Players[_PlayerID] then
        local OldLevel = self.Players[_PlayerID].TechLevel;
        if _NewTechLevel > 0 and _NewTechLevel < 5 and OldLevel < _NewTechLevel then
            -- Remove cannon
            for i= table.getn(self.Players[_PlayerID].UnitsToBuild), 1, -1 do
                local UpgradeCategory = self.Players[_PlayerID].UnitsToBuild[i];
                if UpgradeCategory == UpgradeCategories.Cannon1
                or UpgradeCategory == UpgradeCategories.Cannon2
                or UpgradeCategory == UpgradeCategories.Cannon3
                or UpgradeCategory == UpgradeCategories.Cannon4 then
                    table.remove(self.Players[_PlayerID].UnitsToBuild, i);
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
            table.insert(self.Players[_PlayerID].UnitsToBuild, CannonType);
        end
        self.Players[_PlayerID].TechLevel = _NewTechLevel;
    end
end

function AiController:SetUnitsToBuild(_PlayerID, _CategoryList)
    if self.Players[_PlayerID] then
        -- Remove all
        self.Players[_PlayerID].UnitsToBuild = {};
        -- Add troops
        for i= 1, table.getn(_CategoryList), 1 do
            local UpgradeCategory = self.Players[_PlayerID].UnitsToBuild[i];
            if _CategoryList[i] ~= UpgradeCategories.Cannon1
            or _CategoryList[i] ~= UpgradeCategories.Cannon2
            or _CategoryList[i] ~= UpgradeCategories.Cannon3
            or _CategoryList[i] ~= UpgradeCategories.Cannon4 then
                table.insert(self.Players[_PlayerID].UnitsToBuild, _CategoryList[i]);
            end
        end
        -- Add cannon type
        local CannonType = Entities["PV_Cannon" ..self.Players[_PlayerID].TechLevel];
        table.insert(self.Players[_PlayerID].UnitsToBuild, CannonType);
        -- Remove rifle
        if self.Players[_PlayerID].TechLevel < 3 then
            for i= table.getn(self.Players[_PlayerID].UnitsToBuild), 1, -1 do
                if self.Players[_PlayerID].UnitsToBuild[i] == UpgradeCategories.LeaderRifle then
                    table.remove(self.Players[_PlayerID].UnitsToBuild, i);
                end
            end
        end
        -- Alter recruiting armies
        for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
            if not self.Players[_PlayerID].Armies[i].IsRespawningArmy then
                for j= 1, table.getn(self.Players[_PlayerID].Armies[i].Producers), 1 do
                    local Producer = self.Players[_PlayerID].Armies[i].Producers[j];
                    Producer:ClearTypes();
                    Producer:AddTypes(self.Players[_PlayerID].UnitsToBuild);
                end
            end
        end
    end
end

-- ~~~ Targeting ~~~ --

function AiController:AddAttackTarget(_PlayerID, _Entity)
    if self.Players[_PlayerID] then
        if not QuestTools.IsInTable(_Entity, self.Players[_PlayerID].AttackPos) then
            table.insert(self.Players[_PlayerID].AttackPos, _Entity);
        end
    end
end

function AiController:RemoveAttackTarget(_PlayerID, _Entity)
    if self.Players[_PlayerID] then
        for i= table.getn(self.Players[_PlayerID].AttackPos), 1, -1 do
            if self.Players[_PlayerID].AttackPos[i] == _Entity then
                table.remove(self.Players[_PlayerID].AttackPos, i);
            end
        end
    end
end

function AiController:AddDefenceTarget(_PlayerID, _Entity)
    if self.Players[_PlayerID] then
        if not QuestTools.IsInTable(_Entity, self.Players[_PlayerID].DefencePos) then
            table.insert(self.Players[_PlayerID].DefencePos, _Entity);
        end
        for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
            self:CreateDefendBehavior(
                _PlayerID,
                self.Players[_PlayerID].Armies[i].ArmyID,
                false
            );
        end
    end
end

function AiController:RemoveDefenceTarget(_PlayerID, _Entity)
    if self.Players[_PlayerID] then
        for i= table.getn(self.Players[_PlayerID].DefencePos), 1, -1 do
            if self.Players[_PlayerID].DefencePos[i] == _Entity then
                table.remove(self.Players[_PlayerID].DefencePos, i);
            end
        end
        for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
            self:CreateDefendBehavior(
                _PlayerID,
                self.Players[_PlayerID].Armies[i].ArmyID,
                false
            );
        end
    end
end

function AiController:CreateDefaultDefenceTargets(_PlayerID)
    if  self.Players[_PlayerID]
    and self.Players[_PlayerID].HomePosition
    and table.getn(self.Players[_PlayerID].DefencePos) == 0
    and self.Players[_PlayerID].RodeLength > 0 then
        for i= -45, 315, 90 do
            local Home = self.Players[_PlayerID].HomePosition;
            local Area = self.Players[_PlayerID].RodeLength;
            local Position = QuestTools.GetReachablePosition(
                Home,
                QuestTools.GetCirclePosition(Home, Area, i)
            );
            if Position then
                local ID = Logic.CreateEntity(
                    Entities.XD_ScriptEntity,
                    Position.X,
                    Position.Y,
                    0,
                    _PlayerID
                );
                self:AddDefenceTarget(_PlayerID, ID);
            end
        end
    end
end

-- ~~~ Army ~~~ --

function AiController:ControlPlayerArmies()
    self.CurrentPlayer = self.CurrentPlayer +1;
    if table.getn(Score.Player) < self.CurrentPlayer then
        self.CurrentPlayer = 1;
    end
    local PlayerID = self.CurrentPlayer;
    
    if self.Players[PlayerID] then
        if self.Players[PlayerID].LastTick == 0 or self:GetTime() > self.Players[PlayerID].LastTick +10 then
            self.Players[PlayerID].LastTick = self:GetTime();
            -- Clear dead armies
            for i= table.getn(self.Players[PlayerID].Armies), 1, -1 do
                if self.Players[PlayerID].Armies[i]:IsDead() then
                    table.remove(self.Players[PlayerID].Armies, i);
                end
            end

            -- Handle attacks
            for i= table.getn(self.Players[PlayerID].AttackPos), 1, -1 do
                self:ControlPlayerAssault(PlayerID, self.Players[PlayerID].AttackPos[i]);
            end
        end
    end
end

function AiController:ControlPlayerAssault(_PlayerID, _Position)
    -- no enemies there
    local Enemies = AiArmy:CallGetEnemiesInArea(_Position, self.Players[_PlayerID].RodeLength, _PlayerID);
    for i= table.getn(Enemies), 1, -1 do
        local Type = Logic.GetEntityType(Enemies[i]);
        local TypeName = Logic.GetEntityTypeName(Type);
        if  TypeName ~= nil and TypeName ~= ""
        and string.find(TypeName, "Tower") then
            table.remove(Enemies, i);
        end
    end
    if table.getn(Enemies) == 0 then
        for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
            local Army = self.Players[_PlayerID].Armies[i];
            local Command = Army:GetBehaviorInQueue("Attack");
            if Command and Army:IsExecutingBehavior("Attack") then
                if Command.m_Target and Command.m_Target[1] == _Position then
                    Army:DequeueBehavior();
                    Army:InvalidateCurrentBehavior();
                end
            end
        end
        return;
    end

    -- check occupied
    local MaxArmiesForTarget = self.Players[_PlayerID].AttackForceLimit;
    for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
        local Army = self.Players[_PlayerID].Armies[i];
        local Command = Army:GetBehaviorInQueue("Attack");
        if Command then
            if Command.m_Target and Command.m_Target[1] == _Position then
                MaxArmiesForTarget = MaxArmiesForTarget -1;
                if MaxArmiesForTarget <= 0 then
                    return;
                end
            end
        end
    end

    -- associate army
    for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
        local Army = self.Players[_PlayerID].Armies[i];
        local IsAttacking = Army:IsExecutingBehavior("Attack");
        local IsBattling = Army:IsExecutingBehavior("Battle");
        local IsRetreating = Army:IsExecutingBehavior("Retreat");
        local IsRefilling = Army:IsExecutingBehavior("Refill");

        if  not Army.IsHiddenFromAI
        and not Army.IsExemtFromAttack
        and (not IsAttacking and not IsBattling and not IsRetreating and not IsRefilling)
        and not Army:IsDead() 
        and QuestTools.GetReachablePosition(Army.HomePosition, _Position) ~= nil then
            Army:InsertBehavior(AiArmyBehavior:New("Attack", _Position, 2000));
            Army:InvalidateCurrentBehavior();
            break;
        end
    end
end

function AiController:CreateDefendBehavior(_PlayerID, _Army, _Purge)
    if self.Players[_PlayerID] and table.getn(self.Players[_PlayerID].DefencePos) > 0 then
        local Army = self:GetArmy(_Army);
        if Army and not Army.IsHiddenFromAI then
            -- remove old commands
            for i= table.getn(Army.BehaviorQueue), 1, -1 do
                if _Purge or Army.BehaviorQueue[i].m_Identifier == "Guard" then
                    Army:RemoveBehavior(i);
                end
            end
            -- find reachable points
            local Reachable = {};
            for k, v in pairs(self.Players[_PlayerID].DefencePos) do
                local Position = QuestTools.GetReachablePosition(Army.HomePosition, v);
                if Position then
                    table.insert(Reachable, {v, Position});
                end
            end
            -- Set home position if needed
            if Army.IsExemtFromPatrol or table.getn(Reachable) == 0 then
                table.insert(Reachable, {-1, Army.HomePosition});
            end
            -- add behavir for each point
            Reachable = shuffle(Reachable);
            for i= 1, table.getn(Reachable), 1 do
                Army:EnqueueBehavior(AiArmyBehavior:New(
                    "Guard",
                    Reachable[i][2],
                    self.Players[_PlayerID].RodeLength + self.Players[_PlayerID].OuterRange,
                    3*60,
                    true
                ));
            end
        end
    end
end

function AiController:EmployArmies(_PlayerID)
    if self.Players[_PlayerID] then
        if self.Players[_PlayerID].EmploysArmies then
            local Strength = self.Players[_PlayerID].Strength;
            -- Drop armies if to much
            while (Strength < table.getn(self.Players[_PlayerID].Armies)) do
                local Army = table.remove(self.Players[_PlayerID].Armies);
                Army:Disband(true, false);
                for k, v in pairs(AiControllerArmyNameToID) do
                    if v == Army.ArmyID then
                        AiControllerArmyNameToID[k] = nil;
                    end
                end
            end

            -- Create armies
            local Index = 0;
            while (Strength > table.getn(self.Players[_PlayerID].Armies)) do
                Index = Index +1;
                local ArmyID = self:EmployNewArmy(
                    "EmployArmy_Player" .._PlayerID.. "_ID_" ..Index,
                    _PlayerID,
                    self.Players[_PlayerID].HomePosition,
                    self.Players[_PlayerID].RodeLength,
                    self.Players[_PlayerID].ArmyStrength
                );
                self:UpdateRecruitersOfArmy(_PlayerID, ArmyID);
                self:CreateDefendBehavior(_PlayerID, ArmyID);
            end
        end
    end
end

function AiController:EmployNewArmy(_ArmyName, _PlayerID, _Position, _Area, _Strength)
    if AiControllerArmyNameToID[_ArmyName] then
        return;
    end
    local Army = new (AiArmy, _PlayerID, _Position, _Area, _Strength);
    Army.IsRespawningArmy = false;
    Army.StayAlive = true;
    table.insert(AiController.Players[_PlayerID].Armies, Army);
    AiControllerArmyNameToID[_ArmyName] = Army.ArmyID;
    return Army.ArmyID;
end

-- ~~~ Producer ~~~ --

function AiController:OverrideGameEventsForRecruiterUpdate()
    GameCallback_BuildingDestroyed_Orig_AiController = GameCallback_BuildingDestroyed;
    GameCallback_BuildingDestroyed = function(_HurterPlayerID, _HurtPlayerID)
        GameCallback_BuildingDestroyed_Orig_AiController(_HurterPlayerID, _HurtPlayerID);

        if not AiController.Players[_HurtPlayerID] then
            return;
        end
        AiController:ClearDestroyedProducers(_HurtPlayerID);
        AiController:UpdateRecruitersOfArmies(_HurtPlayerID);
    end

    GameCallback_OnBuildingConstructionComplete_Orig_AiController = GameCallback_OnBuildingConstructionComplete;
    GameCallback_OnBuildingConstructionComplete = function(_BuildingID, _PlayerID)
        GameCallback_OnBuildingConstructionComplete_Orig_AiController(_BuildingID, _PlayerID);

        if not AiController.Players[_PlayerID] then
            return;
        end
        AiController:AddProducerBuilding(_PlayerID, _BuildingID);
        AiController:UpdateRecruitersOfArmies(_PlayerID);
    end

    -- HACK: Add producers afterwards to armies if previously failed
    StartSimpleJobEx(function()
        for i= 1, table.getn(Score.Player), 1 do
            if AiController.Players[i] then
                if table.getn(AiController.Players[i].Producers) > 0 then
                    for j= 1, table.getn(AiController.Players[i].Armies), 1 do
                        local Army = AiController.Players[i].Armies[j];
                        if not Army.IsHiddenFromAI and table.getn(Army.Producers) == 0 then
                            AiController:UpdateRecruitersOfArmy(i, j);
                        end
                    end
                end
            end
        end
    end)
end

function AiController:UpdateRecruitersOfArmies(_PlayerID)
    if not self.Players[_PlayerID] then
        return;
    end
    for i= table.getn(self.Players[_PlayerID].Armies), 1, -1 do
        self:UpdateRecruitersOfArmy(_PlayerID, i);
    end
end

function AiController:UpdateRecruitersOfArmy(_PlayerID, _Index)
    if not self.Players[_PlayerID] then
        return;
    end
    local Army = self.Players[_PlayerID].Armies[_Index];
    if Army and Army.PlayerID == _PlayerID and not Army.IsRespawningArmy then
        self.Players[_PlayerID].Armies[_Index].Producers = {};
        for k, v in pairs(self.Players[_PlayerID].Producers) do
            if v and not v.IsSpawner then
                if QuestTools.SameSector(Army.HomePosition, v.ApproachPosition) then
                    table.insert(self.Players[_PlayerID].Armies[_Index].Producers, v);
                end
            end
        end
    end
end

function AiController:ClearDestroyedProducers(_PlayerID)
    if not self.Players[_PlayerID] then
        return;
    end
    for i= table.getn(self.Players[_PlayerID].Producers), 1, -1 do
        if not self.Players[_PlayerID].Producers[i]:IsAlive() then
            table.remove(self.Players[_PlayerID].Producers, i);
        end
    end
end

function AiController:AddProducerBuilding(_PlayerID, _Entity)
    if not self.Players[_PlayerID] then
        return;
    end
    local HomePosition = self.Players[_PlayerID].HomePosition;
    -- No spawner allowed
    if AiTroopSpawnerList[_Entity] then
        return;
    end
    -- Check recruiter
    if AiTroopRecruiterList[_Entity] then
        if not HomePosition or QuestTools.SameSector(HomePosition, AiTroopRecruiterList[_Entity].ApproachPosition) then
            table.insert(self.Players[_PlayerID].Producers, AiTroopRecruiterList[_Entity]);
            return;
        end
    end
    -- Create new recruiter
    if not HomePosition or QuestTools.GetReachablePosition(HomePosition, _Entity) ~= nil then
        local Recruiter = self:CreateRecruiter(_PlayerID, _Entity);
        if Recruiter then
            table.insert(self.Players[_PlayerID].Producers, Recruiter);
        end
    end
end

function AiController:FindProducerBuildings(_PlayerID)
    if not self.Players[_PlayerID] then
        return;
    end
    self.Players[_PlayerID].Producers = {};
    for k, v in pairs(self:GetPossibleRecruiters(_PlayerID)) do
        self:AddProducerBuilding(_PlayerID, v);
    end
end

function AiController:CreateRecruiter(_PlayerID, _Entity)
    local ScriptName = QuestTools.CreateNameForEntity(_Entity);
    if AiTroopRecruiterList[ScriptName] and AiTroopRecruiterList[ScriptName]:IsAlive() then
        if not AiTroopRecruiterList[ScriptName].IsSpawner then
            return AiTroopRecruiterList[ScriptName];
        end
    else
        local EntityType = Logic.GetEntityType(GetID(ScriptName));
        local UpCategory = Logic.GetUpgradeCategoryByBuildingType(EntityType);

        local UnitsForType = {};
        if UpCategory == UpgradeCategories.Barracks then
            UnitsForType = copy(AiTroopRecruiter.BarracksUnits);
        elseif UpCategory == UpgradeCategories.Archery then
            UnitsForType = copy(AiTroopRecruiter.ArcheryUnits);
        elseif UpCategory == UpgradeCategories.Stable then
            UnitsForType = copy(AiTroopRecruiter.StableUnits);
        elseif UpCategory == UpgradeCategories.Foundry then
            UnitsForType = {
                Entities.PV_Cannon1,
                Entities.PV_Cannon2,
                Entities.PV_Cannon3,
                Entities.PV_Cannon4,
            }
        else
            return;
        end

        local Recruiter = CreateTroopRecruiter {
            ScriptName = ScriptName,
            Types      = copy(UnitsForType),
        };
        Recruiter:SetCheatCosts(self:DoesIgnoreMilitaryCosts(_PlayerID));
        Recruiter:SetSelector(function(self)
            local PlayerID = Logic.EntityGetPlayer(GetID(self.ScriptName));
            local UnitList = {};
            for k, v in pairs(self.Troops.Types) do
                if QuestTools.IsInTable(v, AiController.Players[PlayerID].UnitsToBuild) then
                    table.insert(UnitList, v);
                end
            end
            return UnitList[math.random(1, table.getn(UnitList))];
        end);
        return Recruiter;
    end
end

function AiController:GetPossibleRecruiters(_PlayerID)
    local Candidates = {};
    
    -- Barracks
    local Barracks1 = QuestTools.FindAllEntities(_PlayerID, Entities.PB_Barracks1);
    for i= 1, table.getn(Barracks1) do
        if Logic.IsConstructionComplete(Barracks1[i]) == 1 then
            table.insert(Candidates, QuestTools.CreateNameForEntity(Barracks1[i]));
        end
    end
    local Barracks2 = QuestTools.FindAllEntities(_PlayerID, Entities.PB_Barracks2);
    for i= 1, table.getn(Barracks2) do
        if Logic.IsConstructionComplete(Barracks2[i]) == 1 then
            table.insert(Candidates, QuestTools.CreateNameForEntity(Barracks2[i]));
        end
    end

    -- Archery
    local Archery1 = QuestTools.FindAllEntities(_PlayerID, Entities.PB_Archery1);
    for i= 1, table.getn(Archery1) do
        if Logic.IsConstructionComplete(Archery1[i]) == 1 then
            table.insert(Candidates, QuestTools.CreateNameForEntity(Archery1[i]));
        end
    end
    local Archery2 = QuestTools.FindAllEntities(_PlayerID, Entities.PB_Archery2);
    for i= 1, table.getn(Archery2) do
        if Logic.IsConstructionComplete(Archery2[i]) == 1 then
            table.insert(Candidates, QuestTools.CreateNameForEntity(Archery2[i]));
        end
    end

    -- Stable
    local Stable1 = QuestTools.FindAllEntities(_PlayerID, Entities.PB_Stable1);
    for i= 1, table.getn(Stable1) do
        if Logic.IsConstructionComplete(Stable1[i]) == 1 then
            table.insert(Candidates, QuestTools.CreateNameForEntity(Stable1[i]));
        end
    end
    local Stable2 = QuestTools.FindAllEntities(_PlayerID, Entities.PB_Stable2);
    for i= 1, table.getn(Stable2) do
        if Logic.IsConstructionComplete(Stable2[i]) == 1 then
            table.insert(Candidates, QuestTools.CreateNameForEntity(Stable2[i]));
        end
    end

    -- Foundry
    local Foundry1 = QuestTools.FindAllEntities(_PlayerID, Entities.PB_Foundry1);
    for i= 1, table.getn(Foundry1) do
        if Logic.IsConstructionComplete(Foundry1[i]) == 1 then
            table.insert(Candidates, QuestTools.CreateNameForEntity(Foundry1[i]));
        end
    end
    local Foundry2 = QuestTools.FindAllEntities(_PlayerID, Entities.PB_Foundry2);
    for i= 1, table.getn(Foundry2) do
        if Logic.IsConstructionComplete(Foundry2[i]) == 1 then
            table.insert(Candidates, QuestTools.CreateNameForEntity(Foundry2[i]));
        end
    end

    return Candidates;
end

