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
-- <li>qsb.questtools</li>
-- <li>qsb.questsystem</li>
-- </ul>
--
-- @set sort=true
--

OnScreenInfo = {
    m_IsInstalled = false,
    m_TimerJob = nil,
    m_Data = {},

    LocalOsiData = {},

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
        Objectives.MapScriptFunction,
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
        _Behavior.Data.Progress = {};
        if not _Behavior.Data.Progress.Init then
            _Behavior.Data.Progress.Init = true;
        _Behavior.Data.Progress.Max  = _Max;
        end
    end
    if _Behavior.Data.Progress then
        _Behavior.Data.Progress.Current = _Current;
    end
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

function OnScreenInfo:Install()
    if not self.m_IsInstalled then
        StartSimpleHiResJobEx(function()
            OnScreenInfo:RenderOnScreenInfos();
        end);
        AddOnSaveLoadedAction(function()
            OnScreenInfo:Install();
        end);
    end
    self.m_IsInstalled = true;
    self:OverrideUpdates();
end

function OnScreenInfo:Activate(_QuestID)
    local Quest = QuestSystem.Quests[_QuestID];
    self.m_Data[Quest.m_Receiver] = self.m_Data[Quest.m_Receiver] or {};
    if Quest and Quest.m_Description and Quest.m_Description.Title and self:IsUsingOnScreenInfo(Quest) then
        table.insert(self.m_Data[Quest.m_Receiver], {
            QuestID   = _QuestID,
            Receiver  = Quest.m_Receiver,
            Title     = string.gsub(Quest.m_Description.Title, "@cr", ""),
        });
    end
end

function OnScreenInfo:Deactivate(_QuestID)
    local Quest = QuestSystem.Quests[_QuestID];
    self.m_Data[Quest.m_Receiver] = self.m_Data[Quest.m_Receiver] or {};
    if self.m_Data[Quest.m_Receiver] then
        for i= table.getn(self.m_Data[Quest.m_Receiver]), 1, -1 do
            if self.m_Data[Quest.m_Receiver][i].QuestID == _QuestID then
                table.remove(self.m_Data[Quest.m_Receiver], i);
            end
        end
    end
end

function OnScreenInfo:RenderOnScreenInfos()
    local CurrentPlayerID = GUI.GetPlayerID();
    self.m_Data[CurrentPlayerID] = self.m_Data[CurrentPlayerID] or {};
    self:InitPositions();
    local Index = 1;
    for i= 1, table.getn(self.m_Data[CurrentPlayerID]), 1 do
        if Index > 8 then
            return;
        end

        local OsiData = self:GetPosition(CurrentPlayerID, i);       
        if CurrentPlayerID == OsiData.Receiver then
            local Visible = 0;
            if OsiData.Counter and OsiData.Counter.Max > -1 then
                Visible = Visible +1;
            end
            if OsiData.Timer and OsiData.Timer.TimeLeft > -1 then
                Visible = Visible +2;
            end
            if Visible > 0 then
                self:ShowPosition(Index, CurrentPlayerID, Visible);
                self.m_Data[CurrentPlayerID][i].Index = Index;
                Index = Index +1;
            end
        end
    end
end

function OnScreenInfo:GetPosition(_PlayerID, _Index)
    self.m_Data[_PlayerID] = self.m_Data[_PlayerID] or {};
    if not self.m_Data[_PlayerID][_Index] then
        return;
    end
    local Quest = QuestSystem.Quests[self.m_Data[_PlayerID][_Index].QuestID];
    self:CollectTimerData(Quest, self.m_Data[_PlayerID][_Index]);
    for i= 1, table.getn(Quest.m_Objectives), 1 do
        if self:CollectCounterData(Quest, Quest.m_Objectives[i], self.m_Data[_PlayerID][_Index]) then
            break;
        end
    end
    return self.m_Data[_PlayerID][_Index];
end

function OnScreenInfo:IsUsingOnScreenInfo(_Quest)
    return self:IsUsingOnScreenInfoTimer(_Quest) or self:IsUsingOnScreenInfoProgressBar(_Quest);
end

function OnScreenInfo:IsUsingOnScreenInfoTimer(_Quest)
    return _Quest.m_Time and _Quest.m_Time > 0;
end

function OnScreenInfo:IsUsingOnScreenInfoProgressBar(_Quest)
    for i= 1, table.getn(_Quest.m_Objectives), 1 do
        if QuestTools.IsInTable(_Quest.m_Objectives[i][1], OnScreenInfo.ProgressBarBehavior) then
            return true;
        end
    end
    return false;
end

function OnScreenInfo:CollectTimerData(_Quest, _Data)
    if _Quest.m_Time > 0 then
        local RemainingTime = (_Quest.m_StartTime + _Quest.m_Time -1) - round(Logic.GetTime());
        if RemainingTime < 0 then
            RemainingTime = 0;
        end
        _Data.Timer = _Data.Timer or {};
        _Data.Timer.TimeLeft = RemainingTime;
    end
end

function OnScreenInfo:CollectCounterData(_Quest, _Behavior, _Data)
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

function OnScreenInfo:ConvertSecondsToString(_TotalSeconds)
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

function OnScreenInfo:OverrideUpdates()
    -- Must be overridden to do nothing
    GUIUpdate_VCTechRaceColor = function(_Player)
    end

    GUIUpdate_VCTechRaceProgress = function()
        local PlayerID = GUI.GetPlayerID();
        if OnScreenInfo.m_Data[PlayerID] then
            for i= 1, 8, 1 do
                local Data = OnScreenInfo.m_Data[PlayerID][i];
                if Data and Data.Index and Data.Counter and Data.Counter.Max then
                    XGUIEng.SetText("VCMP_Team" ..Data.Index.. "Name", Data.Title);
                    local CurrentWidgetID = XGUIEng.GetWidgetID("VCMP_Team" ..Data.Index.. "Progress");
                    local Progress = Data.Counter.Current / Data.Counter.Max;
                    local R = 150 - math.floor(100 * Progress);
                    local G = 42 + math.floor(108 * Progress);
                    local B = 45;
                    XGUIEng.SetProgressBarValues(CurrentWidgetID, Data.Counter.Current, Data.Counter.Max);
                    XGUIEng.SetMaterialColor(CurrentWidgetID, 0, R, G, B, 255);
                end
            end
        end
    end

    GUIUpdate_GetTeamPoints = function()
        local PlayerID = GUI.GetPlayerID();
        if OnScreenInfo.m_Data[PlayerID] then
            for i= 1, 8, 1 do
                local Data = OnScreenInfo.m_Data[PlayerID][i];
                if Data and Data.Index and Data.Timer and Data.Timer.TimeLeft then
                    local CurrentWidgetID = XGUIEng.GetWidgetID("VCMP_Team" ..Data.Index.. "Points");
                    XGUIEng.SetText("VCMP_Team" ..Data.Index.. "Name", Data.Title);
                    local FormatedTime = OnScreenInfo:ConvertSecondsToString(Data.Timer.TimeLeft);
                    local Text = string.format(
                        " %s %s",
                        (Data.Timer.TimeLeft >= 60 and "@color:255:255:255") or "@color:190,110,110",
                        FormatedTime
                    );
                    XGUIEng.SetText(CurrentWidgetID, Text);
                end
            end
        end
    end
end

function OnScreenInfo:GetScreenSizeFactors()
    local Size = {GUI.GetScreenSize()};
    local FactorX = (1024/Size[1]);
    local FactorY = (768/Size[2]);
    local FactorW = (1024/Size[1]);
    local FactorH = (768/Size[2]);
    return FactorX, FactorY, FactorW, FactorH;
end

function OnScreenInfo:InitPositions()
    local Size = {GUI.GetScreenSize()};
    local X,Y,W,H = self:GetScreenSizeFactors();

    local MotherW = round(300 * W);
    local MotherH = round(640 * H);
    local XAnchor = round(1024-(380*X));
    local YAnchor = round(160 * Y);
	XGUIEng.SetWidgetPositionAndSize("VCMP_Window", XAnchor, YAnchor, MotherW, MotherH);
    XGUIEng.ShowWidget("VCMP_Window", 1);
    for i= 1, 8, 1 do
        local OffsetY = ((48*Y) * (i-1));
        XGUIEng.SetWidgetPositionAndSize("VCMP_Team" ..i, XAnchor, OffsetY, MotherW, round(48*Y));
        for j= 1, 8, 1 do
            XGUIEng.ShowWidget("VCMP_Team" ..i.. "Player" ..j, 0);
        end
        XGUIEng.ShowWidget("VCMP_Team" ..i, 0);
        XGUIEng.ShowWidget("VCMP_Team" ..i.. "_Shade", 0);
    end
end

function OnScreenInfo:ShowPosition(_Index, _Receiver, _TimerCounterFlag)
    local PlayerID = GUI.GetPlayerID();
    if _Index > 8 or _TimerCounterFlag == 0 or _Receiver ~= PlayerID then
        return;
    end
    local X,Y,W,H = self:GetScreenSizeFactors();
    local MotherW = round(300 * W);
    local MotherH = round(700 * H);
    
    local BaseOffset = 24;
    local TechRaceVisible = ((_TimerCounterFlag == 1 or _TimerCounterFlag == 3) and 1) or 0;
    local PointsVisible = ((_TimerCounterFlag == 2 or _TimerCounterFlag == 3) and 1) or 0;
    if TechRaceVisible == 1 or PointsVisible == 1 then
        BaseOffset = BaseOffset +16;
    end
    local OffsetY = round((BaseOffset*X) * (_Index-1));

    XGUIEng.ShowWidget("VCMP_Team" .._Index, 1);

    XGUIEng.ShowWidget("VCMP_Team" .._Index.. "Name", 1);
    XGUIEng.SetWidgetSize("VCMP_Team" .._Index.. "Name", MotherW, round(16*H));

    local BarS = round(300*W - ((PointsVisible == 1 and 65*W) or 0));
    XGUIEng.ShowWidget("VCMP_Team" .._Index.. "TechRace", TechRaceVisible);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "TechRace", round(60*X), round(16*Y), MotherW, round(16*H));
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "Progress", 0, 0, BarS, round(16*H));
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "ProgressBG", 0, 0, BarS, round(16*H));

    local PointsX = round(240*W);
    XGUIEng.ShowWidget("VCMP_Team" .._Index.. "PointGame", PointsVisible);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "PointGame", PointsX, round(16*Y), round(60*W), round(16*H));
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "Points", 0, 0, round(60*W), round(16*H));
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "PointBG", 0, 0, round(60*W), round(16*H));
end

GameCallback_OnQuestStatusChanged_Orig_OnScreenInfo = GameCallback_OnQuestStatusChanged;
GameCallback_OnQuestStatusChanged = function(_QuestID, _State, _Result)
    GameCallback_OnQuestStatusChanged_Orig_OnScreenInfo(_QuestID, _State, _Result);
    OnScreenInfo:Install();
    if _State == QuestStates.Active then
        OnScreenInfo:Deactivate(_QuestID);
        OnScreenInfo:Activate(_QuestID);
    else
        OnScreenInfo:Deactivate(_QuestID);
    end
end

