-- ########################################################################## --
-- #  AiPath                                                                # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- Module for creating paths between positions.
--
-- Paths can be created from a list of checkpoints or found by an implementation
-- of the dijkstra algorithm . Searching paths takes some time. On maps with
-- average size the algorithm  has an average search time of 1 second per path.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.lib.oop</li>
-- <li>qsb.lib.quest.questsync</li>
-- <li>qsb.lib.quest.questtools</li>
-- </ul>
--
-- @set sort=true
--

-- -------------------------------------------------------------------------- --

---
-- Creates a path from the passed checkpoints.
--
-- Good old Dijkstra is not involved.
--
-- @param[type=string] ... List of Checkopoints
-- @return[type=AiPathModel] Path
--
function CreatePathFromCheckpoints(...)
    return AiPathModel:CreatePathFromWaypointList(arg);
end

---
-- Merges all passed paths into one path and returns a new path.
--
-- @param[type=AiPathModel] ... List of Paths
-- @return[type=AiPathModel] Path
--
function MergePaths(...)
    local Path = new(AiPathModel);
    for i= 1, table.getn(arg), 1 do
        Path:Merge(arg[i]);
    end
    return Path;
end

---
-- Tries to connect all passed positions in a path. Between the positions the
-- pathing algorithm searches the connection.
--
-- If no way can be found the function returns nil.
--
-- <b>Note:</b> This function might take some time to execute. You should use
-- it at start of the map and conceal the time behind the load screen.
--
-- @param[type=string] ... List of Positions
-- @return[type=AiPathModel] Path
--
function FindPathBetween(...)
    Path = QuestTools.SaveCall{
        ErrorHandler = function() return nil; end,
        FindPathBetweenInternal, unpack(arg)
    };
    return Path;
end

function FindPathBetweenInternal(...)
    local Positions = {};
    for i= 1, table.getn(arg), 1 do
        if not QuestTools.IsInTable(arg[i], Positions) then
            table.insert(Positions, arg[i]);
        end
    end
    if table.getn(Positions) < 2 then
        assert(false, "GetPathBetween: At least 2 positions needed."); 
    end
    local Path = nil;
    local PathFinder = new(AiPath);
    local Start = 1;
    local End   = 2;
    while (Start ~= table.getn(Positions))
    do
        if not PathFinder:FindPath(Positions[Start], Positions[End], 1) then
            assert(false, "GetPathBetween: Unable to find path between position " ..Start.. " and " ..End.. "!"); 
            return;
        end
        local PathSegment = PathFinder:GetPath();
        if not Path then
            Path = PathSegment;
        else
            Path:Merge(PathSegment);
        end
        Start = Start +1;
        End = End +1;
    end
    Path = Path:Reduce(16);
    return Path;
end

-- -------------------------------------------------------------------------- --

AiPath = {
    Debug     = false,
    Path      = nil,
    NodeMap   = {},
    Open	  = {},
    OpenMap	  = {},
    ClosedMap = {},
}

---
-- Constructor
-- @usage Instance = new(AiPath);
-- @within AiPath
--
function AiPath:construct()
end
class(AiPath);

function AiPath:ClearPath()
    self.Path    = nil;
    self.NodeMap = {};
end

---
-- Returns the last found path
--
-- @return[type=AiPathModel] Path
-- @within AiPath
--
function AiPath:GetPath()
    if self.Path then
        return copy(self.Path);
    end
end

---
-- Start pathfinding between begin and end position. If path is found the
-- function returns true.
--
-- Nodes can be ignored with the _Accept function.
--
-- @param[type=string]   _Begin  Start of path
-- @param[type=string]   _End    End of path
-- @param[type=function] _Accept (Optional) Node filter function
-- @param                ...     parameters for node filter
-- @within AiPath
--
function AiPath:FindPath(_Begin, _End, _Accept, ...)
    self:ClearPath();
    self.StartNode = _End
    self.TargetNode = _Begin
    self.Closed = {};
    self.ClosedMap = {};
    self.Open = {};
    self.OpenMap = {};
    self.AcceptMethode = _Accept;
    self.AcceptArgs = copy(arg);

    _Begin = self:GetClosestPosition(_Begin);
    if not _Begin then
        return false;
    end
    _End = self:GetClosestPosition(_End);
    if not _End then
        return false;
    end

    local path = {}
    local lastNode = self:FindPathLoop(_Begin, _End);
    if lastNode then
        local path = {}
        local prev = self:GetNodeByID(lastNode.Father);
        while (prev)
        do
            table.insert(path, copy(prev));
            local tmp = lastNode.Father;
            lastNode = prev;
            prev = self:GetNodeByID(tmp);
        end
        self.Path = new(AiPathModel, path);
        return true;
    end
    return false;
end

function AiPath:FindPathLoop(_Start, _Target)
    _Start.ID = "ID_".._Start.X.."_".._Start.Y
    table.insert(self.Open, 1, _Start);
    self.OpenMap[_Start.ID] = true;
    repeat
        local removed = table.remove(self.Open, 1);
        self.OpenMap[removed.ID] = nil;
        if removed.X == _Target.X and removed.Y == _Target.Y then
            return removed;
        end
        self:Expand(removed, _Target);
    until (table.getn(self.Open) == 0);
    return nil;
end

function AiPath:Expand(_Node, _Target)
    local x = _Node.X;
    local y = _Node.Y;

    -- Regular nodes
    local father = _Node.ID;
    local sucessors = {};
    for i= x-500, x+500, 500 do
        for j= y-500, y+500, 500 do
            if not (i == x and j == y) then
                if not self.OpenMap["ID_"..i.."_"..j] and not self.ClosedMap["ID_"..i.."_"..j] then
                    local tmp = Logic.CreateEntity(Entities.XD_ScriptEntity, i, j, 0, 8);
                    local sec = Logic.GetSector(tmp);
                    DestroyEntity(tmp);
                    if sec ~= 0 then
                        table.insert(sucessors, {
                            ID = "ID_"..i.."_"..j,
                            X= i,
                            Y= j,
                            Father = father,
                            Distance1 = GetDistance(_Node, self.TargetNode),
                            Distance2 = GetDistance(self.StartNode, _Node)
                        });
                    elseif math.abs(self:GetHeight(x,y) - self:GetHeight(i,j)) < 150 then
                        if self:IsWallNear(i, j) then
                            local blockingEntity;
                            for k,v in pairs(AiPathBlockingDoodads) do
                                local n = Logic.GetEntitiesInArea(k, i, j, v, 16);
                                if n > 0 then
                                    blockingEntity = true;
                                    break;
                                end
                            end
                            if not blockingEntity then
                                table.insert(sucessors, {
                                    ID = "ID_"..i.."_"..j,
                                    X= i,
                                    Y= j,
                                    Father = father,
                                    Distance1 = GetDistance(_Node, self.TargetNode),
                                    Distance2 = GetDistance(self.StartNode, _Node)
                                });
                            end
                        end
                    end
                end
            end
        end
    end

    -- Check successor nodes and put into open list
    for k,v in pairs(sucessors) do
        if not self.Closed["ID_"..v.X.."_"..v.Y] then
            if not self.Open["ID_"..v.X.."_"..v.Y] then
                local useNode = true;
                if self.AcceptMethode then
                    useNode = self.AcceptMethode(v, unpack(self.AcceptArgs))
                end
                if useNode then
                    table.insert(self.Open, v);
                    self.OpenMap[v.ID] = true;
                end
            end
        end
    end

    -- Sort open list
    local comp = function(v,w)
        return v.Distance1 < w.Distance1 and v.Distance2 < w.Distance2;
    end
    table.sort(self.Open, comp);

    -- Insert current node to closed list
    table.insert(self.Closed, _Node);
    self.OpenMap[_Node.ID] = true;
end

function AiPath:GetClosestPosition(_Position)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    local bx = math.floor((_Position.X/1000) + 0.5) * 1000;
    local by = math.floor((_Position.Y/1000) + 0.5) * 1000;
    for x= -500, 500, 500 do
        for y= -500, 500, 500 do
            local tmp = Logic.CreateEntity(Entities.XD_ScriptEntity, bx+x, by+y, 0, 8);
            local sec = Logic.GetSector(tmp);
            DestroyEntity(tmp);
            if sec ~= 0 then
                return {X= bx+x, Y= by+y};
            end
        end
    end
end

function AiPath:GetHeight(_X, _Y)
    if IsValidPosition{X= _X, Y= _Y} then
        local tmp = Logic.CreateEntity(Entities.XD_ScriptEntity, _X, _Y, 0, 8);
        local x,y,z = Logic.EntityGetPos(tmp);
        DestroyEntity(tmp);
        return z;
    end
    return 0;
end

function AiPath:IsWallNear(_X, _Y)
    for i=1,8 do
        if Logic.IsPlayerEntityOfCategoryInArea(i, _X, _Y, 500, "Wall") == 1 then
            return true;
        end
    end
    return false;
end

function AiPath:GetNodeByID(_ID)
    local node;
    for i=1, table.getn(self.Closed) do
        if self.Closed[i].ID == _ID then
            node = self.Closed[i];
        end
    end
    return node;
end

-- - Path ------------------------------------------------------------------- --

AiPathModel = {
    m_Nodes = {};
};

---
-- Constructor
--
-- @within AiPathModel
-- @usage Instance = new(AiPathModel);
--
function AiPathModel:construct(_Nodes)
    if _Nodes then
        self.m_Nodes = copy(_Nodes);
    end
end

class(AiPathModel);

function AiPathModel:CreatePathFromWaypointList(_List)
    local path = new(AiPathModel, {});
    local father = nil;
    for i= 1, table.getn(_List), 1 do
        local ID = GetID(_List[i]);
        local x,y,z = Logic.EntityGetPos(ID);
        table.insert(path.m_Nodes, {
            ID        = "ID_" .._List[i],
            Marker    = 0,
            Father    = father,
            Visited   = false,
            X         = x,
            Y         = y,
            Distance1 = 0,
            Distance2 = 0,
        });
        father = "ID_" ..ID;
    end
    return path;
end

function AiPathModel:AddNode(_Node)
    local Node = copy(_Node);
    local n = table.getn(self.m_Nodes);
    if n > 1 then
        Node.Father = self.m_Nodes[n-1].ID;
    else
        Node.Father = nil;
    end
    table.insert(self.m_Nodes, Node);
end

---
-- Merges another path into the current path.
--
-- @param[type=AiPathModel] _Other Path to merge
-- @within AiPathModel
--
function AiPathModel:Merge(_Other)
    if _Other and table.getn(_Other.m_Nodes) > 0 then
        if table.getn(_Other.m_Nodes) == 0 then
            self.m_Nodes = copy(_Other.m_Nodes);
        else
            local other = copy(_Other.m_Nodes);
            other[1].Father = self.m_Nodes[table.getn(self.m_Nodes)].ID;
            for i= 1, table.getn(other), 1 do
                table.insert(self.m_Nodes, copy(other[i]));
            end
        end
    end
end

---
-- Reduces the path by the given factor and returns it as clone of the instance.
--
-- @param[type=number] _By Factor to reduce
-- @return[type=AiPathModel] Path
-- @within AiPathModel
--
function AiPathModel:Reduce(_By)
    local Reduced = copy(self);
    local n = table.getn(Reduced.m_Nodes);
    for i= n, 1, -1 do
        if i ~= 1 and i ~= n and math.mod(i, _By) ~= 0 then
            Reduced.m_Nodes[i+1].Father = Reduced.m_Nodes[i-1].Father;
            table.remove(Reduced.m_Nodes, i);
        end
    end
    return Reduced;
end

---
-- Resets the path so that all noces are not visited.
-- @within AiPathModel
--
function AiPathModel:Reset()
    for k,v in pairs(self.m_Nodes) do
        self.m_Nodes[k].Visited = false;
    end
end

function AiPathModel:Reverse()
    local Reversed = new(AiPathModel);
    for i= table.getn(self.m_Nodes), 1, -1 do
        Reversed:AddNode(self.m_Nodes[i]);
    end
    return Reversed;
end

---
-- Marks the current node as visited.
-- @within AiPathModel
--
function AiPathModel:Next()
    local Node, ID = self:GetCurrentWaypoint();
    if Node then
        self.m_Nodes[ID].Visited = true;
    end
end

---
-- Creates an script entity for each node and returns them as list.
-- @return[type=table] Path
-- @within AiPathModel
--
function AiPathModel:Convert()
    if self.m_Nodes then
        local nodes = {};
        for k,v in pairs(self.m_Nodes) do
            local eID = Logic.CreateEntity(Entities.XD_ScriptEntity, self.m_Nodes.X, self.m_Nodes.Y, 0, 8);
            table.insert(nodes, eID);
        end
        return nodes;
    end
end

---
-- Returns the current node and the index of the node.
-- @return[type=table]  Current node
-- @return[type=number] Index
-- @within AiPathModel
--
function AiPathModel:GetCurrentWaypoint()
    local lastWP;
    local id = 1;
    repeat
        lastWP = self.m_Nodes[id];
        id = id +1;
    until ((not self.m_Nodes[id]) or self.m_Nodes[id].Visited == false);
    if not self.m_Nodes[id] then
        id = id -1;
    end
    return lastWP, id;
end

---
-- Looks n nodes ahead if the path is blocked. Returns an offset index from the
-- first blocked node after the current node. If the path is not blocked 0 is
-- returned instead.
-- 
-- @param[type=number] _By Factor to reduce
-- @return[type=number] Blocked node offset
-- @within AiPathModel
--
function AiPathModel:GetNextBlockedNodeID(_Limit)
    local currentWP, id = self:GetCurrentWaypoint();
    for i= 2, _Limit, 1 do
        if self.m_Nodes[id+i] then
            local nextWP = self.m_Nodes[id+i];
            if not QuestTools.SameSector(currentWP, nextWP) then
                return id+i;
            end
        end
    end
    return 0;
end

---
-- Returns how many nodes must be looked ahead to correctly react to walls.
-- If there are to few nodes in the path 0 is returned.
-- @return[type=number] Blocked node offset
-- @within AiPathModel
--
function AiPathModel:CalculateLookAhead()
    local AverageDistance = self:GetAverageDistance();
    return Round(3500/AverageDistance);
end

---
-- Returns the average distance between all nodes.
-- @return[type=number] Blocked node offset
-- @within AiPathModel
--
function AiPathModel:GetAverageDistance()
    local SumOfDistances = 0;
    for i= 1, table.getn(self.m_Nodes), 1 do
        if not self.m_Nodes[i+1] then
            break;
        end
        SumOfDistances = SumOfDistances + QuestTools.GetDistance(self.m_Nodes[i], self.m_Nodes[i+1]);
    end
    return SumOfDistances / table.getn(self.m_Nodes);
end

---
-- Displays the nodes by creating XD_Sparkles at their position.
-- @within AiPathModel
--
function AiPathModel:Show()
    for k, v in pairs(self.m_Nodes) do
        DestroyEntity(self.m_Nodes[k].Marker);
        local ID = Logic.CreateEntity(Entities.XD_Sparkles, v.X, v.Y, 0, 0);
        self.m_Nodes[k].Marker = ID;
    end
end

---
-- Removes all node markers from the map.
-- @within AiPathModel
--
function AiPathModel:Hide()
    for k, v in pairs(self.m_Nodes) do
        DestroyEntity(self.m_Nodes[k].Marker);
        self.m_Nodes[k].Marker = 0;
    end
end

-- - Data ------------------------------------------------------------------- --

AiPathBlockingDoodads = {
    [Entities.XD_AppleTree1] = 200,
    [Entities.XD_AppleTree2] = 200,
    [Entities.XD_CherryTree] = 200,
    [Entities.XD_ChestClose] = 200,
    [Entities.XD_ChestOpen] = 200,
    [Entities.XD_ChestOrb] = 200,
    [Entities.XD_Clay1] = 300,
    [Entities.XD_ClayPit1] = 900,
    [Entities.XD_Cliff1] = 500,
    [Entities.XD_Cliff2] = 700,
    [Entities.XD_CliffBright5] = 300,
    [Entities.XD_CliffBright4] = 400,
    [Entities.XD_CliffBright3] = 500,
    [Entities.XD_CliffBright2] = 800,
    [Entities.XD_CliffBright1] = 1000,
    [Entities.XD_CliffEvelance5] = 300,
    [Entities.XD_CliffEvelance4] = 400,
    [Entities.XD_CliffEvelance3] = 500,
    [Entities.XD_CliffEvelance3] = 800,
    [Entities.XD_CliffEvelance2] = 1000,
    [Entities.XD_CliffGrey1] = 500,
    [Entities.XD_CliffGrey2] = 700,
    [Entities.XD_CliffMoor5] = 300,
    [Entities.XD_CliffMoor4] = 400,
    [Entities.XD_CliffMoor3] = 500,
    [Entities.XD_CliffMoor2] = 800,
    [Entities.XD_CliffMoor1] = 1000,
    [Entities.XD_CliffTideland5] = 300,
    [Entities.XD_CliffTideland4] = 400,
    [Entities.XD_CliffTideland3] = 500,
    [Entities.XD_CliffTideland2] = 800,
    [Entities.XD_CliffTideland1] = 1000,
    [Entities.XD_CliffTidelandShadows5] = 300,
    [Entities.XD_CliffTidelandShadows4] = 400,
    [Entities.XD_CliffTidelandShadows3] = 500,
    [Entities.XD_CliffTidelandShadows2] = 800,
    [Entities.XD_CliffTidelandShadows1] = 1000,
    [Entities.XD_ClosedClayPit1] = 900,
    [Entities.XD_ClosedIronPit1] = 900,
    [Entities.XD_ClosedStonePit1] = 900,
    [Entities.XD_ClosedSulfurPit1] = 900,
    [Entities.XD_Cypress1] = 200,
    [Entities.XD_Cypress2] = 200,
    [Entities.XD_DarkTree1] = 200,
    [Entities.XD_DarkTree2] = 200,
    [Entities.XD_DarkTree3] = 200,
    [Entities.XD_DarkTree4] = 200,
    [Entities.XD_DarkTree5] = 200,
    [Entities.XD_DarkTree6] = 200,
    [Entities.XD_DarkTree7] = 200,
    [Entities.XD_DarkTree8] = 200,
    [Entities.XD_DeadTree01] = 200,
    [Entities.XD_DeadTree02] = 200,
    [Entities.XD_DeadTree03] = 200,
    [Entities.XD_DeadTree04] = 200,
    [Entities.XD_DeadTree05] = 200,
    [Entities.XD_DeadTree06] = 200,
    [Entities.XD_DeadTreeEvelance1] = 300,
    [Entities.XD_DeadTreeEvelance2] = 300,
    [Entities.XD_DeadTreeEvelance3] = 300,
    [Entities.XD_DeadTreeMoor1] = 300,
    [Entities.XD_DeadTreeMoor2] = 300,
    [Entities.XD_DeadTreeMoor3] = 300,
    [Entities.XD_DeadTreeNorth1] = 200,
    [Entities.XD_DeadTreeNorth2] = 200,
    [Entities.XD_DeadTreeNorth3] = 200,
    [Entities.XD_Evil_Camp01] = 400,
    [Entities.XD_Evil_Camp02] = 400,
    [Entities.XD_Evil_Camp03] = 400,
    [Entities.XD_Evil_Camp04] = 400,
    [Entities.XD_Evil_Camp05] = 400,
    [Entities.XD_Evil_Camp06] = 400,
    [Entities.XD_Evil_Camp07] = 400,
    [Entities.XD_Fir1] = 200,
    [Entities.XD_Fir1_small] = 200,
    [Entities.XD_Fir2] = 200,
    [Entities.XD_Fir2_small] = 200,
    [Entities.XD_GeyserEvelance1] = 300,
    [Entities.XD_Grave1] = 200,
    [Entities.XD_GraveComplete1] = 400,
    [Entities.XD_GraveComplete2] = 400,
    [Entities.XD_GraveComplete3] = 400,
    [Entities.XD_GraveComplete4] = 400,
    [Entities.XD_GraveComplete5] = 400,
    [Entities.XD_GraveComplete6] = 400,
    [Entities.XD_GraveComplete7] = 400,
    [Entities.XD_Iron1] = 900,
    [Entities.XD_IronGrid1] = 500,
    [Entities.XD_IronGrid2] = 500,
    [Entities.XD_IronGrid3] = 500,
    [Entities.XD_IronGrid4] = 500,
    [Entities.XD_IronPit1] = 900,
    [Entities.XD_LargeCampFire] = 200,
    [Entities.XD_MiscBank1] = 200,
    [Entities.XD_MiscBarrel1] = 200,
    [Entities.XD_MiscBarrel2] = 200,
    [Entities.XD_MiscBox1] = 200,
    [Entities.XD_MiscBox2] = 200,
    [Entities.XD_MiscChest1] = 200,
    [Entities.XD_MiscChest2] = 200,
    [Entities.XD_MiscChest3] = 200,
    [Entities.XD_MiscHaybale1] = 200,
    [Entities.XD_MiscHaybale2] = 200,
    [Entities.XD_MiscHaybale3] = 200,
    [Entities.XD_MiscPile1] = 200,
    [Entities.XD_MiscQuiver1] = 200,
    [Entities.XD_MiscSack1] = 200,
    [Entities.XD_MiscSack2] = 200,
    [Entities.XD_MiscSmallSack1] = 200,
    [Entities.XD_MiscSmallSack2] = 200,
    [Entities.XD_MiscSmallSack3] = 200,
    [Entities.XD_MiscTable1] = 300,
    [Entities.XD_MiscTable2] = 300,
    [Entities.XD_MiscTent1] = 300,
    [Entities.XD_MiscTrolley1] = 300,
    [Entities.XD_MiscTrolley2] = 300,
    [Entities.XD_MiscTrolley3] = 300,
    [Entities.XD_OliveTree1] = 300,
    [Entities.XD_OliveTree2] = 300,
    [Entities.XD_OrangeTree1] = 200,
    [Entities.XD_OrangeTree2] = 200,
    [Entities.XD_Pine1] = 200,
    [Entities.XD_Pine2] = 200,
    [Entities.XD_Pine3] = 200,
    [Entities.XD_Pine4] = 200,
    [Entities.XD_Pine5] = 200,
    [Entities.XD_Pine6] = 200,
    [Entities.XD_PineNorth1] = 200,
    [Entities.XD_PineNorth2] = 200,
    [Entities.XD_PineNorth3] = 200,
    [Entities.XD_Rock3] = 200,
    [Entities.XD_Rock4] = 300,
    [Entities.XD_Rock5] = 400,
    [Entities.XD_Rock6] = 500,
    [Entities.XD_Rock7] = 600,
    [Entities.XD_RockDarkEvelance3] = 200,
    [Entities.XD_RockDarkEvelance4] = 300,
    [Entities.XD_RockDarkEvelance5] = 400,
    [Entities.XD_RockDarkEvelance6] = 500,
    [Entities.XD_RockDarkEvelance7] = 600,
    [Entities.XD_RockDarkMoor3] = 200,
    [Entities.XD_RockDarkMoor4] = 300,
    [Entities.XD_RockDarkMoor5] = 400,
    [Entities.XD_RockDarkMoor6] = 500,
    [Entities.XD_RockDarkMoor7] = 600,
    [Entities.XD_RockDestroyableMedium1] = 600,
    [Entities.XD_RockGrass2] = 400,
    [Entities.XD_RockGrass3] = 400,
    [Entities.XD_RockGrass4] = 400,
    [Entities.XD_RockGrass5] = 400,
    [Entities.XD_RockKhakiBright3] = 200,
    [Entities.XD_RockKhakiBright4] = 300,
    [Entities.XD_RockKhakiBright5] = 400,
    [Entities.XD_RockKhakiBright6] = 500,
    [Entities.XD_RockKhakiBright7] = 600,
    [Entities.XD_RockKhakiMedium3] = 200,
    [Entities.XD_RockKhakiMedium4] = 300,
    [Entities.XD_RockKhakiMedium5] = 400,
    [Entities.XD_RockKhakiMedium6] = 500,
    [Entities.XD_RockKhakiMedium7] = 600,
    [Entities.XD_RockMedium3] = 200,
    [Entities.XD_RockMedium4] = 300,
    [Entities.XD_RockMedium5] = 400,
    [Entities.XD_RockMedium6] = 500,
    [Entities.XD_RockMedium7] = 600,
    [Entities.XD_RockNorth1] = 200,
    [Entities.XD_RockNorth2] = 300,
    [Entities.XD_RockNorth3] = 400,
    [Entities.XD_RockNorth4] = 500,
    [Entities.XD_RockTideland3] = 200,
    [Entities.XD_RockTideland4] = 300,
    [Entities.XD_RockTideland5] = 400,
    [Entities.XD_RockTideland6] = 500,
    [Entities.XD_RockTideland7] = 600,
    [Entities.XD_RockTidelandGreen1] = 200,
    [Entities.XD_RockTidelandGreen2] = 300,
    [Entities.XD_RockTidelandGreen3] = 400,
    [Entities.XD_RockTidelandGreen4] = 500,
    [Entities.XD_RockTidelandGreen5] = 600,
    [Entities.XD_RuinFragment1] = 300,
    [Entities.XD_RuinFragment2] = 300,
    [Entities.XD_RuinFragment3] = 300,
    [Entities.XD_RuinFragment4] = 300,
    [Entities.XD_RuinFragment5] = 300,
    [Entities.XD_RuinFragment6] = 300,
    [Entities.XD_RuinHouse1] = 1000,
    [Entities.XD_RuinHouse2] = 1000,
    [Entities.XD_RuinMonastery1] = 1300,
    [Entities.XD_RuinMonastery2] = 1300,
    [Entities.XD_RuinResidence1] = 600,
    [Entities.XD_RuinResidence2] = 600,
    [Entities.XD_RuinSmallTower1] = 400,
    [Entities.XD_RuinSmallTower2] = 400,
    [Entities.XD_RuinSmallTower3] = 400,
    [Entities.XD_RuinSmallTower4] = 400,
    [Entities.XD_RuinTower1] = 200,
    [Entities.XD_RuinTower2] = 200,
    [Entities.XD_Signpost1] = 200,
    [Entities.XD_Signpost2] = 200,
    [Entities.XD_Signpost3] = 200,
    [Entities.XD_SingnalFireOff] = 300,
    [Entities.XD_SingnalFireOn] = 300,
    [Entities.XD_Stone1] = 200,
    [Entities.XD_StonePit1] = 900,
    [Entities.XD_Stone_BlockPath] = 200,
    [Entities.XD_Sulfur1] = 900,
    [Entities.XD_SulfurPit1] = 200,
    [Entities.XD_TemplarAltar] = 200,
    [Entities.XD_Tomb1] = 200,
    [Entities.XD_Tomb2] = 200,
    [Entities.XD_Tomb3] = 200,
    [Entities.XD_Tomb4] = 200,
    [Entities.XD_Tomb5] = 200,
    [Entities.XD_Tomb6] = 200,
    [Entities.XD_Tomb7] = 200,
    [Entities.XD_Tomb8] = 200,
    [Entities.XD_Torch] = 200,
    [Entities.XD_Tree1] = 200,
    [Entities.XD_Tree1_small] = 200,
    [Entities.XD_Tree2] = 200,
    [Entities.XD_Tree2_small] = 200,
    [Entities.XD_Tree3] = 200,
    [Entities.XD_Tree3_small] = 200,
    [Entities.XD_Tree4] = 200,
    [Entities.XD_Tree5] = 200,
    [Entities.XD_Tree6] = 200,
    [Entities.XD_Tree7] = 200,
    [Entities.XD_Tree8] = 200,
    [Entities.XD_TreeEvelance1] = 300,
    [Entities.XD_TreeMoor1] = 300,
    [Entities.XD_TreeMoor2] = 300,
    [Entities.XD_TreeMoor3] = 300,
    [Entities.XD_TreeMoor4] = 300,
    [Entities.XD_TreeMoor5] = 300,
    [Entities.XD_TreeMoor6] = 300,
    [Entities.XD_TreeMoor7] = 200,
    [Entities.XD_TreeMoor8] = 200,
    [Entities.XD_TreeMoor9] = 200,
    [Entities.XD_TreeNorth1] = 200,
    [Entities.XD_TreeNorth2] = 200,
    [Entities.XD_TreeNorth3] = 200,
    [Entities.XD_Willow1] = 300,
    [Entities.XD_WoodenFence01] = 400,
    [Entities.XD_WoodenFence02] = 400,
    [Entities.XD_WoodenFence03] = 400,
    [Entities.XD_WoodenFence04] = 400,
    [Entities.XD_WoodenFence05] = 400,
    [Entities.XD_WoodenFence06] = 400,
    [Entities.XD_WoodenFence07] = 400,
    [Entities.XD_WoodenFence08] = 400,
    [Entities.XD_WoodenFence09] = 400,
    [Entities.XD_WoodenFence10] = 400,
    [Entities.XD_WoodenFence11] = 400,
    [Entities.XD_WoodenFence12] = 400,
    [Entities.XD_WoodenFence13] = 400,
    [Entities.XD_WoodenFence14] = 400,
    [Entities.XD_WoodenFence15] = 400,
    [Entities.XD_WoodenFence16] = 400,
};