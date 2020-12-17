-- ########################################################################## --
-- #  Quest Briefing                                                        # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module adds some briefing improvements. Some are just for cosmetics,
-- some are fixing pittful bugs, some offer helpful new features. This is the
-- version for the vanilla game.
--
-- If multiple choice is used in Multiplayer you must synchronize the actions
-- of buttont if something is created or lua state changes. Otherwise you will
-- get a desync!
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.core.oop</li>
-- <li>qsb.lib.questtools</li>
-- <li>qsb.lib.questsystem</li>
-- </ul>
--
-- @set sort=true
--

QuestBriefing = {
    m_Book = {};
    m_Queue = {};

    Events = {},
    UniqieID = 0,

    TimerPerChar = 0.6,
    FakeHeight = 150,
    DialogZoomDistance = 1000,
    DialogZoomAngle = 35,
    DialogRotationAngle = -45,
    BriefingZoomDistance = 4000,
    BriefingZoomAngle = 48,
    BriefingRotationAngle = -45,
    BriefingExploration = 6000,
    MCButtonAmount = 2,
}

---
-- TODO: Add doc
-- @within QuestBriefing
-- @local
--
function QuestBriefing:Install()
    self:CreateScriptEvents();
    self:OverrideBriefingFunctions();

    self.m_Book.Job = StartSimpleHiResJobEx(function()
        QuestBriefing:ControlBriefing();
    end);
end

function QuestBriefing:CreateScriptEvents()
    -- Player pressed escape
    self.Events.PostEscapePressed = QuestSync:CreateScriptEvent(function(_PlayerID)
        if QuestBriefing:IsBriefingActive(_PlayerID) then
            if QuestBriefing:CanPageBeSkipped(_PlayerID) then
                QuestBriefing:NextPage(_PlayerID, false);
            end
        end
    end);
    
    -- Multiple choice option selected
    self.Events.PostOptionSelected = QuestSync:CreateScriptEvent(function(_PlayerID, _PageID, _OptionID)
        if QuestBriefing:IsBriefingActive(_PlayerID) then
            if QuestBriefing.m_Book[_PlayerID][_PageID] then
                if QuestBriefing.m_Book[_PlayerID][_PageID].MC then
                    for k, v in pairs(QuestBriefing.m_Book[_PlayerID][_PageID].MC) do
                        if v and v.ID == _OptionID then
                            local Option = v;
                            if type(v[2]) == "function" then
                                QuestBriefing.m_Book[_PlayerID].Page = self:GetPageID(v[2](v), _PlayerID) -1;
                            else
                                QuestBriefing.m_Book[_PlayerID].Page = self:GetPageID(v[2], _PlayerID) -1;
                            end
                            QuestBriefing.m_Book[_PlayerID][_PageID].MC.Selected = _OptionID;
                            QuestBriefing:NextPage(_PlayerID, false);
                            return;
                        end
                    end
                end
            end
        end
    end);
end

function QuestBriefing:OverrideBriefingFunctions()
    ---
    -- Creates the local briefing functions for adding pages.
    --
    -- Functions created:
    -- <ul>
    -- <li>AP: Creates normal pages and multiple choice pages. You have full
    -- control over all settings. It is also possible to do cutscene like
    -- camera animations. Add a name to the page to make it easily accessable
    -- via multiple choice.</li>
    -- <li>ASP: Creates a simplyfied page. A short notation good for dialogs.
    -- can be used in talkative missions. The first argument is an optional
    -- name for the page to be used with multiple choice.</li>
    -- <li>AMC: Creates a simplyfied multiple choice page. Answers are passed
    -- after the action. Each answer consists of the text and the target where
    -- the briefing jumps to. Target can also be a function that returns
    -- the target.</li>
    -- </ul>
    --
    -- @param[type=table] _briefing Briefing
    -- @return[type=function] AP function
    -- @return[type=function] ASP function
    -- @return[type=function] AMC function
    -- @within Methods
    --
    function AddPages(_Briefing)
        return QuestBriefing:AddPages(_Briefing);
    end

    ---
    -- Starts the passed briefing for the quest and returns the briefing ID.
    --
    -- The function with the briefing muss always pass the created ID back to
    -- the calling quest.
    --
    -- The briefing can have the following attributes:
    --
    -- <table border="1">
    -- <tr>
    -- <td><b>Attribute</b></td>
    -- <td><b>Type</b></td>
    -- <td><b>Description</b></td>
    -- </tr>
    -- <tr>
    -- <td>Starting</td>
    -- <td>function</td>
    -- <td>Method to be invoked before briefing starts.</td>
    -- </tr>
    -- <tr>
    -- <td>Finished</td>
    -- <td>function</td>
    -- <td>Method to be invoked when briefing has finished.</td>
    -- </tr>
    -- <tr>
    -- <td>RestoreCamera</td>
    -- <td>boolean</td>
    -- <td>Camera position is saved and restored after briefing ends.</td>
    -- </tr>
    -- <tr>
    -- <td>RenderFoW</td>
    -- <td>boolean</td>
    -- <td>Shows the fog of war. This is a default setting and can be set for
    -- each page seperatley.</td>
    -- </tr>
    -- <tr>
    -- <td>RenderSky</td>
    -- <td>boolean</td>
    -- <td>Shows the sky. This is a default setting and can be set for each
    -- page seperatley.</td>
    -- </tr>
    -- </table>
    --
    -- @param[type=table] _Briefing Briefing description
    -- @param[type=table] _Quest    Quest briefing is bound to
    -- @return[type=number] ID of briefing
    -- @within Methods
    --
    StartBriefing = function(_Briefing, _ID, _Quest)
        return QuestBriefing:StartBriefing(_Briefing, _ID, _Quest);
    end

    BriefingMCButtonSelected = function(_Selected)
        QuestBriefing:BriefingMCButtonSelected(_Selected);
    end

    ---
    -- Returns the chosen answer of the page. If no answer was chosen or if
    -- the page hasn't a multiple choice then 0 is returned.
    --
    -- @param[type=table] _Page Briefing description
    -- @return[type=number] ID of selected answer
    -- @within Methods
    --
    GetSelectedBriefingMCButton = function(_Page)
        if _Page.MC and _Page.MC.Selected then
            return _Page.MC.Selected;
        end
        return 0;
    end

    ---
    -- Returns true if a briefing is active for the player. If no player was
    -- passed, the local player is checked.
    --
    -- @param[type=number] _PlayerID (Optional) ID of player
    -- @return[type=boolean] Briefing is active
    -- @within Methods
    --
    IsBriefingActive = function(_PlayerID)
        return QuestBriefing:IsBriefingActive(_PlayerID) == true;
    end

    IsWaitingForMCSelection = function()
        local PlayerID = GUI.GetPlayerID();
        if QuestBriefing:IsBriefingActive(PlayerID) then
            local Page = QuestBriefing.m_Book[PlayerID].Page;
            if QuestBriefing.m_Book[PlayerID][Page].MC then
                return true;
            end
        end
        return false;
    end

    GameCallback_Escape_Orig_QuestBriefing = GameCallback_Escape;
    GameCallback_Escape = function()
        local PlayerID = GUI.GetPlayerID();
        if QuestBriefing:IsBriefingActive(PlayerID) then
            QuestSync:SnchronizedCall(QuestBriefing.Events.PostEscapePressed, PlayerID);
        else
            GameCallback_Escape_Orig_QuestBriefing();
        end
    end
end

function QuestBriefing:AddPages(_Briefing)
    ---
    -- Creates a page for the briefing.
    --
    -- Pages can have the following attributes:
    --
    -- <table border="1">
    -- <tr>
    -- <td><b>Attribute</b></td>
    -- <td><b>Type</b></td>
    -- <td><b>Description</b></td>
    -- </tr>
    -- <tr>
    -- <td>Name</td>
    -- <td>string</td>
    -- <td>(Optional) Name of the page</td>
    -- </tr>
    -- <tr>
    -- <td>Position</td>
    -- <td>string|number</td>
    -- <td>Scriptname or ID of target entity</td>
    -- </tr>
    -- <tr>
    -- <td>Title</td>
    -- <td>string|table</td>
    -- <td>Text to be shown as title. Can be localized.</td>
    -- </tr>
    -- <tr>
    -- <td>Text</td>
    -- <td>string|table</td>
    -- <td>Text to be shown as page content. Can be localized.</td>
    -- </tr>
    -- <tr>
    -- <td>DialogCamera</td>
    -- <td>boolean</td>
    -- <td>Use dialog camera settings.</td>
    -- </tr>
    -- <tr>
    -- <td>Action</td>
    -- <td>function</td>
    -- <td>Function to be called when page is shown. Will be called every time
    -- the page is entered.</td>
    -- </tr>
    -- <tr>
    -- <td>CameraFlight</td>
    -- <td>boolean</td>
    -- <td>(Optional) Use a camera animation for the transition between the
    -- pages camera settings and the settings of the previous page. Not possible
    -- for the first page.</td>
    -- </tr>
    -- <tr>
    -- <td>Distance</td>
    -- <td>number</td>
    -- <td>(Optional) Sets a different distance to the target.</td>
    -- </tr>
    -- <tr>
    -- <td>Rotation</td>
    -- <td>number</td>
    -- <td>(Optional) Sets a different rotation angle then the default.</td>
    -- </tr>
    -- <tr>
    -- <td>Angle</td>
    -- <td>number</td>
    -- <td>(Optional) Sets a different elevation angle then the default.</td>
    -- </tr>
    -- <tr>
    -- <td>RenderFoW</td>
    -- <td>boolean</td>
    -- <td>Shows the fog of war.</td>
    -- </tr>
    -- <tr>
    -- <td>RenderSky</td>
    -- <td>boolean</td>
    -- <td>Shows the sky.</td>
    -- </tr>
    -- <tr>
    -- <td>Minimap</td>
    -- <td>boolean</td>
    -- <td>Shows the minimap.</td>
    -- </tr>
    -- <tr>
    -- <td>Signal</td>
    -- <td>boolean</td>
    -- <td>Marks the camera position on the minimap with a signal.</td>
    -- </tr>
    -- <tr>
    -- <td>Explore</td>
    -- <td>number</td>
    -- <td>Reveals an area of the set size around the position. This area is
    -- hidden again after the briefing ends.</td>
    -- </tr>
    -- </table>
    --
    -- @param[type=table] _Page Definded page
    -- @return[type=table] Created page
    --
    local AP = function(_Page)
        table.insert(_Briefing, _Page);
        return _Page;
    end

    ---
    -- Creates a simple dialog page.
    --
    -- Parameter order: [name, ] position, title, text, dialogCamera, action
    --
    -- @param ... Page arguments
    -- @return[type=table] Created page
    --
    local ASP = function(...)
        -- Add invalid page name
        if type(arg[5]) ~= "boolean" then
            table.insert(arg, 1, -1);
        end
        -- Add default action
        if arg[6] == nil then
            arg[6] = function() end;
        elseif type(arg[6]) ~= "function" then
            table.insert(arg, 6, function() end);
        end
        -- Create short page
        local Page = AP {
            Name         = arg[1],
            Target       = arg[2],
            Title        = arg[3],
            Text         = arg[4],
            DialogCamera = arg[5],
            Action       = arg[6],
        };
        Page.Explore   = 0;
        Page.MiniMap   = false;
        Page.RenderFoW = false;
        Page.RenderSky = true;
        Page.Signal    = false;
        return Page;
    end

    ---
    -- Creates a simple multiple choice page.
    --
    -- Parameter order: [name, ] position, title, text, dialogCamera, action,
    -- option1Text, option1Target, ...
    --
    -- @param ... Page arguments
    -- @return[type=table] Created page
    --
    local AMC = function(...)
        -- Add invalid page name
        if type(arg[5]) ~= "boolean" then
            table.insert(arg, 1, -1);
        end
        -- Add default action
        if arg[6] == nil then
            arg[6] = function() end;
        elseif type(arg[6]) ~= "function" then
            table.insert(arg, 6, function() end);
        end
        -- Create short page
        local Page = AP {
            Name         = arg[1],
            Target       = arg[2],
            Title        = arg[3],
            Text         = arg[4],
            DialogCamera = arg[5],
            Action       = arg[6],
            MC           = {}
        };
        Page.Explore   = 0;
        Page.MiniMap   = false;
        Page.RenderFoW = false;
        Page.RenderSky = true;
        Page.Signal    = false;
        for i= 7, table.getn(arg), 2 do
            table.insert(Page.MC, {arg[i], arg[i+1], ID = math.ceil((i-6)/2)});
        end
        return Page;
    end
    return AP, ASP, AMC;
end

function QuestBriefing:IsBriefingActive(_PlayerID)
    local PlayerID = _PlayerID or GUI.GetPlayerID();
    if self.m_Book[PlayerID] then
        return true;
    end
    return false;
end

function QuestBriefing:IsBriefingActiveForAnyPlayer()
    for k, v in pairs(QuestSync:GetActivePlayers()) do
        if self:IsBriefingActive(v) then
            return true;
        end
    end
    return false;
end

function QuestBriefing:IsBriefingFinished(_ID)
    return QuestSystem.Briefings[_ID] == true;
end

function QuestBriefing:StartBriefing(_Briefing, _ID, _PlayerID)
    -- Transfer player ID
    if _PlayerID == nil and _ID ~= nil then
        _PlayerID = _ID;
        _ID = nil;
    end
    -- Set ID of briefing
    if _ID == nil then
        self.UniqieID = self.UniqieID +1;
        _ID = self.UniqieID;
    end

    -- Enqueue briefing if briefing is active
    if QuestBriefing:IsBriefingActive(_PlayerID) then
        self.m_Queue[_PlayerID] = self.m_Queue[_PlayerID] or {};
        table.insert(
            self.m_Queue[_PlayerID], {
                copy(_Briefing),
                self.UniqieID,
            }
        );

    -- Start briefing
    else
        self.m_Book[_PlayerID]             = copy(_Briefing);
        self.m_Book[_PlayerID].Exploration = {};
        self.m_Book[_PlayerID].ID          = self.UniqieID;
        self.m_Book[_PlayerID].Page        = 0;

        self:EnableCinematicMode(_PlayerID);
        if self.m_Book[_PlayerID].Starting then
            self.m_Book[_PlayerID]:Starting();
        end
        self:NextPage(_PlayerID, true);
    end
    -- Return briefing ID
    return self.UniqieID;
end

function QuestBriefing:EndBriefing(_PlayerID)
    -- Disable cinematic mode
    self:DisableCinematicMode(_PlayerID);
    -- Destroy explorations
    for k, v in pairs(self.m_Book[_PlayerID].Exploration) do
        DestroyEntity(v);
    end
    -- Call finished
    if self.m_Book[_PlayerID].Finished then
        self.m_Book[_PlayerID]:Finished();
    end
    -- Register briefing as finished
    QuestSystem.Briefings[self.m_Book[_PlayerID].ID] = true;
    -- Invalidate briefing
    self.m_Book[_PlayerID] = nil;
    -- Dequeue next briefing
    if self.m_Queue[_PlayerID] and table.getn(self.m_Queue[_PlayerID]) > 0 then
        local NewBriefing = table.remove(self.m_Queue[_PlayerID], 1);
        self:StartBriefing(NewBriefing[1], NewBriefing[2], _PlayerID);
    end
end

function QuestBriefing:NextPage(_PlayerID, _FirstPage)
    -- Check briefing exists
    if not self.m_Book[_PlayerID] then
        return;
    end
    -- Increment page
    self.m_Book[_PlayerID].Page = self.m_Book[_PlayerID].Page +1;
    -- End briefing if page does not exist
    local PageID = self.m_Book[_PlayerID].Page;
    local Page   = self.m_Book[_PlayerID][PageID];
    if not Page then
        self:EndBriefing(_PlayerID);
        return;
    elseif type(Page) ~= "table" then
        self.m_Book[_PlayerID].Page = self:GetPageID(Page, _PlayerID) -1;
        self:NextPage(_PlayerID, false);
        return;
    end
    -- Set start time
    self.m_Book[_PlayerID][PageID].StartTime = round(Logic.GetTime() * 10);
    -- Set position
    if Page.Target then
        self.m_Book[_PlayerID][PageID].Position = GetPosition(Page.Target);
    end
    -- Create exploration entity
    if Page.Target and Page.Explore and Page.Explore > 0 then
        local Position = GetPosition(Page.Target);
        local ID = Logic.CreateEntity(Entities.XD_ScriptEntity, Position.X, Position.Y, 0, _PlayerID);
        Logic.SetEntityExplorationRange(ViewCenter, math.ceil(Page.Explore/10));
        table.insert(self.m_Book[_PlayerID].Exploration, ID);
    end
    -- Render the page
    self:RenderPage(_PlayerID);
end

function QuestBriefing:CanPageBeSkipped(_PlayerID)
    -- Can not skip what does not exist
    if not self.m_Book[_PlayerID] then
        return false;
    end
    -- Skipping is disabled for the briefing
    if self.m_Book[_PlayerID].DisableSkipping then
        return false;
    end

    local PageID = self.m_Book[_PlayerID].Page;
    if self.m_Book[_PlayerID][PageID] then
        -- Skipping is disabled for the current page
        if self.m_Book[_PlayerID][PageID].DisableSkipping then
            return false;
        end
        -- Multiple choice can not be skipped
        if self.m_Book[_PlayerID][PageID].MC then
            return false;
        end
        -- 1.5 seconds must have passed between two page skips
        if math.abs(self.m_Book[_PlayerID][PageID].StartTime - (Logic.GetTime() * 10)) < 15 then
            return false;
        end
    end
    -- Page can be skipped
    return true;
end

function QuestBriefing:GetPageID(_Name, _PlayerID)
    local PlayerID = _PlayerID or GUI.GetPlayerID();
    -- Number is assumed valid ID
    if type(_Name) == "number" then
        return _Name;
    end
    -- Check briefing for page
    if self.m_Book[PlayerID] then
        for i= 1, table.getn(self.m_Book[PlayerID]), 1 do
            if self.m_Book[PlayerID][i].Name == _Name then
                return i;
            end
        end
    end
    -- Page not found
    return -1;
end

function QuestBriefing:RenderPage(_PlayerID)
    -- Only for local player
    if _PlayerID ~= GUI.GetPlayerID() then
        return;
    end
    -- Check page exists
    if not self.m_Book[_PlayerID] then
        return;
    end
    local Page = self.m_Book[_PlayerID][self.m_Book[_PlayerID].Page];
    if not Page then
        return;
    end
    -- Render signal
    if Page.Target and Page.Signal then
        local Position = GetPosition(Page.Target);
        GUI.ScriptSignal(Position.X, Position.Y, 0);
    end

    self:SetPageApperance(Page.MiniMap ~= true);
    local RenderFoW = (self.m_Book[_PlayerID].RenderFoW or Page.RenderFoW and 1) or 0;
    Display.SetRenderFogOfWar(RenderFoW);
    local RenderSky = (self.m_Book[_PlayerID].RenderSky or Page.RenderSky and 1) or 0;
    Display.SetRenderSky(RenderSky);
    Camera.ScrollUpdateZMode(0);
    Camera.FollowEntity(0);
    Mouse.CursorHide();
    
    if Page.Target then
        Page = self:AdjustBriefingPageCamHeight(Page);
        local EntityID = GetID(Page.Target);

        if not Page.CameraFlight then
            local Rotation = Logic.GetEntityOrientation(EntityID);
            if Logic.IsSettler(EntityID) == 1 then
                Rotation = Rotation +90;
                Camera.FollowEntity(EntityID);
            elseif Logic.IsBuilding(EntityID) == 1 then
                Rotation = Rotation -90;
                Camera.ScrollSetLookAt(Page.Position.X, Page.Position.Y);
            else
                Camera.ScrollSetLookAt(Page.Position.X, Page.Position.Y);
            end
            if Page.DialogCamera then
                Camera.ZoomSetDistance(Page.Distance or self.DialogZoomDistance);
                Camera.ZoomSetAngle(Page.Angle or self.DialogZoomAngle);
            else
                Camera.ZoomSetDistance(Page.Distance or self.BriefingZoomDistance);
                Camera.ZoomSetAngle(Page.Angle or self.BriefingZoomAngle);
            end
            Camera.RotSetAngle(Rotation or Page.Rotation or self.BriefingRotationAngle);
        else
            if not _LastPage then
                Camera.ScrollSetLookAt(Page.Position.X, Page.Position.Y);
                Camera.ZoomSetDistance(Page.Distance or self.BriefingZoomDistance);
                Camera.ZoomSetAngle(Page.Angle or self.BriefingZoomAngle);
                Camera.RotSetAngle(Page.Rotation or self.BriefingRotationAngle);
            else
                local x, y, z = Logic.EntityGetPos(GetID(_LastPage.Target));
                Camera.ScrollSetLookAt(x, y);
                Camera.ZoomSetDistance(_LastPage.Distance or self.BriefingZoomDistance);
                Camera.ZoomSetAngle(_LastPage.Angle or self.BriefingZoomAngle);
                Camera.RotSetAngle(_LastPage.Rotation or self.BriefingRotationAngle);

                Camera.InitCameraFlight();
                Camera.ZoomSetDistanceFlight(Page.Distance, Page.Duration);
                Camera.ZoomSetAngleFlight(Page.Angle, Page.Duration);
                Camera.RotFlight(Page.Rotation, Page.Duration);
                Camera.FlyToLookAt(Page.Position.X, Page.Position.Y, Page.Duration);
            end
        end
    end

    if Page.Title then
        self:PrintHeadline(Page.Title);
    end

    if Page.Text then
        self:PrintText(Page.Text);
        -- TODO: Start speech
    end

    if Page.Action then
        Page:Action(self.m_Book[_PlayerID]);
    end

    if Page.MC then
        self:PrintOptions(Page);
    else
        for i= 1, self.MCButtonAmount, 1 do
            XGUIEng.ShowWidget("CinematicMC_Button" ..i, 0);
        end
    end
end

function QuestBriefing:BriefingMCButtonSelected(_Selected)
    local PlayerID = GUI.GetPlayerID();
    QuestSync:SnchronizedCall(
        self.Events.PostOptionSelected,
        PlayerID,
        self.m_Book[PlayerID].Page,
        _Selected
    );
end

function QuestBriefing:ControlBriefing()
    for k, v in pairs(QuestSync:GetActivePlayers()) do
        if self.m_Book[v] then
            if self.m_Book[v] then
                -- Check page exists
                local PageID = self.m_Book[v].Page;
                if not self.m_Book[v][PageID] then
                    return false;
                end
                -- Stop briefing
                if type(self.m_Book[v][PageID]) == nil then
                    self:EndBriefing(v);
                    return false;
                end
                -- Jump to page
                if type(self.m_Book[v][PageID]) ~= "table" then
                    self.m_Book[v].Page = self:GetPageID(self.m_Book[v][PageID], v) -1;
                    self:NextPage(v, self.m_Book[v].Page > 0);
                    return false;
                end
                -- Calculate duration
                local Text       = self.m_Book[v][PageID].Text or "";
                local TextLength = (string.len(Text) +60) * self.TimerPerChar;
                local Duration   = self.m_Book[v][PageID].Duration or TextLength;
                -- Next page after duration is up
                local TimePassed = (Logic.GetTime() * 10) - self.m_Book[v][PageID].StartTime;
                if self:CanPageBeSkipped(v) and TimePassed > Duration then
                    self:NextPage(v, false);
                end
            end
        end
    end
end

---
-- Fakes camera hight on the unusable Z-achis. This function must be called
-- after all camera calculations are done.
-- @param[type=table] _Page Briefing page
-- @return[type=table] Page
-- @within Information
-- @local
--
function QuestBriefing:AdjustBriefingPageCamHeight(_Page)
    if _Page.Position then
        -- Set defaults
        _Page.Angle = _Page.Angle or ((_Page.DialogCamera and self.DialogZoomAngle) or self.BriefingZoomAngle);
        _Page.Rotation = _Page.Rotation or ((_Page.DialogCamera and self.DialogRotationAngle) or self.BriefingRotationAngle);
        _Page.Distance = _Page.Distance or ((_Page.DialogCamera and self.DialogZoomDistance) or self.BriefingZoomDistance);
        -- Set height
        if Logic.IsSettler(GetID(_Page.Target)) == 1 then
            _Page.Height = _Page.Height or self.FakeHeight;
        else
            _Page.Height = _Page.Height or 0;
        end
        if _Page.Angle >= 90 then
            _Page.Height = 0;
        end

        if _Page.Height > 0 and _Page.Angle > 0 and _Page.Angle < 90 then
            local AngleTangens = _Page.Height / math.tan(math.rad(_Page.Angle));
            local RotationRadiant = math.rad(_Page.Rotation or -45);
            -- Save backup for when page is visited again
            if not _Page.PositionOriginal then
                _Page.PositionOriginal = _Page.Position;
            end

            -- New position
            local NewPosition = {
                X = _Page.PositionOriginal.X - math.sin(RotationRadiant) * AngleTangens,
                Y = _Page.PositionOriginal.Y + math.cos(RotationRadiant) * AngleTangens
            };
            -- Update if valid position
            if NewPosition.X > 0 and NewPosition.Y > 0 and NewPosition.X < Logic.WorldGetSize() and NewPosition.Y < Logic.WorldGetSize() then
                -- Save backup for when page is visited again
                if not _Page.ZoomOriginal then
                    _Page.ZoomOriginal = _Page.Distance;
                end
                _Page.Distance = _Page.ZoomOriginal + math.sqrt(math.pow(_Page.Height, 2) + math.pow(AngleTangens, 2));
                _Page.Position = NewPosition;
            end
        end
    end
    return _Page;
end

function QuestBriefing:PrintHeadline(_Text)
    -- Localize text
    local Language = QuestTools.GetLanguage();
    if type(_Text) == "table" then
        _Text = _Text[Language];
    end
    -- Add title format
    if not string.find(string.sub(_Text, 1, 2), "@") then
        _Text = "@center " .._Text;
    end
    -- String table text or replace placeholders
    if string.find(_Text, "^%w/%w$") then
        _Text = XGUIEng.GetStringTableText(_Text);
    else
        _Text = QuestSystem:ReplacePlaceholders(_Text);
    end
    XGUIEng.SetText("CinematicMC_Headline", _Text or "");
end

function QuestBriefing:PrintText(_Text)
    -- Localize text
    local Language = QuestTools.GetLanguage();
    if type(_Text) == "table" then
        _Text = _Text[Language];
    end
    -- String table text or replace placeholders
    if string.find(_Text, "^%w/%w$") then
        _Text = XGUIEng.GetStringTableText(_Text);
    else
        _Text = QuestSystem:ReplacePlaceholders(_Text);
    end
    XGUIEng.SetText("CinematicMC_Text", _Text or "");
end

function QuestBriefing:PrintOptions(_Page)
    local Language = QuestTools.GetLanguage();
    if _Page.MC then
        Mouse.CursorShow();
        for i= 1, table.getn(_Page.MC), 1 do
            if self.MCButtonAmount >= i then
                -- Button highlight fix
                XGUIEng.ShowWidget("CinematicMC_Button" ..i, 1);
                XGUIEng.DisableButton("CinematicMC_Button" ..i, 1);
                XGUIEng.DisableButton("CinematicMC_Button" ..i, 0);
                -- Localize text
                local Text = _Page.MC[i][1];
                if type(Text) == "table" then
                    Text = Text[Language];
                end
                -- String table text or replace placeholders
                if string.find(Text, "^%w/%w$") then
                    Text = XGUIEng.GetStringTableText(Text);
                else
                    Text = QuestSystem:ReplacePlaceholders(Text);
                end
                -- Set text
                XGUIEng.SetText("CinematicMC_Button" ..i, Text or "");
            end
        end
    end
end

function QuestBriefing:EnableCinematicMode(_PlayerID)
    local PlayerID = GUI.GetPlayerID();
    if PlayerID ~= _PlayerID then
        return;
    end
    if self.m_Book[PlayerID].RestoreCamera then
        local x, y = Camera.ScrollGetLookAt();
        self.m_Book[PlayerID].RestorePosition = {X= x, Y= y};
    end
    GUIAction_GoBackFromHawkViewInNormalView();
    Interface_SetCinematicMode(1);
    Camera.StopCameraFlight();
    Camera.ScrollUpdateZMode(0);
    Camera.RotSetAngle(-45);
    Display.SetRenderFogOfWar(0);
    GUI.MiniMap_SetRenderFogOfWar(1);
    Display.SetRenderSky(1);
    GUI.EnableBattleSignals(false);
    Sound.PlayFeedbackSound(0,0);
    Input.CutsceneMode();
    GUI.SetFeedbackSoundOutputState(0);
    Logic.SetGlobalInvulnerability(1);
    LocalMusic.SongLength = 0;

    XGUIEng.ShowWidget("Cinematic",1);
    XGUIEng.ShowWidget("Cinematic_Text",0);
    XGUIEng.ShowWidget("Cinematic_Headline",0);
    XGUIEng.ShowWidget("CinematicMC_Container", 1);
    XGUIEng.ShowWidget("CinematicMC_Text", 1);
    XGUIEng.ShowWidget("CinematicMC_Headline", 1);
    XGUIEng.ShowWidget("CinematicMiniMapContainer",1);
end

function QuestBriefing:DisableCinematicMode(_PlayerID)
    local PlayerID = GUI.GetPlayerID();
    if PlayerID ~= _PlayerID then
        return;
    end
    if self.m_Book[PlayerID].RestorePosition then
        local Position = self.m_Book[PlayerID].RestorePosition;
        Camera.ScrollSetLookAt(Position.X, Position.Y);
    end
    Interface_SetCinematicMode(0);
    Display.SetRenderFogOfWar(1);
    Display.SetRenderSky(0);
    Logic.SetGlobalInvulnerability(0);
    GUI.EnableBattleSignals(true);
    GUI.ActivateSelectionState();
    Input.GameMode();
    GUI.SetFeedbackSoundOutputState(1);
    Stream.Stop();
    LocalMusic.SongLength = 0;

    XGUIEng.ShowWidget("Normal",1);
    XGUIEng.ShowWidget("3dOnScreenDisplay",1);
    XGUIEng.ShowWidget("Cinematic",0);
    XGUIEng.ShowWidget("CinematicMiniMapContainer",0);
end

function QuestBriefing:SetPageApperance(_DisableMap)
    local size = {GUI.GetScreenSize()};
    local Is4To3 = (size[2]/3) * 4 == size[1];
    local button1Y = (size[2]*(768/size[2]))-10;
    local button2Y = (size[2]*(768/size[2]))-10;
    local titlePosY = 45;
    local textPosY = ((size[2]*(768/size[2])))-100;
    local titleSize = (size[1]-200);
    local choiceHeight = round(46*(768/size[2]));
    local choiceWidth  = round(800*(1024/size[1]));
    local choicePosX   = round(((Is4To3 and 112) or 112*1.4)*(size[1]/1024));
    local choicePosY   = round(((size[2]*(768/size[2]))/2) - ((self.MCButtonAmount/2)*(choiceHeight+10)));

    -- Set widget apperance
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Container",0,0,size[1],size[2]);
    for i= 1, self.MCButtonAmount, 1 do
        XGUIEng.SetWidgetPositionAndSize("CinematicMC_Button" ..i, choicePosX, choicePosY, choiceWidth, choiceHeight);
        choicePosY = choicePosY + ((choiceHeight+10) * (i));
    end
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Text",(200),textPosY,(680),100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Text",(200),textPosY,(680),100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Headline",100,titlePosY,titleSize,15);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Headline",100,titlePosY,titleSize,15);
    XGUIEng.SetWidgetPositionAndSize("CinematicBar01",0,size[2],size[1],180);
    XGUIEng.SetMaterialTexture("CinematicBar02", 0, "data/graphics/textures/gui/cutscene_top.dds");
    XGUIEng.SetMaterialColor("CinematicBar02", 0, 255, 255, 255, 255);
    XGUIEng.SetWidgetPositionAndSize("CinematicBar02", 0, 0, size[1], 180);

    -- Set widget visability
    XGUIEng.ShowWidget("CinematicMiniMapOverlay", (_DisableMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicMiniMap", (_DisableMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicFrameBG", (_DisableMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicFrame", (_DisableMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicBar02", 1);
    XGUIEng.ShowWidget("CinematicBar01", 1);
    XGUIEng.ShowWidget("CinematicBar00", 0);
end

