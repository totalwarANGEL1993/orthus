-- ########################################################################## --
-- #  Timer (Extra 1/2)                                                     # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This is a passive module that handles quest timers.
--
-- A quest must have a description in the quest log to display a timer. The
-- timer shows how much time is left until the quest automatically ends,
-- either with failure or success. Thats depends on the objectives.
--
-- Note that this won't be compatible to multiplayer maps. So you cant use
-- the qsb for vanilla multiplayer maps. But that was never intendet anyway.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- <li>qsb.questsystem</li>
-- </ul>
--
-- @set sort=true
--

QuestSystem.QuestTimer = {
    TimerJob = nil,
    Data = {},
    Timers = {},
};

---
-- Activates a timer for the quest with the given id.
-- @param[type=number] _QuestID ID of quest
--
-- @within QuestTimer
-- @local
--
function QuestSystem.QuestTimer:ActivateTimer(_QuestID)
    local Quest = QuestSystem.Quests[_QuestID];
    if Quest and Quest.m_Description and Quest.m_Time > 0 then
        table.insert(self.Data, {
            QuestID   = _QuestID,
            Title     = string.gsub(Quest.m_Description.Title, "@cr", ""),
            StartTime = Quest.m_StartTime,
            Duration  = Quest.m_Time,
        });
        self:Controller();
    end
end

---
-- Deactivates the timer for the quest with the given id.
-- @param[type=number] _QuestID ID of quest
--
-- @within QuestTimer
-- @local
--
function QuestSystem.QuestTimer:DeactivateTimer(_QuestID)
    for i= table.getn(self.Data), 1, -1 do
        if self.Data[i].QuestID == _QuestID then
            table.remove(self.Data, i);
        end
    end
end

---
-- Updates the timer at the index.
-- @param[type=number] _Index Index of timer.
--
-- @within QuestTimer
-- @local
--
function QuestSystem.QuestTimer:UpdateTimer(_Index)
    local Current = math.floor(Logic.GetTime() - self.Data[_Index].StartTime);
    local Limit   = self.Data[_Index].Duration;

    local Progress = Current/Limit;
    R = 95 + math.floor(155 * Progress);
    B = 255 - math.floor(200 * Progress);

    -- self:ResetVCMP();
    self:Show(_Index, self.Data[_Index].Title, Current, Limit, R, 150, B, 255);
end

---
-- Resets the VCMP window.
--
-- @within QuestTimer
-- @local
--
function QuestSystem.QuestTimer:ResetVCMP()
    GUIUpdate_GetTeamPoints = function()end
	GUIUpdate_VCTechRaceProgress = function()end
    GUIUpdate_VCTechRaceColor = function()end
    
    XGUIEng.ShowWidget("VCMP_Window", 1);
	XGUIEng.SetWidgetPosition("VCMP_Window", 5, 100);
	XGUIEng.SetWidgetPosition("NotesWindow", 220, 150);
	for i=1,8 do
		XGUIEng.ShowWidget("VCMP_Team"..i.."Player1", 0);
		XGUIEng.ShowWidget("VCMP_Team"..i.."Player2", 0);
		XGUIEng.ShowWidget("VCMP_Team"..i.."Player3", 0);
		XGUIEng.ShowWidget("VCMP_Team"..i.."Player4", 0);
		XGUIEng.ShowWidget("VCMP_Team"..i.."Player5", 0);
		XGUIEng.ShowWidget("VCMP_Team"..i.."Player6", 0);
		XGUIEng.ShowWidget("VCMP_Team"..i.."Player7", 0);
		XGUIEng.ShowWidget("VCMP_Team"..i.."Player8", 0);
		XGUIEng.SetWidgetSize("VCMP_Team"..i, 200, 10);
		XGUIEng.SetWidgetPositionAndSize("VCMP_Team"..i.."Name", 5, 0, 200, 4);
		XGUIEng.SetWidgetPositionAndSize("VCMP_Team"..i.."Shade", 5, 0, 200, 4);
		XGUIEng.SetWidgetPositionAndSize("VCMP_Team"..i.."Points", 5, 0, 200, 0);
		XGUIEng.SetWidgetPositionAndSize("VCMP_Team"..i.."PointGame", 5, 5, 200, 0);
		XGUIEng.ShowWidget("VCMP_Team"..i, 0);
		XGUIEng.ShowWidget("VCMP_Team"..i.."_Shade", 0);
	end
end

---
-- Displays a simple quest timer represented by a progress bar. Below the bar
-- is the name of the quest the timer is from.
--
-- @param[type=number] _Index Index of timer
-- @param[type=string] _title Displayed text
-- @param[type=number] _Current Current value
-- @param[type=number] _Limit Limit of timer
-- @param[type=number] _r Red of progress bar
-- @param[type=number] _g Green of progress bar
-- @param[type=number] _b Blue of progress bar
-- @param[type=number] _a Alpha of progress bar
--
-- @within QuestTimer
-- @local
--
function QuestSystem.QuestTimer:Show(_Index, _title, _Current, _Limit, _r, _g, _b, _a)
    local ProgressBar = math.floor((200 * (_Current/_Limit)) + 0.5);
    ProgressBar = (ProgressBar > 200 and 200) or ProgressBar;
    ProgressBar = (ProgressBar < 0 and 0) or ProgressBar;

	XGUIEng.ShowWidget("VCMP_Team".._Index, 1);
	XGUIEng.SetWidgetSize("VCMP_Team".._Index, 200, 10);
	XGUIEng.SetText("VCMP_Team".._Index.."Points", _title);
	XGUIEng.SetText("VCMP_Team".._Index.."Name", "");
	XGUIEng.ShowWidget("VCMP_Team".._Index.."PointGame", 1);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."_Shade", 1);

	XGUIEng.SetWidgetSize("VCMP_Team".._Index.."Name", ProgressBar, 4);
	XGUIEng.SetWidgetSize("VCMP_Team".._Index.."_Shade", 200, 4);
	XGUIEng.SetMaterialColor("VCMP_Team".._Index.."Name",0, _r, _g, _b, _a);
end

---
-- Hides the timer at the position.
-- @param[type=number] _Index Index of timer
--
-- @within QuestTimer
-- @local
--
function QuestSystem.QuestTimer:Hide(_Index)
	XGUIEng.ShowWidget("VCMP_Team".._Index.."Player1", 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."Player2", 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."Player3", 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."Player4", 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."Player5", 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."Player6", 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."Player7", 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."Player8", 0);
	XGUIEng.SetWidgetSize("VCMP_Team".._Index, 200, 10);
	XGUIEng.SetWidgetPositionAndSize("VCMP_Team".._Index.."Name", 5, 0, 200, 4);
	XGUIEng.SetWidgetPositionAndSize("VCMP_Team".._Index.."Shade", 5, 0, 200, 4);
	XGUIEng.SetWidgetPositionAndSize("VCMP_Team".._Index.."Points", 5, 0, 200, 0);
	XGUIEng.SetWidgetPositionAndSize("VCMP_Team".._Index.."PointGame", 5, 5, 200, 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index, 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."_Shade", 0);

	XGUIEng.ShowWidget("VCMP_Team".._Index, 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."PointGame", 0);
	XGUIEng.ShowWidget("VCMP_Team".._Index.."_Shade", 0);
end

---
-- Hides all timers.
--
-- @within QuestTimer
-- @local
--
function QuestSystem.QuestTimer:HideAllTimer()
    QuestSystem.QuestTimer:ResetVCMP();
    for i= 1, 8, 1 do
        self:Hide(i); 
    end
end

---
-- Initalizes the controller job for the timers.
--
-- @within QuestTimer
-- @local
--
function QuestSystem.QuestTimer:Controller()
    if self.TimerJob == nil then
        self.TimerJob = StartSimpleJobEx(function()
            QuestSystem.QuestTimer:HideAllTimer();
            for i= 1, table.getn(QuestSystem.QuestTimer.Data), 1 do
                if i <= 8 then
                    QuestSystem.QuestTimer:UpdateTimer(i);
                end
            end
        end);
    end
end

-- Callbacks ---------------------------------------------------------------- --

GameCallback_OnQuestStatusChanged_Orig_QsbTimer = GameCallback_OnQuestStatusChanged;
function GameCallback_OnQuestStatusChanged(_QuestID, _State, _Result)
    if GameCallback_OnQuestStatusChanged_Orig_QsbTimer then
        GameCallback_OnQuestStatusChanged_Orig_QsbTimer(_QuestID, _State, _Result);
    end
    
    if _State == QuestStates.Active then
        QuestSystem.QuestTimer:DeactivateTimer(_QuestID);
        QuestSystem.QuestTimer:ActivateTimer(_QuestID);
    else
        Message("Quest " .._QuestID.. " has finished!");
        QuestSystem.QuestTimer:DeactivateTimer(_QuestID);
    end
end

