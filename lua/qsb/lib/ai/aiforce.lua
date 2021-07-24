-- ########################################################################## --
-- #  AiPath                                                                # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- 
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.lib.oop</li>
-- <li>qsb.lib.ai.aiforce</li>
-- </ul>
--
-- @set sort=true
--

-- -------------------------------------------------------------------------- --



-- -------------------------------------------------------------------------- --

AiForceState = {
    Idle       = 1,
    Battle     = 2,
    Moving     = 4,
    SearchWall = 5,
    AttackWall = 6,
    Format     = 7,
    Retreat    = 8,
    Refill     = 9,
}

AiForce = {
    PlayerID             = 1;
    State                = AiForceState.Battle,
    Producers            = {},
    -- ---------------------------------------------------------------------- --
    Retreat              = 0.2;
    Defeated             = 0.1;
    DefeatedCallback     = nil;
    DefeatedCallbackExec = false;
    -- ---------------------------------------------------------------------- --
    Dead                 = false,
    DeadCallback         = nil;
    DeadCallbackExec     = false;
    -- ---------------------------------------------------------------------- --
    IsRecruitingArmy     = false,
    IsRespawningArmy     = false,
    RespawnTime          = 90,
    LastTick             = 0,
    Refill               = true;
    TroopAmount          = 8,
    Troops               = {},
    IncommingTroops      = {},
    OffenceArea          = 3500,
    WallSegmentToAttack  = 0,
    GuardTime            = -1,
    HoldPosition         = false;
    DirectTargeting      = true;
    AttackPath           = {},
    RetreatPath          = {},
    RalleyPoint          = nil,
    AcceptMethode        = nil,
    AcceptArguments      = {},
}

AiForceSequence = 0;
AiForceFrequency = 5;
AiForceList = {};
AiForceTroopIDToArmyID = {};
AiForceIncommingTroopIDToArmyID = {};
AiForceController = nil;

function AiForce:construct()
    AiForceSequence = AiForceSequence +1;
    local ArmyID = AiForceSequence;

    self.ArmyID = ArmyID;
    AiForceList[ArmyID] = self;
    if not AiForceController then
        QuestTools.StartInlineJob(Events.LOGIC_EVENT_EVERY_TURN, function()
            AiForce:ArmyController();
        end)
    end
end
class(AiForce);

function AiForce:CreateArmy(_Desc)
    local Army = new(AiForce);

    Army.PlayerID            = _Desc.PlayerID or Army.PlayerID;
    Army.State               = AiForceState.Battle;
    Army.RalleyPoint         = _Desc.RalleyPoint;
    Army.Producers           = _Desc.Producers;
    Army.Defeated            = _Desc.Defeated or Army.Defeated;
    Army.DefeatedCallback    = _Desc.DefeatedCallback;
    Army.DeadCallback        = _Desc.DeadCallback;
    Army.IsRecruitingArmy    = _Desc.Recruit == true;
    Army.IsRespawningArmy    = _Desc.Respawn == true;
    Army.RespawnTime         = _Desc.RespawnTime or Army.RespawnTime;
    Army.Refill              = _Desc.Refill == true;
    Army.TroopAmount         = _Desc.Strength or self.TroopAmount
    Army.Troops              = {};
    Army.OffenceArea         = _Desc.OffenceArea or Army.OffenceArea;
    Army.HoldPosition        = true;
    Army.DirectTargeting     = true;
    Army.AcceptMethode       = _Desc.AcceptMethode;
    Army.AcceptArguments     = _Desc.AcceptArguments or Army.AcceptArguments;

    Army.Paused = false;
    if Army.IsRespawningArmy and table.getn(Army.Producers) == 0 then
        Army.Paused = true;
    end
    Army.RespawnCounter = Army.RespawnTime;
    Army.AttackPath = AiPathModel:CreatePathFromWaypointList({Army.RalleyPoint});
    Army.RetreatPath = Army.AttackPath:Reverse();
    
    Army.ArmyController = nil;
    Army.CreateArmy = nil;
    Army.CreateTroop = nil;

    return Army;
end

function AiForce:CreateTroop(_Desc)
    return self:CreateArmy{
        PlayerID            = _Desc.PlayerID,
        DefeatedCallback    = _Desc.DefeatedCallback,
        Defeated            = _Desc.Defeated,
        Recruit             = false,
        Respawn             = false,
        Refill              = _Desc.Refill,
        Producers           = {},
        OffenceArea         = _Desc.OffenceArea,
        Troops              = _Desc.Troops,
        HoldPosition        = false,
        RalleyPoint         = _Desc.RalleyPoint,
        AcceptMethode       = _Desc.AcceptMethode,
        AcceptArguments     = _Desc.AcceptArguments,
    };
end

function AiForce:ArmyController()
    local Time = math.floor(Logic.GetTime() * 10);
    local Delta = math.mod(Time, AiForceFrequency);
    for k, v in pairs(AiForceList) do
        if (v.LastTick == 0 or v.LastTick+10 < Time) and math.mod(k, AiForceFrequency) == Delta then
            v:Operate();
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiForce:Operate()
    if not self:IsPaused() then
        self.LastTick = math.floor(Logic.GetTime() * 10);
        self.ArmyFormationCache = nil;
        self:ClearDeadTroops();
        self:ClearDeadIncommingTroops();
        self:CheckIncommingTroops();
        
        if self:IsDead() then
            if self.DeadCallback and not self.DeadCallbackExec then
                self.DeadCallbackExec = true;
                self:DeadCallback();
            end
        else
            local percentage = self:GetStrength();
            if self.State ~= AiForceState.Refill and self.Defeated >= percentage then
                if self.DefeatedCallback and not self.DefeatedCallbackExec then
                    self.DefeatedCallback();
                    self.DefeatedCallbackExec = true;
                end
                self:Vanish();
                self:ResetPath();
                if self.IsRespawningArmy and not self:IsDead() then
                    self.State = AiForceState.Refill;
                end
                if self.IsRecruitingArmy then
                    self.State = AiForceState.Refill;
                end
                return;
            end

            local currentWP, id = self:GetPath():GetCurrentWaypoint();

            -- ### Idle ### --

            if self.State == AiForceState.Idle then
                self.WallSegmentToAttack = 0;
                self:NormalizedArmySpeed();
                if self:AreEnemiesInArea(self:GetPosition(), self.OffenceArea) then
                    self.State = AiForceState.Battle;
                else
                    if percentage < self.Retreat then
                        self.State = AiForceState.Retreat;
                        return;
                    end
                    if currentWP then
                        self.State = AiForceState.Moving;
                    end
                end

            -- ### Battle ### --

            elseif self.State == AiForceState.Battle then
                self:ResetArmySpeed();
                if not self:AreEnemiesInArea(self:GetPosition(), self.OffenceArea) then
                    self.State = AiForceState.Idle;
                    return;
                end
                if self:IsScattered() then
                    self.State = AiForceState.Format;
                    return;
                end
                local TargetingMap = self:TargetEnemies(self:GetPosition());
                for k,v in pairs(self.Troops) do
                    if TargetingMap[v] and TargetingMap[v] > 0 then
                        self:TroopAttack(v, TargetingMap[v], self.DirectTargeting);
                    end
                end

            -- ### Move ### --

            elseif self.State == AiForceState.Moving then
                if not currentWP then
                    self.State = AiForceState.Retreat;
                    return;
                end
                if self:AreEnemiesInAreaWithoutWalls(self:GetPosition(), self.OffenceArea) then
                    self.State = AiForceState.Battle;
                    return;
                end
                if self:IsPathBlocked() > 0 then
                    self.State = AiForceState.SearchWall;
                    return;
                end
                if self.HoldPosition then
                    if not self:IsNear(currentWP, 500) then
                        self:MoveAsBlock(currentWP, false, false);
                    end
                else
                    if self:IsNear(currentWP, 500) then
                        if self.GuardTime == -1 then
                            self:GetPath():Next();
                        else
                            self.GuardTime = self.GuardTime -1
                            if self.GuardTime == 0 then
                                self.GuardTime = -1;
                                self:GetPath():Next();
                            end
                        end
                    else
                        self:MoveAsBlock(currentWP, false, false);
                    end
                end

            -- ### Attack Wall ### --

            elseif self.State == AiForceState.SearchWall then
                if self:AreEnemiesInArea(self:GetPosition(), self.OffenceArea) then
                    self.State = AiForceState.Battle;
                else
                    if self:IsPathBlocked() <= 0 then
                        self.State = AiForceState.Idle;
                    else
                        local WallID = self:GetWallSegment(self:GetPosition(), 4000);
                        if WallID ~= 0 then
                            self.WallSegmentToAttack = WallID;
                            self.State = AiForceState.AttackWall;
                        else
                            self.State = AiForceState.Idle;
                        end
                    end
                end

            elseif self.State == AiForceState.AttackWall then
                if self:AreEnemiesInArea(self:GetPosition(), self.OffenceArea) then
                    self.State = AiForceState.Battle;
                    return;
                end
                if self:IsScattered() then
                    self.State = AiForceState.Format;
                    return;
                end
                if not IsExisting(self.WallSegmentToAttack) or self:IsPathBlocked() <= 0 then
                    self.State = AiForceState.Idle;
                    return;
                end
                for k,v in pairs(self.Troops) do
                    local Type = Logic.GetEntityType(v);
                    if AiForceRangedTypeMap[Type] or AiForceVehicleTypeMap[Type] then
                        if not self:IsMemberBattling(v) then
                            Logic.GroupAttack(v, self.WallSegmentToAttack);
                        end
                    else
                        local Position = self:GetPosition();
                        if not self:IsMemberMoving(v) and GetDistance(v, Position) > 500 then
                            Logic.MoveSettler(v, Position.X, Position.Y);
                        end
                    end
                end

            -- ### Group ### --

            elseif self.State == AiForceState.Format then
                if not self:IsScattered() then
                    self.State = AiForceState.Idle;
                else
                    self:MoveAsBlock(currentWP, false, false);
                end

            -- ### Retreat ### --

            elseif self.State == AiForceState.Retreat then
                if self:AreEnemiesInArea(self:GetPosition(), self.OffenceArea) then
                    self.State = AiForceState.Battle;
                else
                    local firstWP = self.AttackPath.m_Nodes[1];
                    if not self:IsNear(firstWP, 500) then
                        self:MoveAsBlock(firstWP, false, false);
                    else
                        self.State = AiForceState.Refill;
                        local Weak = self:GetWeakTroops();
                        self:DispatchTroopsToProducers(Weak);
                        self:ResetPath();
                    end
                end

            -- ### Refill ### --

            elseif self.State == AiForceState.Refill then
                if self:AreEnemiesInArea(self:GetPosition(), self.OffenceArea) then
                    self.State = AiForceState.Battle;
                else
                    if self:GetStrength() < 1 then
                        self:ProduceTroops();
                    else
                        self.State = AiForceState.Idle;
                    end
                end
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiForce:BindPath(_Path)
    if _Path then
        self.HoldPosition = false;
        self.AttackPath = _Path;
        self.RetreatPath = self.AttackPath:Reverse();
    end
end

function AiForce:UnbindPath()
    self.HoldPosition = true;
    self.AttackPath = AiPathModel:CreatePathFromWaypointList({self.RalleyPoint});
    self.RetreatPath = self.AttackPath:Reverse();
end

function AiForce:ResetPath()
    if self.AttackPath then
        self.AttackPath:Reset();
    end
    if self.RetreatPath then
        self.RetreatPath:Reset();
    end
end

function AiForce:GetPath()
    if self.State == AiForceState.Retreat then
        return self.RetreatPath;
    end
    return self.AttackPath;
end

function AiForce:SetIsDead(_Flag)
    self.Dead = _Flag == true;
    if self.Dead then
        self:Vanish();
    else
        self:ResetPath();
        self.DefeatedCallbackExec = false;
        self.DeadCallbackExec = false;
        self.Dead = false;
    end
end

function AiForce:SetIsPaused(_Flag)
    self.Paused = _Flag == true;
end

function AiForce:IsPaused()
    return self.Paused == true;
end

function AiForce:IsDead()
    if self.Dead then
        return true;
    else
        if not self.IsRespawningArmy and not self.IsRecruitingArmy then
            if table.getn(self.IncommingTroops) > 0 then
                return false;
            end
            return self:GetStrength() == 0;
        end
        if not self.IsRecruitingArmy then
            if self:GetStrength() == 0 then
                if table.getn(self.IncommingTroops) > 0 then
                    return false;
                end
                local Dead = true;
                for i= table.getn(self.Producers), 1, -1 do
                    if self.Producers[i]:IsAlive() then
                        Dead = false;
                        break;
                    end
                end
                return Dead;
            end
        end
    end
    return false;
end

function AiForce:Vanish()
    for i= table.getn(self.Troops), 1, -1 do
        if IsExisting(self.Troops[i]) then
            AiForceTroopIDToArmyID[self.Troops[i]] = nil;
            DestroyEntity(self.Troops[i]);
        end
    end
    self.Troops = {};
end

function AiForce:ClearDeadTroops()
    for i= table.getn(self.Troops), 1, -1 do
        if self.Troops[i] then
            if not IsExisting(self.Troops[i]) or Logic.GetEntityHealth(self.Troops[i]) == 0 then
                AiForceTroopIDToArmyID[self.Troops[i]] = nil;
                table.remove(self.Troops, i);
            end
        end
    end
end

function AiForce:GetMembersAlive()
    local members = {};
    for k,v in pairs(self.Troops) do
        if v and IsExisting(v) then
            table.insert(members, v);
        end
    end
    return table.getn(members), members;
end

function AiForce:GetStrength()
    local FullSize = self.TroopAmount;
    local Size = 0;
    local n, Troops = self:GetMembersAlive();
    for i= 1, n, 1 do
        local Max = Logic.LeaderGetMaxNumberOfSoldiers(Troops[i]);
        local Now = Logic.LeaderGetNumberOfSoldiers(Troops[i]);
        Size = Size + ((Now+1) / (Max+1));
    end
    return Size / self.TroopAmount;
end

-- -------------------------------------------------------------------------- --

function AiForce:AddEntity(_TroopID, _Instantly)
    if not IsExisting(_TroopID) 
    or Logic.GetEntityHealth(_TroopID) == 0 then
        return;
    end
    if  Logic.IsEntityInCategory(_TroopID, EntityCategories.Cannon) == 0
    and Logic.IsLeader(_TroopID) == 0 then
        return;
    end
    if QuestTools.IsInTable(_TroopID, self.Troops)
    or QuestTools.IsInTable(_TroopID, self.IncommingTroops) then
        return;
    end
    -- TODO: Formation
    if _Instantly then
        AiForceTroopIDToArmyID[_TroopID] = self.ArmyID;
        table.insert(self.Troops, _TroopID);
    else
        AiForceIncommingTroopIDToArmyID[_TroopID] = self.ArmyID;
        table.insert(self.IncommingTroops, _TroopID);
    end
end

function AiForce:RemoveEntity(_TroopID)
    for i= table.getn(self.Troops), 1, -1 do
        if self.Troops[i] == _TroopID then
            AiForceTroopIDToArmyID[_TroopID] = nil;
            table.remove(self.Troops, i);
        end
    end
    self:RemoveIncommingEntity(_TroopID);
end

function AiForce:RemoveIncommingEntity(_TroopID)
    for i= table.getn(self.IncommingTroops), 1, -1 do
        if self.IncommingTroops[i] == _TroopID then
            AiForceIncommingTroopIDToArmyID[_TroopID] = nil;
            table.remove(self.IncommingTroops, i);
        end
    end
end

function AiForce:ClearDeadIncommingTroops()
    for i= table.getn(self.IncommingTroops), 1, -1 do
        if self.IncommingTroops[i] then
            if not IsExisting(self.IncommingTroops[i]) or Logic.GetEntityHealth(self.Troops[i]) == 0 then
                AiForceIncommingTroopIDToArmyID[self.IncommingTroops[i]] = nil;
                table.remove(self.IncommingTroops, i);
            end
        end
    end
end

function AiForce:CheckIncommingTroops()
    local ArrivalDistance = 1500^2;
    for i= table.getn(self.IncommingTroops), 1, -1 do
        if self:GetDistanceSqared(self.IncommingTroops[i], self:GetPosition()) < ArrivalDistance then
            self:AddEntity(self.IncommingTroops[i], true);
            self:RemoveIncommingEntity(self.IncommingTroops[i]);
        else
            local Position = self:GetPosition();
            Logic.GroupAttackMove(v, Position.X, Position.Y);
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiForce:AddProducer(_Producer)
    if (not _Producer.IsSpawner and self.IsRespawningArmy) or (not _Producer.IsRecruiter and self.IsRecruitingArmy) then
        return;
    end
    for k, v in pairs(self.Producers) do
        if v and v.ScriptName == _Producer.ScriptName then
            return;
        end
    end
    if self.IsRespawningArmy and table.getn(self.Producers) == 0 then
        self:SetIsPaused(false);
    end
    table.insert(self.Producers, _Producer);
end

function AiForce:DropProducer(_ScriptName)
    for k, v in pairs(self.Producers) do
        if v and v.ScriptName == _ScriptName then
            self.Producers[k] = nil;
            break;
        end
    end
    table.sort(self.Producers);
end

function AiForce:ClearProducers()
    self.Producers = {};
end

function AiForce:GetSpawnerProducers()
    local SpawnerList = {};
    for k, v in pairs(self.Producers) do
        if v and v.IsSpawner and v:IsAlive() then
            if QuestTools.SameSector(self.RalleyPoint, v.ApproachPosition) then
                table.insert(SpawnerList, v);
            end
        end
    end
    return SpawnerList;
end

function AiForce:CountProducedTroops()
    local SpawnedTroops = 0;
    for k, v in pairs(self.Producers) do
        SpawnedTroops = SpawnedTroops + table.getn(v.Troops.Created);
    end
    return SpawnedTroops;
end

function AiForce:IsInArmy(_TroopID)
    if AiForceTroopIDToArmyID[_TroopID] then
        if IsExisting(_TroopID) and Logic.GetEntityHealth(_TroopID) > 0 then
            return AiForceTroopIDToArmyID[_TroopID] == self.ArmyID;
        end
        AiForceTroopIDToArmyID[_TroopID] = nil;
    end
    return false;
end

function AiForce:GetWeakTroops()
    local Weak = {};
    for i= table.getn(self.Troops), 1, -1 do
        local Cur = Logic.LeaderGetNumberOfSoldiers(self.Troops[i]);
        local Max = Logic.LeaderGetMaxNumberOfSoldiers(self.Troops[i]);
        if Max > 0 and Cur < Max then
            table.insert(Weak, self.Troops[i]);
            AiForceTroopIDToArmyID[self.Troops[i]] = nil;
            table.remove(self.Troops, i);
        end
    end
    return Weak;
end

function AiForce:DispatchTroopsToProducers(_Troops)
    local Troops = copy(_Troops);
    -- add to producers
    for i= table.getn(Troops), 1, -1 do
        local TroopType = Logic.GetEntityType(Troops[i]);
        for k, v in pairs(self.Producers) do
            if v and v:IsAlive() and not QuestTools.IsInTable(Troops[i], v.Troops.Created) then
                if v.IsSpawner and v:IsInTypeList(TroopType) then
                    local x,y,z = Logic.EntityGetPos(v.ApproachPosition);
                    Logic.MoveSettler(Troops[i], x, y);
                    table.insert(v.Troops.Created, Troops[i]);
                    AiForceTroopIDToArmyID[Troops[i]] = nil;
                    table.remove(Troops, i);
                    break;
                elseif v.IsRecruiter and v:IsSuitableUnitType(TroopType) then
                    local x,y,z = Logic.EntityGetPos(v.ApproachPosition);
                    Logic.MoveSettler(Troops[i], x, y);
                    table.insert(v.Troops.Created, Troops[i]);
                    AiForceTroopIDToArmyID[Troops[i]] = nil;
                    table.remove(Troops, i);
                    break;
                end
            end
        end
    end
    -- destroy rest
    for i= table.getn(Troops), 1, -1 do
        AiForceTroopIDToArmyID[Troops[i]] = nil;
        DestroyEntity(Troops[i]);
    end
end

function AiForce:ProduceTroops()
    if self.IsRespawningArmy then
        local Spawner = self:GetSpawnerProducers();
        while (table.getn(Spawner) > 0 and table.getn(self.Troops) < self.TroopAmount)
        do
            local HasDelay = false;
            for i= table.getn(Spawner), 1, -1 do
                if Spawner[i].Delay > 0 then
                    HasDelay = true;
                end
                if table.getn(self.Troops) >= self.TroopAmount then
                    break;
                end
                Spawner[i]:CreateTroop(true, true);
                local ID = Spawner[i]:GetTroop();
                if ID > 0 then
                    self:AddEntity(ID, true);
                end
            end
            if HasDelay then
                break;
            end
        end
    elseif self.IsRecruitingArmy then
        for k, v in pairs(self.Producers) do
            if v and v:IsAlive() and table.getn(self.Troops) < self.TroopAmount then
                if QuestTools.SameSector(self.RalleyPoint, v.ApproachPosition) then
                    local ID = v:GetTroop();
                    if ID > 0 then
                        self:AddEntity(ID, false);
                    elseif ID == 0 then
                        if self:CountProducedTroops() < self.TroopAmount - table.getn(self.Troops) then
                            v:CreateTroop(false);
                        end
                    end
                end
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiForce:GetArmyOrientation()
    if table.getn(self.Troops) == 0 then
        return 0;
    else
        local ValueSum = 0;
        local Rotation = 0;
        for i= 1, table.getn(self.Troops), 1 do
            if Logic.IsLeader(self.Troops[i]) == 1 then
                local Soldiers = {Logic.GetSoldiersAttachedToLeader(self.Troops[i])};
                for j= 2, Soldiers[1]+1, 1 do
                    Rotation = Rotation + Logic.GetEntityOrientation(Soldiers[j]);
                    ValueSum = ValueSum + 1;
                end
            end
            Rotation = Rotation + Logic.GetEntityOrientation(self.Troops[i]);
            ValueSum = ValueSum + 1;
        end
        return Rotation / ValueSum;
    end
end

function AiForce:GetArmyBlockPositonMap(_Position)
    if self.ArmyFormationCache then
        return self.ArmyFormationCache;
    end
    local Position = _Position or self:GetPosition();
    if type(_Position) ~= "table" then
        Position = GetPosition(_Position);
    end
    local RowCount = 3;
    local Rotation = self:GetArmyOrientation() +180;
    local Distance = 500;

    local PositionMap = {};
    if table.getn(self.Troops) == 1 then
        PositionMap[self.Troops[1]] = Position;
    else
        local LeaderPerRow = math.ceil(table.getn(self.Troops)/RowCount);
        local getModLi = function(i)
            i = i -1;
            return -(math.floor(i/RowCount)-math.floor(LeaderPerRow/2)) * Distance
        end
        local getModRei = function(i)
            i = i -1;
            return (math.mod(i,RowCount)-math.floor(RowCount/2)) * Distance;
        end

        local Temp = {};
        for i= 1, table.getn(self.Troops), 1 do
            if Logic.IsHero(self.Troops[i]) == 1 then
                local Type = Logic.GetEntityType(self.Troops[i]);
                if Type == Entities.PU_Hero5 or Entities.PU_Hero10 then
                    table.insert(Temp, 1, self.Troops[i]);
                else
                    table.insert(Temp, self.Troops[i]);
                end
            elseif Logic.IsEntityInCategory(self.Troops[i], EntityCategories.Melee) == 1 then
                table.insert(Temp, self.Troops[i]);
            else
                table.insert(Temp, 1, self.Troops[i]);
            end
        end

        local n = table.getn(Temp);
        for i= 1, n do
            local FormationPos = QuestTools.GetCirclePosition(Position, getModLi(i), 0 + Rotation);
            FormationPos = QuestTools.GetCirclePosition(FormationPos, getModRei(i), 0 + Rotation + 270);
            FormationPos = QuestTools.GetReachablePosition(Temp[i], FormationPos);
            PositionMap[Temp[i]] = FormationPos;
        end
    end
    self.ArmyFormationCache = PositionMap;
    return PositionMap
end

function AiForce:MoveAsBlock(_Position, _Agressive, _Abort)
    if not _Abort and self:IsMoving() then
        return;
    end
    local ArmyPosition = self:GetPosition();
    local Position = _Position;
    if type(_Position) ~= "table" then
        Position = GetPosition(_Position);
    end
    local RowCount = self.TroopsPerLine or 3;
    local Rotation = self:GetArmyOrientation() -180;
    local Distance = 500;

    local PositionMap = self:GetArmyBlockPositonMap(Position);
    
    if table.getn(self.Troops) == 1 then
        local TroopPosition = PositionMap[self.Troops[1]];
        if not TroopPosition then
            TroopPosition = ArmyPosition;
        end
        if QuestTools.IsValidPosition(TroopPosition) then
            if _Agressive then
                Logic.GroupAttackMove(self.Troops[1], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
            else
                Logic.MoveSettler(self.Troops[1], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
            end
        end
    else
        for i= 1, table.getn(self.Troops), 1 do
            local TroopPosition = PositionMap[self.Troops[i]];
            if not TroopPosition then
                TroopPosition = ArmyPosition;
            end
            if QuestTools.IsValidPosition(TroopPosition) then
                if _Agressive then
                    Logic.GroupAttackMove(self.Troops[i], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
                else
                    Logic.MoveSettler(self.Troops[i], TroopPosition.X, TroopPosition.Y, 0 + Rotation);
                end
            end
        end
    end
end

function AiForce:TroopAttack(_ID, _target, _direct)
    if Logic.GetEntityHealth(_ID) > 0 then
        local type = Logic.GetEntityType(_ID);
        local command = Logic.LeaderGetCurrentCommand(_ID);
        local sight = Logic.GetEntityExplorationRange(_ID) * 100;
        local Pos = QuestTools.GetReachablePosition(_ID, _target);
        if Pos then
            if not _direct or AiForceMeleeTypeMap[type] then
                if command ~= 0 and command ~= 5 and command ~= 10 then
                    Logic.GroupAttackMove(_ID, Pos.X, Pos.Y);
                end
            else
                if AiForceVehicleTypeMap[type] and QuestTools.GetDistance(_ID, _target) > sight then
                    if command ~= 0 and command ~= 5 and command ~= 10 then
                        Logic.GroupAttackMove(_ID, Pos.X, Pos.Y);
                    end
                else
                    if command ~= 0 and command ~= 10 then
                        if AiForceVehicleTypeMap[type] and command ~= 5 then
                            Logic.GroupStand(_ID);
                        end
                        Logic.GroupAttack(_ID, _target);
                    end
                end
            end
        end
    end
end

function AiForce:IsMoving()
    for k,v in pairs(self.Troops) do
        if Logic.IsEntityInCategory(v, EntityCategories.Cannon) == 0 then
            if self:IsMemberMoving(v) then
                return true;
            end
        end
    end
    return false;
end

function AiForce:IsMemberMoving(_ID)
    return Logic.IsEntityMoving(_ID) == true;
end

function AiForce:IsBattling()
    for k,v in pairs(self.Troops) do
        if Logic.IsEntityInCategory(v, EntityCategories.Cannon) == 0 then
            if self:IsMemberBattling(v) then
                return true;
            end
        end
    end
    return false;
end

function AiForce:IsMemberBattling(_ID)
    if IsExisting(_target) and Logic.GetEntityHealth(_ID) > 0 then
        if not (string.sub(Logic.GetCurrentTaskList(_ID) or "", -5, -1)=="_IDLE") then
            local Command = Logic.LeaderGetCurrentCommand(_ID);
            if Command == 0 and Command == 5 and Command == 10 then
                return true;
            end
        end
    end
    return false;
end

function AiForce:GetPosition()
    if self.State ~= AiForceState.Refill then
        return QuestTools.GetGeometricFocus(unpack(self.Troops));
    end
    return GetPosition(self.RalleyPoint);
end

function AiForce:GetDistanceSqared(_Position1, _Position2)
    if (type(_Position1) == "string") or (type(_Position1) == "number") then
        _Position1 = GetPosition(_Position1);
    end
    if (type(_Position2) == "string") or (type(_Position2) == "number") then
        _Position2 = GetPosition(_Position2);
    end
    local xDistance = (_Position1.X - _Position2.X);
    local yDistance = (_Position1.Y - _Position2.Y);
    return ((_Position1.X - _Position2.X)^2) + ((_Position1.Y - _Position2.Y)^2);
end

function AiForce:IsNear(_pos, _distance)
    return QuestTools.GetDistance(self:GetPosition(), _pos) <= _distance;
end

function AiForce:IsPathBlocked()
    if self:GetPath() then
        local LookAhead = self:GetPath():CalculateLookAhead();
        if LookAhead == 0 then
            return -1;
        end
        return self:GetPath():GetNextBlockedNodeID(LookAhead);
    end
    return 0;
end

function AiForce:IsScattered()
    local ArmyPosition = self:GetPosition();
    for k,v in pairs(self.Troops) do
        if GetDistance(v,ArmyPosition) > self.OffenceArea then
            return true;
        end
    end
    return false;
end

-- -------------------------------------------------------------------------- --

function AiForce:GetTroopBaseSpeed(_ID)
    local Speed = 0;
    if not IsExisting(_ID) then
        return Speed;
    end
    for k, v in pairs(QuestTools.GetEntityCategoriesAsString(_ID)) do
        if AiForceUnitBaseSpeedMap[v] and Speed < AiForceUnitBaseSpeedMap[v] then
            Speed = AiForceUnitBaseSpeedMap[v];
        end
    end
    local TypeName = Logic.GetEntityTypeName(Logic.GetEntityType(_ID));
    Speed = AiForceUnitBaseSpeedMap[TypeName] or 0;
    return (Speed == 0 and 360) or Speed;
end

function AiForce:NormalizedArmySpeed()
    local TroopSpeed = 0;
    for i= 1, table.getn(self.Troops), 1 do
        TroopSpeed = TroopSpeed + self:GetTroopBaseSpeed(self.Troops[i]);
    end
    TroopSpeed = TroopSpeed / table.getn(self.Troops);
    for i= 1, table.getn(self.Troops), 1 do
        local Speed = self:GetTroopBaseSpeed(self.Troops[i]);
        self:SetTroopSpeed(self.Troops[i], TroopSpeed/Speed);
    end
end

function AiForce:ResetArmySpeed()
    for i= 1, table.getn(self.Troops), 1 do
        self:SetTroopSpeed(self.Troops[i], 1.0);
    end
end

function AiForce:SetTroopSpeed(_ID, _Factor)
    if IsExisting(_ID) and Logic.GetEntityHealth(_ID) > 0 then
        Logic.SetSpeedFactor(_ID, _Factor);
        if Logic.IsLeader(_ID) == 1 then
            local Soldiers = {Logic.GetSoldiersAttachedToLeader(_ID)};
            for i= 2, Soldiers[1]+1, 1 do
                if IsExisting(Soldiers[i]) and Logic.GetEntityHealth(Soldiers[i]) > 0 then
                    Logic.SetSpeedFactor(Soldiers[i], _Factor);
                end
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

function AiForce:TargetEnemies(_Position)
    local Enemies = self:GetEnemiesInArea(_Position, self.OffenceArea);
    local TargetMap = {};
    for k, v in pairs(self.Troops) do
        local sort = function(a, b)
            return self:GetEnemyThreat(a, v) < self:GetEnemyThreat(b, v);
        end
        table.sort(Enemies, sort);
        TargetMap[v] = Enemies[1] or 0;
    end
    return TargetMap;
end

function AiForce:GetEnemyThreat(_TroopID, _EnemyID)
    local TroopType = Logic.GetEntityType(_TroopID);
    local Distance = self:GetDistanceSqared(_TroopID, _EnemyID);
    local Priority = self:GetPriorityMap(_TroopID);
    
    local Factor = 1.0;
    for k, v in pairs(QuestTools.GetEntityCategories(_EnemyID)) do
        if Priority[v] then
            if Priority[v] > 0 then
                Factor = Factor * ((1/Priority[v]) or 1);
            else
                Factor = 0;
                break;
            end
        end
    end
    if Factor == 0 then
        return Logic.WorldGetSize() ^ 2;
    else
        return Distance * Factor;
    end
end

function AiForce:GetPriorityMap(_ID)
    local Type = Logic.GetEntityType(_ID);
    local Priority = AiForceTargetingPriorities.Cannon;
    if AiForceMeleeTypeMap[Type] then
        Priority = AiForceTargetingPriorities.Melee;
    end
    if AiForceRangedTypeMap[Type] then
        Priority = AiForceTargetingPriorities.Ranged;
    end
    return Priority;
end

-- -------------------------------------------------------------------------- --

function AiForce:AreEnemiesInArea(_Position, _Area)
    local Enemies = self:GetEnemiesInArea(_Position, _Area);
    return table.getn(Enemies) > 0;
end

function AiForce:AreEnemiesInAreaWithoutWalls(_Position, _Area)
    return QuestTools.AreEnemiesInArea(self.PlayerID, _Position, _Area);
end

function AiForce:GetEnemiesInArea(_Position, _Area)
    local Enemies = {};
    for i= 1, 8 do
        if i ~= self.PlayerID and Logic.GetDiplomacyState(i, self.PlayerID) == Diplomacy.Hostile then
            local tmp = {Logic.GetPlayerEntitiesInArea(i, 0, _Position.X, _Position.Y, _Area, 16)};
            for j=2, tmp[1], 1 do
                if self:IsProperTarget(tmp[j]) then
                    table.insert(Enemies, tmp[j]);
                end
            end
        end
    end
    return Enemies;
end

function AiForce:IsProperTarget(_EnemyID)
    if  IsExisting(_EnemyID)
    and Logic.GetEntityHealth(_EnemyID) > 0
    and (Logic.IsBuilding(_EnemyID) == 1 or Logic.IsSettler(_EnemyID) == 1)
    and Logic.IsEntityInCategory(_EnemyID, EntityCategories.Thief) == 0
    and (Logic.IsLeader(_EnemyID) == 1
         or (Logic.IsHero(_EnemyID) == 1 and Logic.GetCamouflageDuration(_EnemyID) == 0) 
         or Logic.IsEntityInCategory(_EnemyID, EntityCategories.MilitaryBuilding) == 1
         or Logic.IsEntityInCategory(_EnemyID, EntityCategories.Cannon) == 1
         or Logic.IsEntityInCategory(_EnemyID, EntityCategories.Soldier) == 1
         or Logic.IsEntityInCategory(_EnemyID, EntityCategories.Wall) == 1
    ) then
        return true;
    end
    return false;
end

function AiForce:GetWallSegment(_Position, _Area)
    for i= 1, 8 do
        if i ~= self.PlayerID and Logic.GetDiplomacyState(i, self.PlayerID) == Diplomacy.Hostile then
            local walls = {};
            for k,v in pairs(AiForceWallTypeList) do
                local tmp = {Logic.GetPlayerEntitiesInArea(i, v, _Position.X, _Position.Y, _Area, 16)};
                for j=2, tmp[1], 1 do
                    table.insert(walls, tmp[j]);
                end
            end

            if table.getn(walls) > 0 then
                local nearestDistance = Logic.WorldGetSize();
                local nearestEntity = 0;
                for j= 1, table.getn(walls) do
                    local distance = QuestTools.GetDistance(walls[i], nearestEntity);
                    if distance <= nearestDistance then
                        nearestDistance = distance;
                        nearestEntity = walls[i];
                    end
                end
                return nearestEntity;
            end
        end
    end
    return 0;
end

-- -------------------------------------------------------------------------- --

AiForceUnitBaseSpeedMap = {
    ["Bow"] = 320,
    ["CavalryLight"] = 500,
    ["CavalryHeavy"] = 500,
    ["Hero"] = 400,
    ["Rifle"] = 320,
    
    ["PV_Cannon1"] = 240,
    ["PV_Cannon2"] = 260,
    ["PV_Cannon3"] = 220,
    ["PV_Cannon4"] = 180,
};

AiForceTargetingPriorities = {
    Cannon = {
        [EntityCategories.MilitaryBuilding] = 1.0,
        [EntityCategories.EvilLeader] = 0.9,
        [EntityCategories.LongRange] = 0.5,
    },
    Ranged = {
        [EntityCategories.MilitaryBuilding] = 1.0,
        [EntityCategories.VillageCenter] = 0.6,
        [EntityCategories.Headquarters] = 0.6,
        [EntityCategories.LongRange] = 0.5,
        [EntityCategories.Hero] = 0.5,
        [EntityCategories.MilitaryBuilding] = 0.2,
    },
    Melee = {
        [EntityCategories.Hero] = 1.0,
        [EntityCategories.Cannon] = 1.0,
        [EntityCategories.LongRange] = 0.8,
        [EntityCategories.MilitaryBuilding] = 0.6,
        [EntityCategories.Melee] = 0.2,
    },
};

AiForceWallTypeList = {
    Entities.XD_DarkWallDistorted,
    Entities.XD_DarkWallStraight,
    Entities.XD_DarkWallStraightGate_Closed,
    Entities.XD_WallDistorted,
    Entities.XD_WallStraight,
    Entities.XD_WallStraightGate_Closed,
};

AiForceMeleeTypeMap = {
    [Entities.CU_AggressiveWolf] = true,
    [Entities.CU_BanditLeaderSword1] = true,
    [Entities.CU_BanditLeaderSword2] = true,
    [Entities.CU_Barbarian_LeaderClub1] = true,
    [Entities.CU_Barbarian_LeaderClub2] = true,
    [Entities.CU_BlackKnight_LeaderMace1] = true,
    [Entities.CU_BlackKnight_LeaderMace2] = true,
    [Entities.CU_Evil_LeaderBearman1] = true,
    [Entities.CU_VeteranCaptain] = true,
    [Entities.CU_VeteranLieutenant] = true,
    [Entities.CU_VeteranMajor] = true,
    [Entities.PU_BattleSerf] = true,
    [Entities.PU_LeaderHeavyCavalry1] = true,
    [Entities.PU_LeaderHeavyCavalry2] = true,
    [Entities.PU_LeaderPoleArm1] = true,
    [Entities.PU_LeaderPoleArm2] = true,
    [Entities.PU_LeaderPoleArm3] = true,
    [Entities.PU_LeaderPoleArm4] = true,
    [Entities.PU_LeaderSword1] = true,
    [Entities.PU_LeaderSword2] = true,
    [Entities.PU_LeaderSword3] = true,
    [Entities.PU_LeaderSword4] = true,
    [Entities.PU_Scout] = true,
    [Entities.PU_Thief] = true,
    -- Heroes (not supported)
    [Entities.CU_Barbarian_Hero] = true,
    [Entities.CU_BlackKnight] = true,
    [Entities.CU_Evil_Queen] = true,
    [Entities.CU_Mary_de_Mortfichet] = true,
    [Entities.PU_Hero1] = true,
    [Entities.PU_Hero11] = true,
    [Entities.PU_Hero1a] = true,
    [Entities.PU_Hero1b] = true,
    [Entities.PU_Hero1c] = true,
    [Entities.PU_Hero2] = true,
    [Entities.PU_Hero3] = true,
    [Entities.PU_Hero4] = true,
    [Entities.PU_Hero6] = true,
}

AiForceRangedTypeMap = {
    [Entities.CU_BanditLeaderBow1] = true,
    [Entities.CU_Evil_LeaderSkirmisher1] = true,
    [Entities.PU_LeaderBow1] = true,
    [Entities.PU_LeaderBow2] = true,
    [Entities.PU_LeaderBow3] = true,
    [Entities.PU_LeaderBow4] = true,
    [Entities.PU_LeaderCavalry1] = true,
    [Entities.PU_LeaderCavalry2] = true,
    [Entities.PU_LeaderRifle1] = true,
    [Entities.PU_LeaderRifle2] = true,
    -- Heroes (not supported)
    [Entities.PU_Hero10] = true,
    [Entities.PU_Hero5] = true,
}

AiForceVehicleTypeMap = {
    [Entities.PV_Cannon1] = true,
    [Entities.PV_Cannon2] = true,
    [Entities.PV_Cannon3] = true,
    [Entities.PV_Cannon4] = true,
}