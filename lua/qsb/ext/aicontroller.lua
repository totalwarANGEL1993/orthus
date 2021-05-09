-- ########################################################################## --
-- #  AI Generator                                                          # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- 
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

-- -------------------------------------------------------------------------- --

function CreateAIPlayer(_PlayerID, _TechLevel, _SerfAmount, _HomePosition, _Strength, _Construct, _Rebuild)
    _SerfAmount = _SerfAmount or 6;
    _Strength = _Strength or 0;

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

function CreateAiArmy(_PlayerID, _Home, _Range, _TroopAmount)
    if not AiController.Players[_PlayerID] then
        Message("DEBUG: Can not create army for player " ..tostring(_PlayerID).. " because AI is not initalized!");
        return;
    end
    local Army = new (AiArmy, _PlayerID, _Home, _Range, _TroopAmount);
    Army.IsRespawningArmy = false;
    table.insert(AiController.Players[_PlayerID].Armies, Army);
    return Army.ArmyID;
end

function CreateRespawningAiArmy(_PlayerID, _Home, _Range, _Spawner, _RespawnTime, _TroopAmount, _TroopList)
    if not AiController.Players[_PlayerID] then
        Message("DEBUG: Can not create army for player " ..tostring(_PlayerID).. " because AI is not initalized!");
        return;
    end
    if type(_Spawner) ~= "table" then
        _Spawner = {_Spawner};
    end
    local Army = new (AiArmy, _PlayerID, _Home, _Range, _TroopAmount);
    Army.IsRespawningArmy = true;
    for i= 1, table.getn(_Spawner) do
        local Producer = CreateTroopGenerator {
			ScriptName = _Spawner[i],
			Delay      = _RespawnTime,
			Types      = copy(_TroopList)
		};
        Army:AddProducer(Producer);
    end
    table.insert(AiController.Players[_PlayerID].Armies, Army);
    return Army.ArmyID;
end

function GetAiArmy(_ArmyID)
    return AiArmyList[_ArmyID];
end

function DisbandAiArmy(_ArmyID, _DestroyTroops, _KillProducer)
    if AiArmyList[_ArmyID] then
        AiArmyList[_ArmyID]:Disband(_DestroyTroops, _KillProducer);
    end
end

function ArmySetAttackAllowed(_ArmyID, _Flag)
    local Army = GetAiArmy(_ArmyID);
    if Army then
        Army:SetAttackAllowed(_Flag == true);
    end
    return self;
end

function ArmySetGuardAllowed(_ArmyID, _Flag)
    local Army = GetAiArmy(_ArmyID);
    if Army then
        Army:SetDefenceAllowed(_Flag == true);
    end
    return self;
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
        MilitaryCosts   = true,
        VillageCenter   = false,
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
    end
end

function AiController:RemoveDefenceTarget(_PlayerID, _Entity)
    if self.Players[_PlayerID] then
        for i= table.getn(self.Players[_PlayerID].DefencePos), 1, -1 do
            if self.Players[_PlayerID].DefencePos[i] == _Entity then
                table.remove(self.Players[_PlayerID].DefencePos, i);
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
    -- Check send army
    local AllocatedArmy = self.Players[_PlayerID].AttackPosMap[_Position];
    if AllocatedArmy then
        local Army = GetAiArmy(AllocatedArmy);
        if  Army
        and not Army:IsDead() 
        and Army:IsAttackAllowed()
        and (Army.State == ArmyStates.Advance or Army.State == ArmyStates.Attack)
        and Army.AttackTarget
        and QuestTools.GetReachablePosition(Army.HomePosition, _Position) ~= nil then
            return;
        end
        self.Players[_PlayerID].AttackPosMap[_Position] = nil;
    end
    
    -- Find new army
    local ClosestDistance = Logic.WorldGetSize();
    local ClosestArmy = nil;
    for i= table.getn(self.Players[_PlayerID].Armies), 1, -1 do
        local Army = self.Players[_PlayerID].Armies[i];
        if  Army 
        and not Army.AttackTarget
        and not Army:HasWeakTroops()
        and not Army:IsDead() 
        and Army:IsAttackAllowed()
        and (Army.State == ArmyStates.Idle or Army.State == ArmyStates.Guard)
        and QuestTools.GetReachablePosition(Army.HomePosition, _Position) ~= nil then
            local Enemies = AiArmy:GetEnemiesInRodeLength(_PlayerID, _Position);
            if table.getn(Enemies) > 0 then
                local ArmyDistance = QuestTools.GetDistance(Army:GetArmyPosition(), _Position);
                if ArmyDistance < ClosestDistance then
                    ClosestArmy = Army;
                end
            end
        end
    end
    
    -- Send new army
    if ClosestArmy then
        if ClosestArmy.State == ArmyStates.Guard then
            ClosestArmy:SetGuardTarget(nil);
        end
        self.Players[_PlayerID].AttackPosMap[_Position] = ClosestArmy.ArmyID;
        ClosestArmy:SetAttackTarget(_Position);
    end
end

function AiController:ControlPlayerDefence(_PlayerID, _Position)
    if self.Players[_PlayerID].DefencePosMap[_Position] then
        local Data = self.Players[_PlayerID].DefencePosMap[_Position];
        local AllocatedArmy = Data.Selected;
        if AllocatedArmy then
            local Army = GetAiArmy(AllocatedArmy);
            if  Army
            and not Army:IsDead() 
            and Army:IsDefenceAllowed()
            and Army.State == ArmyStates.Guard
            and not Army.AttackTarget
            and (Army.State == ArmyStates.Advance or Army.State == ArmyStates.Guard)
            and QuestTools.GetReachablePosition(Army.HomePosition, _Position) ~= nil then
                return;
            end
        end
        self.Players[_PlayerID].DefencePosMap[_Position].Selected = nil;

        local NewArmy;
        for k, v in pairs(self.Players[_PlayerID].Armies) do
            if v and not QuestTools.IsInTable(v.ArmyID, self.Players[_PlayerID].DefencePosMap[_Position]) then
                if  not v:IsDead() 
                and v:IsDefenceAllowed()
                and v.State == ArmyStates.Idle
                and not v.AttackTarget 
                and not v.GuardTarget
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
            self.Players[_PlayerID].DefencePosMap[_Position] = nil;
        end
    end
    self.Players[_PlayerID].DefencePosMap[_Position] = {};
end

function AiController:EmployArmies(_PlayerID)
    if self.Players[_PlayerID] then
        if self.Players[_PlayerID].EmploysArmies then
            local Strength = self.Players[_PlayerID].Strength;
            -- Drop armies if to much
            while (Strength < table.getn(self.Players[_PlayerID].Armies)) do
                local Army = table.remove(self.Players[_PlayerID].Armies);
                Army:Disband(true, false);
            end

            -- Create crmies
            local Index = 0;
            while (Strength > table.getn(self.Players[_PlayerID].Armies)) do
                Index = Index +1;
                local ArmyID = CreateAiArmy(_PlayerID, self.Players[_PlayerID].HomePosition, 4000, 12);
                ArmySetAttackAllowed(ArmyID, math.mod(Index, 3) ~= 0);
                AiController:FindProducerBuildings(_PlayerID);
                AiController:UpdateRecruitersOfArmy(_PlayerID, ArmyID);
            end
        end
    end
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
    local Army = GetAiArmy(_ArmyID);
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
    if QuestTools.GetReachablePosition(self.Players[_PlayerID].HomePosition, _Entity) ~= nil then
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

