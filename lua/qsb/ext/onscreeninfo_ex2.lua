-- ########################################################################## --
-- #  Onscreen Information (Extra 1/2)                                      # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module renders timers and progress bars for quests.
-- 
-- A quest must have a description in the quest log to display onscreen info.
--
-- Timers are indicating how much time is left until the quest automatically
-- ends, either with failure or success. Thats depends on the objectives.
--
-- Progress bars are automatically displayed for several objective types. They
-- show how much the player advanced in completing the quest. The progress of
-- a quest is determinated by the first behavior that can have a progress bar.
--
-- There can only be 8 active quests visible on screen!
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.qsbtools</li>
-- <li>qsb.questsystem</li>
-- </ul>
--
-- @set sort=true
--

QuestSystem.OnScreenInfo = {
    m_IsInstalled = false,
    m_TimerJob = nil,
    m_Data = {},

    ProgressBarBehavior = {
        Objectives.Produce,
        Objectives.Settlers,
        Objectives.Workers,
        Objectives.Soldiers,
        Objectives.Motivation,
        Objectives.Units,
        Objectives.DestroyType,
        Objectives.DestroyCategory,
        Objectives.Steal,
    }
};

---
-- Adds progress to the progress bar of the quest by calling inside a custom
-- objective behavior. Only the first behavior with a progress bar is checked.
-- 
-- @param[type=table]  _Behavior Custom behavior
-- @param[type=number] _Current  Current value
-- @param[type=number] _Max      Maximum value
-- @within Methods
--
function SetBehaviorProgress(_Behavior, _Current, _Max)
    if not _Behavior.Data.Progress then
        _Behavior.Data.Progress = {Max = _Max};
    end
    _Behavior.Data.Progress.Current = _Current;
end

---
-- Resets the progress of this behavior.
-- 
-- @param[type=table]  _Behavior Custom behavior
-- @within Methods
--
function ResetBehaviorProgress(_Behavior)
    _Behavior.Data.Progress = nil;
end

function QuestSystem.OnScreenInfo:Install()
    if self.m_IsInstalled then
        return;
    end
    self.m_IsInstalled = true;

    self:OverrideUpdates();
    StartSimpleJobEx(function()
        QuestSystem.OnScreenInfo:RenderOnScreenInfos();
    end);
end

function QuestSystem.OnScreenInfo:Activate(_QuestID)
    local Quest = QuestSystem.Quests[_QuestID];
    if Quest and Quest.m_Description and self:IsUsingOnScreenInfo(Quest) then
        table.insert(self.m_Data, {
            QuestID   = _QuestID,
            Receiver  = Quest.m_Receiver,
            Title     = string.gsub(Quest.m_Description.Title, "@cr", ""),
        });
    end
end

function QuestSystem.OnScreenInfo:Deactivate(_QuestID)
    for i= table.getn(self.m_Data), 1, -1 do
        if self.m_Data[i].QuestID == _QuestID then
            table.remove(self.m_Data, i);
        end
    end
end

function QuestSystem.OnScreenInfo:RenderOnScreenInfos()
    QuestSystem.OnScreenInfo:InitPositions();
    for k, v in pairs(MPSync:GetActivePlayers()) do
        local Index = 1;
        for i= 1, table.getn(self.m_Data), 1 do
            local OsiData = self:GetPosition(i);
            local Visible = 0;
            if OsiData.Counter and OsiData.Counter.Max > -1 then
                Visible = Visible +1;
            end
            if OsiData.Timer and OsiData.Timer.TimeLeft > -1 then
                Visible = Visible +2;
            end
            if Index < 8 and v == GUI.GetPlayerID() and v == self.m_Data[i].Receiver then
                self:ShowPosition(Index, self.m_Data[i].Receiver, Visible);
                Index = Index +1;
            end
        end
    end
end

function QuestSystem.OnScreenInfo:GetPosition(_PositionID)
    if not self.m_Data[_PositionID] then
        return;
    end
    local Quest = QuestSystem.Quests[self.m_Data[_PositionID].QuestID];
    self:CollectTimerData(Quest, self.m_Data[_PositionID]);
    for i= 1, table.getn(Quest.m_Objectives), 1 do
        if self:CollectCounterData(Quest, Quest.m_Objectives[1], self.m_Data[_PositionID]) then
            break;
        end
    end
    return self.m_Data[_PositionID];
end

function QuestSystem.OnScreenInfo:IsUsingOnScreenInfo(_Quest)
    return self:IsUsingOnScreenInfoTimer(_Quest) or self:IsUsingOnScreenInfoProgressBar(_Quest);
end

function QuestSystem.OnScreenInfo:IsUsingOnScreenInfoTimer(_Quest)
    return _Quest.m_Time and _Quest.m_Time > 0;
end

function QuestSystem.OnScreenInfo:IsUsingOnScreenInfoProgressBar(_Quest)
    for i= 1, table.getn(_Quest.m_Objectives), 1 do
        if QSBTools.FindValue(_Quest.m_Objectives[i][1], QuestSystem.OnScreenInfo.ProgressBarBehavior) then
            return true;
        end
    end
    return false;
end

function QuestSystem.OnScreenInfo:CollectTimerData(_Quest, _Data)
    if _Quest.m_Time > 0 then
        local RemainingTime = (_Quest.m_StartTime + _Quest.m_Time) - Logic.GetTime();
        if RemainingTime < 0 then
            RemainingTime = 0;
        end
        _Data.Timer = _Data.Timer or {};
        _Data.Timer.TimeLeft = RemainingTime;
    end
end

function QuestSystem.OnScreenInfo:CollectCounterData(_Quest, _Behavior, _Data)
    local Current = 0;
    local Max = 0;

    -- Produce resources
    if _Behavior[1] == Objectives.Produce then
        local Amount = Logic.GetPlayersGlobalResource(_Quest.m_Receiver, _Behavior[2]);
        if not _Behavior[4] then
            Amount = Amount + Logic.GetPlayersGlobalResource(
                _Quest.m_Receiver, _Behavior[2]+1
            );
        end
        Current = Current + Amount;
        Max = Max + _Behavior[3];
    
    -- Reach unit amount (only positive)
    elseif _Behavior[1] == Objectives.Settlers 
    or     _Behavior[1] == Objectives.Workers 
    or     _Behavior[1] == Objectives.Soldiers 
    or     _Behavior[1] == Objectives.Motivation then
        if _Behavior[3] then
            return false;
        end
        local Amount = 0;
        if _Behavior[1] == Objectives.Workers then
            Amount = Logic.GetNumberOfAttractedWorker(_Behavior[4] or _Quest.m_Receiver);
        elseif _Behavior[1] == Objectives.Soldiers then
            Amount = Logic.GetNumberOfAttractedSoldiers(_Behavior[4] or _Quest.m_Receiver);
        elseif _Behavior[1] == Objectives.Motivation then
            Amount = Logic.GetAverageMotivation(_Behavior[4] or _Quest.m_Receiver);
        else
            Amount = Logic.GetNumberOfAttractedSettlers(_Behavior[4] or _Quest.m_Receiver);
        end
        Current = Current + Amount;
        Max = Max + _Behavior[2];
    
    -- Recruit units
    elseif _Behavior[1] == Objectives.Units then
        local Current = Logic.GetNumberOfEntitiesOfTypeOfPlayer(
            _Quest.m_Receiver, _Behavior[2]
        );
        local Max = _Behavior[3];
        Current = Current + Current;
        Max = Max + Max;
    
    -- Destroy types or categories
    elseif _Behavior[1] == Objectives.DestroyType 
    or    _Behavior[1] == Objectives.DestroyCategory then
        Current = Current + _Behavior[5];
        Max = Max + _Behavior[4];
    
    -- Steal resources
    elseif _Behavior[1] == Objectives.Steal then
        Current = Current + _Behavior[5];
        Max = Max + _Behavior[4];
    
    -- Custom functions with special fields
    elseif _Behavior[1] == Objectives.MapScriptFunction then
        if _Behavior[2][2].Data.Progress then
            Current = Current + _Behavior[2][2].Data.Progress.Current;
            Max = Max + _Behavior[2][2].Data.Progress.Max;
        end
    end

    if Current > Max then
        Current = Max;
    end
    _Data.Counter = _Data.Counter or {};
    _Data.Counter.Current = Current;
    _Data.Counter.Max = (Max > 0 and Max) or -1;
    return _Data.Counter.Max ~= -1;
end

function QuestSystem.OnScreenInfo:ConvertSecondsToString(_TotalSeconds)
    local Hours = math.floor(_TotalSeconds / 60 / 60);
    local TotalMinutes = math.floor(_TotalSeconds / 60);
    local Minutes = math.mod(TotalMinutes, 60);
    if Minutes == 60 then
        Hours = Hours +1;
        Minutes = Minutes -1;
    end
    local Seconds = math.floor(math.mod(_TotalSeconds, 60));
    if Seconds == 60 then
        Minutes = Minutes +1;
        Seconds = Seconds -1;
    end

    local String = "";
    if Hours < 10 then
        String = String .. "0" .. Hours .. ":";
    else
        String = String .. Hours .. ":";
    end
    if Minutes < 10 then
        String = String .. "0" .. Minutes .. ":";
    else
        String = String .. Minutes .. ":";
    end
    if Seconds < 10 then
        String = String .. "0" .. Seconds;
    else
        String = String .. Seconds;
    end
    return String;
end

function QuestSystem.OnScreenInfo:OverrideUpdates()
    GUIUpdate_VCTechRaceProgress = function()
        local CurrentWidgetID = XGUIEng.GetCurrentWidgetID();
        local MotherContainer= XGUIEng.GetWidgetsMotherID(CurrentWidgetID);
        local GrandMaContainer= XGUIEng.GetWidgetsMotherID(MotherContainer);
        local PositionID = XGUIEng.GetBaseWidgetUserVariable(GrandMaContainer, 0);

        local Data = QuestSystem.OnScreenInfo:GetPosition(PositionID+1);
        XGUIEng.SetText("VCMP_Team1Name", Data.Title);

        local Progress = Data.Counter.Current / Data.Counter.Max;
        local R = 150 - math.floor(100 * Progress);
        local G = 42 + math.floor(108 * Progress);
        local B = 45;
	    XGUIEng.SetProgressBarValues(CurrentWidgetID, Data.Counter.Current, Data.Counter.Max);
        XGUIEng.SetMaterialColor(CurrentWidgetID, 0, R, G, B, 255);
    end

    GUIUpdate_GetTeamPoints = function()
        local CurrentWidgetID = XGUIEng.GetCurrentWidgetID();
        local MotherContainer= XGUIEng.GetWidgetsMotherID(CurrentWidgetID);
        local GrandMaContainer= XGUIEng.GetWidgetsMotherID(MotherContainer);
        local PositionID = XGUIEng.GetBaseWidgetUserVariable(GrandMaContainer, 0);
        
        local Data = QuestSystem.OnScreenInfo:GetPosition(PositionID+1);
        XGUIEng.SetText("VCMP_Team1Name", Data.Title);

        local FormatedTime = QuestSystem.OnScreenInfo:ConvertSecondsToString(Data.Timer.TimeLeft);
        local Text = string.format(
            " %s @ra %s",
            (Data.Timer.TimeLeft >= 60 and "@color:255:255:255") or "@color:180,80,80",
            FormatedTime
        );
        XGUIEng.SetText(CurrentWidgetID, Text);
    end
end

function QuestSystem.OnScreenInfo:InitPositions()
    local Size = {GUI.GetScreenSize()};
    XGUIEng.SetWidgetPositionAndSize("VCMP_Window", 0, 120, Size[1], Size[2]-120);
    XGUIEng.ShowWidget("VCMP_Window", 1);
    for i= 1, 8, 1 do
        local Offset = (48 * (i-1));
        XGUIEng.SetWidgetPositionAndSize("VCMP_Team" ..i, 0, Offset, Size[1], 70);
        for j= 1, 8, 1 do
            XGUIEng.ShowWidget("VCMP_Team" ..i.. "Player" ..j, 0);
        end
        XGUIEng.ShowWidget("VCMP_Team" ..i, 0);
        XGUIEng.ShowWidget("VCMP_Team" ..i.. "_Shade", 0);
    end
end

function QuestSystem.OnScreenInfo:ShowPosition(_Index, _Receiver, _TimerCounterFlag)
    local Size = {GUI.GetScreenSize()};
    if _Index > 8 then
        return;
    end
    
    local BaseOffset = 24;
    local TechRaceVisible = ((_TimerCounterFlag == 1 or _TimerCounterFlag == 3) and 1) or 0;
    local PointsVisible = ((_TimerCounterFlag == 2 or _TimerCounterFlag == 3) and 1) or 0;
    if TechRaceVisible == 1 or PointsVisible == 1 then
        BaseOffset = BaseOffset +16;
    end
    local Offset = (BaseOffset * (_Index-1));

    XGUIEng.ShowWidget("VCMP_Team" .._Index, 1);

    local TeamNamePosX = (Size[1]/2) +230;
    local TeamNameSizeX = (Size[1]/2) -300;
    local R, G, B = GUI.GetPlayerColor(_Receiver);
    XGUIEng.ShowWidget("VCMP_Team" .._Index.. "Name", 1);
    XGUIEng.SetMaterialColor("VCMP_Team" .._Index.. "Name", 0, R, G, B, 200);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "Name", TeamNamePosX, 0, TeamNameSizeX, 16);

    local TechRacePosX = (Size[1]/2) +230;
    local TechRaceSizeX = (Size[1]/2) -300;
    local PointsOffsetX = 0 + ((PointsVisible == 1 and 0) or 62);
    local PointsOffsetS = 0 + ((PointsVisible == 1 and 62) or 0);
    XGUIEng.ShowWidget("VCMP_Team" .._Index.. "TechRace", TechRaceVisible);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "TechRace", TechRacePosX, 16, TechRaceSizeX, 16);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "Progress", PointsOffsetX, 0, TechRaceSizeX - PointsOffsetS, 16);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "ProgressBG", PointsOffsetX, 0, TechRaceSizeX - PointsOffsetS, 16);

    local PointsPosX = (Size[1]/2) +230;
    local PointsSizeX = (Size[1]/2) -300;
    local BarVisibleOffset = 0 + ((TechRaceVisible == 1 and TechRaceSizeX) or 0);
    XGUIEng.ShowWidget("VCMP_Team" .._Index.. "PointGame", PointsVisible);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "PointGame", PointsPosX, 16, PointsSizeX, 16);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "Points", BarVisibleOffset, 0, 60, 16);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "PointBG", BarVisibleOffset, 0, 60, 16);
end

GameCallback_OnQuestStatusChanged_Orig_OnScreenInfo = GameCallback_OnQuestStatusChanged;
GameCallback_OnQuestStatusChanged = function(_QuestID, _State, _Result)
    GameCallback_OnQuestStatusChanged_Orig_OnScreenInfo(_QuestID, _State, _Result);
    
    QuestSystem.OnScreenInfo:Install();
    if _State == QuestStates.Active then
        QuestSystem.OnScreenInfo:Deactivate(_QuestID);
        QuestSystem.OnScreenInfo:Activate(_QuestID);
    else
        QuestSystem.OnScreenInfo:Deactivate(_QuestID);
    end
end

Mission_OnSaveGameLoaded_Orig_OnScreenInfo = Mission_OnSaveGameLoaded;
Mission_OnSaveGameLoaded = function()
    Mission_OnSaveGameLoaded_Orig_OnScreenInfo();
    QuestSystem.OnScreenInfo:Install();
end

