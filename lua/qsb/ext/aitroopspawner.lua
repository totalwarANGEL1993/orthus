-- ########################################################################## --
-- #  AI Troop Recruiter                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --




function CreateTroopGenerator(_Data)
    if not AiTroopSpawnerList[_Data.ScriptName] then
        new(AiTroopSpawner, _Data.ScriptName);
        local Spawner = GetTroopGenerator(_Data.ScriptName);
        Spawner:SetDelay(_Data.Delay or 90);
        if _Data.Spawnpoint then
            Spawner:SetApproachPosition(GetPosition(_Data.Spawnpoint));
        end
        if _Data.Limit then
            Spawner:SetMaxTroops(_Data.Limit);
        end
        for i= 1, table.getn(_Data.Types), 1 do
            Spawner:AddType(_Data.Types[i][1], _Data.Types[i][2]);
        end
    end
    return AiTroopSpawnerList[_Data.ScriptName];
end

function DropTroopGenerator(_ScriptName)
    if AiTroopSpawnerList[_ScriptName] then
        AiTroopSpawnerList[_ScriptName] = nil;
    end
end

function GetTroopGenerator(_ScriptName)
    if AiTroopSpawnerList[_ScriptName] then
        return AiTroopSpawnerList[_ScriptName];
    end
end

-- -------------------------------------------------------------------------- --

AiTroopSpawner = {
    ScriptName = nil,
    LastRecruitedTime = 0,
    Delay = 30,
    Troops = {
        Maximum = 999,
        Selector = function(self)
            local Size = table.getn(self.Troops.Types);
            return self.Troops.Types[math.random(1, Size)];
        end,
        Types = {},
        Created = {},
    },
}

AiTroopSpawnerList = {};

function AiTroopSpawner:construct(_ScriptName)
    self.ScriptName = _ScriptName;
    self:Initalize();
    AiTroopSpawnerList[_ScriptName] = self;
end;
class(AiTroopSpawner);

function AiTroopSpawner:Initalize()
    if not self.Initalized then
        self.Initalized = true;
        
        -- Save approach position
        local Position = GetPosition(self.ScriptName);
        local ID = AI.Entity_CreateFormation(8, Entities.PU_Serf, 0, 0, Position.X, Position.Y, 0, 0, 0, 0);
        self.ApproachPosition = GetPosition(ID);
        DestroyEntity(ID);
    end
end

function AiTroopSpawner:IsAlive()
    return IsExisting(self.ScriptName);
end

function AiTroopSpawner:AddType(_Type, _Exp)
    table.insert(self.Troops.Types, {_Type, _Exp});
    return self;
end

function AiTroopSpawner:ClearTypes()
    self.Troops.Types = {};
    return self;
end

function AiTroopSpawner:SetApproachPosition(_Position)
    self.ApproachPosition = _Position;
    return self;
end

function AiTroopSpawner:SetMaxTroops(_Max)
    self.Troops.Maximum = _Max;
    return self;
end

function AiTroopRecruiter:SetDelay(_Time)
    self.Delay = _Time;
    return self;
end

function AiTroopSpawner:IsReady()
    if self.ScriptName and IsExisting(self.ScriptName) then
        if Logic.GetTime() > self.LastRecruitedTime + self.Delay then
            if table.getn(self.Troops.Created) < self.Troops.Maximum then
                return true;
            end
        end
    end
    return false;
end

function AiTroopSpawner:GetTroop()
    for i= table.getn(self.Troops.Created), 1, -1 do
        if IsExisting(self.Troops.Created[i]) then
            return table.remove(self.Troops.Created, i);
        else
            table.remove(self.Troops.Created, i);
        end
    end
    return 0;
end

function AiTroopSpawner:CreateTroop(_IgnoreCreated)
    if self:IsReady() then
        if table.getn(self.Troops.Created) == 0 or _IgnoreCreated then
            if table.getn(self.Troops.Types) > 0 then
                local TroopType = self.Troops.Selector(self);
                local ID = GetID(self.ScriptName);
                local PlayerID = Logic.EntityGetPlayer(ID);
                local Position = self.ApproachPosition;

                local TroopID = AI.Entity_CreateFormation(
                    PlayerID,
                    TroopType[1],
                    0,
                    16,
                    Position.X,
                    Position.Y,
                    0,
                    0,
                    TroopType[2] or 0,
                    16
                );
                table.insert(self.Troops.Created, TroopID);
                self.LastRecruitedTime = Logic.GetTime();
            end
        end
    end
end

