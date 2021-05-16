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
-- <li>qsb.core.questsync</li>
-- <li>qsb.core.questtools</li>
-- <li>qsb.ext.aitrooprecruiter</li>
-- <li>qsb.ext.aitroopspawner</li>
-- <li>qsb.ext.aiarmy</li>
-- </ul>
--
-- @set sort=true
--

AiController = {
    Players = {},

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
-- <b>Note:</b> The AI will decide to which targets an army is send to. There
-- isn't a direct connection for one army and one target.
--
-- @param[type=string] _ArmyName   Army identifier
-- @param[type=number] _PlayerID   Owner of army
-- @param[type=number] _Strength   Strength of army [1|8]
-- @param[type=string] _Position   Home Position of army
-- @param[type=number] _Area       Action range of the army
-- @return[type=number] Army ID
-- @within Methods
--
-- @usage CreateAIPlayerArmy("Foo", false, 2, 8, "armyPos1", 5000);
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
    return Army.ArmyID;
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
-- isn't a direct connection for one army and one target.
--
-- @param[type=string] _ArmyName    Army identifier
-- @param[type=number] _PlayerID    Owner of army.
-- @param[type=number] _Strength    Strength of army [1|8]
-- @param[type=string] _Position    Home Position of army
-- @param[type=string] _Spawner     Name of generator
-- @param[type=number] _Area        Action range of the army
-- @param[type=number] _RespawnTime Time till troops are refreshed
-- @param              ...          List of types to spawn
-- @within Methods
--
-- @usage CreateAIPlayerSpawnArmy(
--     "Bar", false, 2, 8, "armyPos1", "lifethread", 5000, 2*60,
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
    return Army.ArmyID;
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
    if AiControllerArmyNameToID[_Army] then
        _Army = AiControllerArmyNameToID[_Army];
    end
    return AiArmyList[_Army];
end

---
-- Disbands the given army.
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
        Army:Disband(_DestroyTroops, _DestoryProducer);
        for k, v in pairs(AiControllerArmyNameToID) do
            if v == _ArmyID then
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
-- @param               _Army   Name or ID of army
-- @param[type=boolean] _Flag   Army is hidden
-- @within Methods
-- 
-- @usage ArmySetHiddenFromAI("SomeArmy", true);
--
function ArmySetHiddenFromAI(_Army, _Flag)
    local Army = GetArmy(_Army);
    if Army then
        Army
            :SetHiddenFromAI(_Flag)
            :SetState(ArmyStates.Idle)
            :SetSubState(ArmySubStates.None)
            :SetAttackTarget(nil)
            :SetGuardTarget(nil)
            :UpdateDefenceTargetsOfArmy(Army.PlayerID, _ArmyID);
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
-- Disables or enables the ability to attack for the army. This function can
-- be used to forbid an army to attack even if there are valid targets.
--
-- @param               _Army   Name or ID of army
-- @param[type=boolean] _Flag   Ability to attack
-- @within Methods
-- 
-- @usage ArmyDisableAttackAbility("SomeArmy", true);
--
function ArmyDisableAttackAbility(_Army, _Flag)
    local Army = GetArmy(_Army);
    if Army then
        Army:SetAttackAllowed(_Flag == true);
    end
    return self;
end

---
-- Disables or enables the ability to patrol between positions. This
-- function can force an army to stay on its spawnpoint or to avoid to be put
-- on guard duties.
--
-- @param               _Army   Name or ID of army
-- @param[type=boolean] _Flag   Ability to defend
-- @within Methods
-- 
-- @usage ArmyDisablePatrolAbility("SomeArmy", false);
--
function ArmyDisablePatrolAbility(_Army, _Flag)
    local Army = GetArmy(_Army);
    if Army then
        Army:SetDefenceAllowed(_Flag == true);
    end
    return self;
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
-- <b>Note:</b> An AI will send one army per attack target. Which army is send
-- is decided by the AI. Armies can not be connected to attack positions. By
-- default the AI chooses the target for an army that is closest to it.
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
-- Registers an patrol waypoint position for the player.
--
-- <b>Note:</b> An AI will send one army per patrol waypoint. Which army is send
-- is decided by the AI. Armies can not be connected to patrol waypoints. By
-- default the AI chooses the position for an army that is closest to it.
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
        return ArmyIDList;
    end
    AiController:SetUnitsToBuild(_PlayerID, _CategoryList);
end

---
-- Sets if the AI player is ignoring the costs of units when recruiting or
-- refreshing.
-- 
-- <p><b>Note:</b> This is active by default! You can deactivate it if you
-- want the AI to be restricted to the resources.</p>
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

function AiController:CreatePlayer(_PlayerID, _SerfAmount, _HomePosition, _Strength, _TechLevel, _Construct, _Rebuild)
    if self.Players[_PlayerID] then
        return;
    end
    if not self.Initalized then
        self.Initalized = true;
        self:OverrideGameEventsForRecruiterUpdate();
    end

    self.Players[_PlayerID] = {
        Armies          = {},
        Producers       = {},
        AttackPos       = {},
        AttackPosMap    = {},
        AttackAllowed   = true,
        DefencePos      = {},
        DefencePosMap   = {},
        DefenceAllowed  = true,
        HomePosition    = _HomePosition,
        TechLevel       = _TechLevel,
        UnitsToBuild    = copy(self.DefaultUnitsToBuild),
        EmploysArmies   = _Strength > 0,
        Strength        = _Strength,
        MilitaryCosts   = false,
    };
    table.insert(self.Players[_PlayerID].UnitsToBuild, Entities["PV_Cannon" .._TechLevel]);

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

    QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_SECOND, function(_PlayerID)
        AiController:ControlPlayerArmies(_PlayerID);
    end, _PlayerID);
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
            local ArmyID = self.Players[_PlayerID].Armies[i].ArmyID;
            self:AddDefenceTargetToArmy(_PlayerID, ArmyID, _Entity);
        end
    end
end

function AiController:UpdateDefenceTargetsOfArmy(_PlayerID, _ArmyID)
    if self.Players[_PlayerID] then
        for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
            local Army = self.Players[_PlayerID].Armies[i];
            if Army.ArmyID == _ArmyID then
                if not Army.IsHiddenFromAI then
                    for k, v in pairs(self.Players[_PlayerID].DefencePos) do
                        self:AddDefenceTargetToArmy(_PlayerID, _ArmyID, v);
                    end
                else
                    self.Players[_PlayerID].Armies[i].GuardPosList = {};
                end
            end
        end
    end
end

function AiController:AddDefenceTargetToArmy(_PlayerID, _ArmyID, _Entity)
    if self.Players[_PlayerID] then
        for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
            local Army = self.Players[_PlayerID].Armies[i];
            if Army.ArmyID == _ArmyID then
                if not Army.IsHiddenFromAI then
                    if QuestTools.GetReachablePosition(Army.HomePosition, _Entity) ~= nil then
                        if not QuestTools.IsInTable(_Entity, Army.GuardPosList) then
                            table.insert(self.Players[_PlayerID].Armies[i].GuardPosList, _Entity);
                        end
                    end
                end
            end
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
            local ArmyID = self.Players[_PlayerID].Armies[i].ArmyID;
            self:RemoveDefenceTargetFromArmy(_PlayerID, ArmyID, _Entity);
        end
    end
end

function AiController:RemoveDefenceTargetFromArmy(_PlayerID, _ArmyID, _Entity)
    if self.Players[_PlayerID] then
        for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
            local Army = self.Players[_PlayerID].Armies[i];
            if Army.ArmyID == _ArmyID then
                if not Army.IsHiddenFromAI then
                    for j= table.getn(Army.GuardPosList), 1, -1 do
                        if Army.GuardPosList[j] == _Entity then
                            table.remove(self.Players[_PlayerID].Armies[i].GuardPosList, j);
                        end
                    end
                end
            end
        end
    end
end

function AiController:SetAttackAllowed(_PlayerID, _ArmyID, _Flag)
    if self.Players[_PlayerID] then
        self.Players[_PlayerID].AttackAllowed = _Flag == true;
        for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
            self.Players[_PlayerID].Armies[i].AttackAllowed = _Flag == true;
        end
    end
end

function AiController:SetDefenceAllowed(_PlayerID, _ArmyID, _Flag)
    if self.Players[_PlayerID] then
        self.Players[_PlayerID].DefenceAllowed = _Flag == true;
        for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
            self.Players[_PlayerID].Armies[i].DefendAllowed = _Flag == true;
        end
    end
end

-- ~~~ Army ~~~ --

function AiController:ControlPlayerArmies(_PlayerID)
    if self.Players[_PlayerID] then
        -- Clear dead armies
        for i= table.getn(self.Players[_PlayerID].Armies), 1, -1 do
            if self.Players[_PlayerID].Armies[i]:IsDead() then
                table.remove(self.Players[_PlayerID].Armies, i);
            end
        end

        -- Handle attacks
        for i= table.getn(self.Players[_PlayerID].AttackPos), 1, -1 do
            self:ControlPlayerAssault(_PlayerID, self.Players[_PlayerID].AttackPos[i]);
        end

        -- Handle guarding
        for i= table.getn(self.Players[_PlayerID].DefencePos), 1, -1 do
            self:ControlPlayerDefence(_PlayerID, self.Players[_PlayerID].DefencePos[i]);
        end
    end
end

function AiController:ControlPlayerAssault(_PlayerID, _Position)
    -- no enemies there
    local Enemies = AiArmy:GetEnemiesInArea(_Position, 4500, _PlayerID);
    if table.getn(Enemies) == 0 then
        return;
    end

    -- check occupied
    for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
        if self.Players[_PlayerID].Armies[i].AttackTarget == _Position then
            return;
        end
    end

    -- associate army
    for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
        local Army = self.Players[_PlayerID].Armies[i];
        if  not Army.AttackTarget 
        and not Army.IsHiddenFromAI
        and Army.DefendAllowed
        and (Army.State == ArmyStates.Idle or Army.State == ArmyStates.Guard)
        and not Army:IsDead() 
        and QuestTools.GetReachablePosition(Army.HomePosition, _Position) ~= nil then
            if Army.State == ArmyStates.Guard then
                Army:SetGuardTarget(nil);
            end
            Army:SetAttackTarget(_Position);
            Army:SetState(ArmyStates.Idle);
            Army:SetSubState(ArmySubStates.None);
            break;
        end
    end
end

function AiController:ControlPlayerDefence(_PlayerID, _Position)    
    -- check occupied
    for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
        if self.Players[_PlayerID].Armies[i].GuardTarget == _Position then
            return;
        end
    end

    -- associate army
    for i= 1, table.getn(self.Players[_PlayerID].Armies), 1 do
        local Army = self.Players[_PlayerID].Armies[i];
        if QuestTools.IsInTable(_Position, Army.GuardPosList) then
            if  not Army.AttackTarget 
            and not Army.GuardTarget
            and not Army.IsHiddenFromAI
            and Army.DefendAllowed
            and Army.State == ArmyStates.Idle
            and not Army:IsDead() 
            and QuestTools.GetReachablePosition(Army.HomePosition, _Position) ~= nil then
                local Positions = self.Players[_PlayerID].Armies[i].GuardPosList;
                if not QuestTools.IsInTable(_Position, Positions.Visited) then
                    Army:SetGuardTarget(_Position);
                    Army:SetState(ArmyStates.Idle);
                    Army:SetSubState(ArmySubStates.None);
                    Army:AddVisitedGuardPosition(_Position);
                    if table.getn(Positions.Visited) >= table.getn(Positions) then
                        Army:ClearVisitedGuardPositions();
                    end
                    break;
                end
            end
        end
    end
end

function AiController:ControlPlayerDefence2(_PlayerID, _Position)
    if not self.Players[_PlayerID].DefencePosMap[_Position] then
        self.Players[_PlayerID].DefencePosMap[_Position] = {};
    end
    
    local Data = self.Players[_PlayerID].DefencePosMap[_Position];
    local AllocatedArmy = Data.Selected;
    if AllocatedArmy then
        local Army = GetArmy(AllocatedArmy);
        if  Army
        and Army.State == ArmyStates.Guard
        and Army.DefendAllowed
        and Army.GuardTarget
        and not Army.AttackTarget
        and (Army.State < ArmyStates.Retreat)
        and not Army:IsDead()
        and QuestTools.GetReachablePosition(Army.HomePosition, _Position) ~= nil then
            return;
        end
    end

    local NewArmy;
    for k, v in pairs(self.Players[_PlayerID].Armies) do
        if v and not QuestTools.IsInTable(v.ArmyID, self.Players[_PlayerID].DefencePosMap[_Position]) then
            if  not v.AttackTarget 
            and not v.GuardTarget
            and not v.IsHiddenFromAI
            and v.DefendAllowed
            and v.State == ArmyStates.Idle
            and not v:IsDead() 
            and QuestTools.GetReachablePosition(v.HomePosition, _Position) ~= nil then
                NewArmy = v;
                break;
            end
        end
    end

    if NewArmy then
        table.insert(self.Players[_PlayerID].DefencePosMap[_Position], NewArmy.ArmyID);
        self.Players[_PlayerID].DefencePosMap[_Position].Selected = NewArmy.ArmyID;
        NewArmy:SetGuardTarget(_Position);
        return;
    else
        -- self.Players[_PlayerID].DefencePosMap[_Position] = nil;
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

            -- Create crmies
            local Index = 0;
            while (Strength > table.getn(self.Players[_PlayerID].Armies)) do
                Index = Index +1;
                local ArmyID = self:EmployNewArmy(
                    "EmployArmy_Player" .._PlayerID.. "_ID_" ..Index,
                    _PlayerID,
                    self.Players[_PlayerID].HomePosition,
                    4000,
                    12
                );
                ArmyDisableAttackAbility(ArmyID, math.mod(Index, 3) ~= 0);
                self:FindProducerBuildings(_PlayerID);
                self:UpdateRecruitersOfArmy(_PlayerID, ArmyID);
                for k, v in pairs(self.Players[_PlayerID].DefencePos) do
                    self:AddDefenceTargetToArmy(_PlayerID, ArmyID, v);
                end
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
end

-- ~~~ Producer ~~~ --

function AiController:UpdateRecruitersOfArmies(_PlayerID)
    if not self.Players[_PlayerID] then
        return;
    end
    for i= table.getn(self.Players[_PlayerID].Armies), 1, -1 do
        self:UpdateRecruitersOfArmy(_PlayerID, self.Players[_PlayerID].Armies[i].ArmyID);
    end
end

function AiController:UpdateRecruitersOfArmy(_PlayerID, _ArmyID)
    if not self.Players[_PlayerID] then
        return;
    end
    local Army = GetArmy(_ArmyID);
    if Army and Army.PlayerID == _PlayerID and not Army.IsRespawningArmy then
        self.Players[_PlayerID].Armies[_ArmyID].Producers = {};
        for k, v in pairs(self.Players[_PlayerID].Producers) do
            if v and not v.IsSpawner then
                if QuestTools.GetReachablePosition(Army.HomePosition, v.ApproachPosition) ~= nil then
                    table.insert(self.Players[_PlayerID].Armies[_ArmyID].Producers, v);
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

