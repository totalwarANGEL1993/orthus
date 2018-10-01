-- ########################################################################## --
-- #  Interaction                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module adds some briefing improvements. Some are just for cosmetics,
-- some are fixing pittful bugs, some offer helpful new features.
--
-- @set sort=true
--

Information = {
    Fader = {
        IsFadeIn = false,
        StartTime = 0,
        Duration = 0,
    }
}

---
-- Installs the information mod.
-- @within Information
-- @local
--
function Information:Install()
    self:OverrideMultipleChoice();
    self:OverrideCinematic();
    self:OverrideEscape();
    self:CreateAddPageFunctions();
end

---
-- Returns the number of the extension.
-- @return [number] Extension number
-- @within Information
-- @local
--
function Information:GetExtraNumber()
    return tonumber(string.sub(Framework.GetProgramVersion(), string.len(Version)));
end

---
-- Initalizes the add pages functions for simpler briefing pages.
-- @within Information
-- @local
--
function Information:CreateAddPageFunctions()
    ---
    -- Creates the local briefing functions for adding pages.
    --
    -- Functions created:
    -- <ul>
    -- <li>AP: Creates normal pages and multiple choice pages. You have full
    -- control over all settings.</li>
    -- <li>ASP: Creates a simplyfied page. A short notation good for dialogs.
    -- can be used in talkative missions.</li>
    -- </ul>
    --
    -- @param _briefing [table] Briefing
    -- @return [function] AP function
    -- @return [function] ASP function
    --
    function AddPages(_briefing)
        local AP = function(_page)
            if _page then
                -- Set position before page is add
                if type(_page.position) ~= "table" then
                    _page.entity   = _page.position;
                    _page.position = GetPosition(_page.position);
                end
                -- Set title before page is add
                if _page.title then
                    _page.title = "@center " .. _page.title;
                end
                -- Set text before page is add
                if _page.mc and _page.mc.title then
                    _page.mc.title = "@center " .. _page.mc.title;
                end

                if _page.action then
                    _page.actionOrig = _page.action;
                end
                _page.action = function()
                    local ori, zoom, ang;

                    -- Get zoom distance
                    local ZoomDistance = BRIEFING_ZOOMDISTANCE;
                    if _page.dialogCamera then
                        ZoomDistance = DIALOG_ZOOMDISTANCE;
                    end
                    ZoomDistance = (_page.zoom ~= nil and _page.zoom) or ZoomDistance;
                    _page.zoom = ZoomDistance;

                    -- Get zoom angle
                    local ZoomAngle = BRIEFING_ZOOMANGLE;
                    if _page.dialogCamera then
                        ZoomAngle = DIALOG_ZOOMANGLE;
                    end
                    ZoomAngle = (_page.angle ~= nil and _page.angle) or ZoomAngle;
                    _page.angle = ZoomAngle;

                    -- Get rotation angle
                    local RotationAngle = -45;
                    if _page.lookAt and _page.entity then
                        RotationAngle = Logic.GetEntityOrientation(GetID(_page.entity));
                        if Logic.IsSettler(GetID(_page.entity)) == 1 then
                            RotationAngle = RotationAngle + 90;
                        end
                    end
                    RotationAngle = (_page.rotation ~= nil and _page.rotation) or RotationAngle;
                    _page.rotation = RotationAngle;

                    -- Disable fog
                    Display.SetRenderFogOfWar(1);
                    if _page.disableFog then
                        Display.SetRenderFogOfWar(0);
                    end

                    -- Display sky
                    Display.SetRenderSky(0);
                    if _page.showSky then
                        Display.SetRenderSky(1);
                    end

                    -- Override camera flight
                    Camera.StopCameraFlight();
                    if not _page.flyTime then
                        Camera.ZoomSetDistance(ZoomDistance);
                        Camera.ZoomSetAngle(ZoomAngle);
                        Camera.RotSetAngle(RotationAngle);
                        Camera.ScrollSetLookAt(_page.position.X, _page.position.Y);
                    else
                        briefingState.nextPageDelayTime = (_page.flyTime * 10) +1;
                        briefingState.timer = (_page.flyTime * 10) +1;

                        if briefingState.page > 0 then
                            local LastPage = briefingBook[1][briefingState.page];

                            Camera.ZoomSetDistance(LastPage.zoom or BRIEFING_ZOOMDISTANCE);
                            Camera.ZoomSetAngle(LastPage.angle or BRIEFING_ZOOMANGLE);
                            Camera.RotSetAngle(LastPage.rotation or -45);
                            Camera.ScrollSetLookAt(LastPage.position.X, LastPage.position.Y);

                            Camera.ScrollUpdateZMode(0);
                            Camera.InitCameraFlight();
                            Camera.ZoomSetDistanceFlight(ZoomDistance, _page.flyTime);
                            Camera.ZoomSetAngleFlight(ZoomAngle, _page.flyTime);
                            Camera.RotFlight(RotationAngle, _page.flyTime);
                            Camera.FlyToLookAt(_page.position.X, _page.position.Y, _page.flyTime);
                        else
                            Camera.ZoomSetDistance(_page.zoom);
                            Camera.ZoomSetAngle(_page.angle);
                            Camera.RotSetAngle(_page.rotation);
                            Camera.ScrollSetLookAt(_page.position.X, _page.position.Y);
                        end
                    end

                    -- Call original action
                    if _page.actionOrig then
                        _page.actionOrig();
                    end
                end
            end
            table.insert(_briefing, _page);
            _page.id = table.getn(_briefing);
            return _page;
        end
        local ASP = function(_entity, _title, _text, _dialog, _action)
            return AP(CreateShortPage(_entity, _title, _text, _dialog, _action));
        end
        return AP, ASP;
    end

    function CreateShortPage(_entity, _title, _text, _dialog, _action)
        local page = {
            title = _title,
            text = _text,
            position = _entity,
            dialogCamera = (_dialog or false),
            action = _action,
            lookAt = true;
        };
        return page;
    end
end

---
-- Overrides the escape callback.
-- @within Information
-- @local
--
function Information:OverrideEscape()
    GameCallback_Escape_Orig_Information = GameCallback_Escape;
    GameCallback_Escape = function()
        -- Briefing no escape
        if IsBriefingActive() then
            if briefingState.noEscape then
                return;
            end
        end
        -- Escape cutscene
        if gvCutscene then
			gvCutscene.Skip = true;
		end

        GameCallback_Escape_Orig_Information();
	end
end

---
-- Overrides the briefing and cutscene functions that enter or leave the
-- cinematic mode.
--
-- Issues:
-- <ul>
-- <li>Implements the noEscape swith for briefings</li>
-- <li>Fixes the buggy game clock</li>
-- </ul>
--
-- @within Information
-- @local
--
function Information:OverrideCinematic()
    -- Briefings --

    StartBriefing_Orig_Information = StartBriefing;
    StartBriefing = function(_briefing)
        assert(type(_briefing) == "table");
        if _briefing.noEscape then
            briefingState.noEscape = true;
        end
        if XGUIEng.IsWidgetShown("GameClock") == 1 then
			XGUIEng.ShowWidget("GameClock", 0);
			gvGameClockWasShown = true;
        end
		Game.GameTimeReset();
        GUI.ClearNotes();
        return StartBriefing_Orig_Information(_briefing);
    end

    EndBriefing_Orig_Information = EndBriefing;
    EndBriefing = function()
        if briefingState.noEscape then
            briefingState.noEscape = nil;
        end
        if gvGameClockWasShown then
			XGUIEng.ShowWidget("GameClock", 1);
			gvGameClockWasShown = false;
        end
        Display.SetRenderFogOfWar(1);
        Display.SetRenderSky(0);
        return EndBriefing_Orig_Information();
    end

    -- Cutscenes --

    if StartCutscene then
        StartCutscene_Orig_Information = StartCutscene;
        StartCutscene = function(_Cutscene,_SkipCutscene)
            Information:SetBriefingLooks(true);
            Game.GameTimeReset();
            GUI.ClearNotes();

            if XGUIEng.IsWidgetShown("GameClock") == 1 then
				XGUIEng.ShowWidget("GameClock",0)
				gvGameClockWasShown = true
			end
            return StartCutscene_Orig_Information(_Cutscene,_SkipCutscene);
        end
    end

    if CutsceneDone then
        CutsceneDone_Orig_Information = CutsceneDone;
        CutsceneDone = function()
            if gvGameClockWasShown then
				XGUIEng.ShowWidget("GameClock",1)
				gvGameClockWasShown = false
			end
			return CutsceneDone_Orig_Information();
		end
    end
end

---
-- Overrides the multiple choice functions.
--
-- Issues:
-- <ul>
-- <li>Both MC buttons can now have a callback function</li>
-- <li>MC are no longer permamently highlighted</li>
-- </ul>
--
-- @within Information
-- @local
--
function Information:OverrideMultipleChoice()
    BriefingMCButtonSelected = function(_index)
		assert(briefingBook[1][briefingState.page].mc ~= nil);
		briefingBook[1][briefingState.page].mc.selectedButton = _index;

		if _index == 1 then
			if briefingBook[1][briefingState.page].mc.firstSelected ~= nil then
				briefingState.page = briefingBook[1][briefingState.page].mc.firstSelected - 1;
			else
				assert(briefingBook[1][briefingState.page].mc.firstSelectedCallback);
				briefingState.page = briefingBook[1][briefingState.page].mc.firstSelectedCallback(briefingBook[1][briefingState.page])-1;
			end
		else
			if briefingBook[1][briefingState.page].mc.secondSelected ~= nil then
				briefingState.page = briefingBook[1][briefingState.page].mc.secondSelected - 1;
			else
				assert(briefingBook[1][briefingState.page].mc.secondSelectedCallback);
				briefingState.page = briefingBook[1][briefingState.page].mc.secondSelectedCallback(briefingBook[1][briefingState.page])-1;
			end
		end

		XGUIEng.ShowWidget("CinematicMC_Container",0);
		briefingState.timer = 0;
		briefingState.waitingForMC = false;
		Mouse.CursorHide();
    end

    Briefing_Extra = function(_page,_firstPage)
        -- Button fix
        for i = 1, 2 do
            local theButton = "CinematicMC_Button" .. i;
            XGUIEng.DisableButton(theButton, 1);
            XGUIEng.DisableButton(theButton, 0);
        end

        -- Action
        if _page.action then
            assert( type(_page.action) == "function" );
            _page.action(_page);
        end

        -- change bar design
        Information:SetBriefingLooks(true);
        if _page.minimap == true then
            Information:SetBriefingLooks(false);
        end

        -- Display multiple choice
		if _page.mc ~= nil then
			if _page.mc.text ~= nil then
				assert(_page.mc.title~=nil);
				PrintBriefingHeadline(_page.mc.title);
				PrintBriefingText(_page.mc.text);

				assert(_page.mc.firstText~=nil);
				assert(_page.mc.secondText~=nil);
				PrintMCButton1Text(_page.mc.firstText);
				PrintMCButton2Text(_page.mc.secondText);

				XGUIEng.ShowWidget("CinematicMC_Container",1);
				XGUIEng.ShowWidget("CinematicMC_Text",0);
				XGUIEng.ShowWidget("CinematicMC_Headline",0);
				XGUIEng.ShowWidget("CinematicBar01",1);
				Mouse.CursorShow();
                briefingState.waitingForMC = true;
				return;
			end
		end

		-- hide bars
		if _page.hideBars == true then
			XGUIEng.ShowWidget("CinematicBar02",0);
            XGUIEng.ShowWidget("CinematicBar01",0);
            XGUIEng.ShowWidget("CinematicBar00",0);
		end
	end
end

---
-- Sets the apperance of the cinematic mode.
-- @param _DisableMap [boolean] Hide the minimap
-- @within Information
-- @local
--
function Information:SetBriefingLooks(_DisableMap)
    local size = {GUI.GetScreenSize()};
    local choicePosY = (size[2]*(768/size[2]))-240;
    local button1Y = (size[2]*(768/size[2]))-10;
    local button2Y = (size[2]*(768/size[2]))-10;
    local titlePosY = 45;
    local textPosY = ((size[2]*(768/size[2])))-100;
    local button1SizeX = (((size[1]*(1024/size[1])))-660);
    local button2SizeX = (((size[1]*(1024/size[1])))-660);
    local titleSize = (size[1]-200);
    local bottomBarX = (size[2]*(768/size[2]))-85;
    local bottomBarY = (size[2]*(768/size[2]))-85;

    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Container",0,0,size[1],size[2]);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Button1",200,button1Y,button1SizeX,46);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Button2",570,button2Y,button2SizeX,46);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Text",(200),textPosY,(680),100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Text",(200),textPosY,(680),100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Headline",100,titlePosY,titleSize,15);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Headline",100,titlePosY,titleSize,15);
    XGUIEng.SetWidgetPositionAndSize("CinematicBar01",0,size[2],size[1],185);
    XGUIEng.SetWidgetSize("CinematicBar00",size[1],180);
    XGUIEng.ShowWidget("CinematicBar02",0);
    XGUIEng.ShowWidget("CinematicBar01",1);
    XGUIEng.ShowWidget("CinematicBar00",1);

    XGUIEng.ShowWidget("CinematicMiniMapOverlay", (_DisableMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicMiniMap", (_DisableMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicFrameBG", (_DisableMap and 0) or 1);
    XGUIEng.ShowWidget("CinematicFrame", (_DisableMap and 0) or 1);
end

---
-- Starts a fading process. If it is already fading than the old process will
-- be aborted.
-- @param _Duration [number] Duration of fading in seconds
-- @param _FadeIn [boolean] Fade in from black
-- @within Information
-- @local
function Information:StartFader(_Duration, _FadeIn)
    self.Fader.Duration = _Duration * 100;
    self.Fader.StartTime = Logic.GetTimeMs();
    self.Fader.IsFadeIn = _FadeIn == true;
    Information:SetFaderAlpha(0);
    if _FadeIn then
        Information:SetFaderAlpha(1);
    end
    if self.Fader.JobID and JobIsRunning(self.Fader.JobID) then
        EndJob(self.Fader.JobID);
    end
    self.Fader.JobID = StartSimpleHiResJob("Information_FadingController");
end

---
-- Sets the alpha value of the fader mask.
-- @param _AlphaFactor [number] Alpha factor
-- @within Information
-- @local
function Information:SetFaderAlpha(_AlphaFactor)
    local sX, sY = GUI.GetScreenSize();
    local WidgetID = XGUIEng.GetWidgetID("CinematicBar02");
    XGUIEng.SetWidtetPositionAndSize(WidgetID, 0, 0, sX, sY);
    XGUIEng.SetMaterialTexture(WidgetID, 0, "");
    XGUIEng.SetMaterialColor(WidgetID, 0, 0, 0, 0, math.floor(255 * _AlphaFactor));
end

---
-- Returns the factor for the alpha value of the fader mask.
-- @return [number] Alpha factor
-- @within Information
-- @local
function Information:GetFadingFactor()
    local CurrentTime = Logic.GetTimeMs();
    local FadingFactor = CurrentTime / (self.Fader.StartTime + self.Fader.Duration);
    if self.Fader.IsFadeIn then
        FadingFactor = 1 - FadingFactor;
    end
    return FadingFactor;
end

---
-- Controlls the fading process.
-- @within Information
-- @loca
function Information_FadingController()
    if Logic.GetTimeMs() > self.Fader.StartTime + self.Fader.Duration then
        return true;
    end
    Information:SetFaderAlpha(Information:GetFadingFactor());
    PrintBriefingHeadline("");
    PrintBriefingText("");
end

-- Countdown code --------------------------------------------------------------

---
-- Starts a visible or invisible countdown.
--
-- <b>Note:</b> There can only be one visible but infinit invisible countdonws.
--
-- @param _Limit [number] Time to count down
-- @param _Callback [function] Countdown callback
-- @param _Show [boolean] Countdown visible
--
function StartCountdown(_Limit, _Callback, _Show)
    assert(type(_Limit) == "number")
    assert( not _Callback or type(_Callback) == "function" )
    Counter.Index = (Counter.Index or 0) + 1
    if _Show and CountdownIsVisisble() then
        assert(false, "StartCountdown: A countdown is already visible")
    end
    Counter["counter" .. Counter.Index] = {Limit = _Limit, TickCount = 0, Callback = _Callback, Show = _Show, Finished = false}
    if _Show then
        MapLocal_StartCountDown(_Limit)
    end
    if Counter.JobId == nil then
        Counter.JobId = StartSimpleJob("CountdownTick")
    end
    return Counter.Index
end

---
-- Stops the countdown with the ID.
-- @param _Id [number] Countdown ID
--
function StopCountdown(_Id)
    if Counter.Index == nil then
        return
    end
    if _Id == nil then
        for i = 1, Counter.Index do
            if Counter.IsValid("counter" .. i) then
                if Counter["counter" .. i].Show then
                    MapLocal_StopCountDown()
                end
                Counter["counter" .. i] = nil
            end
        end
    else
        if Counter.IsValid("counter" .. _Id) then
            if Counter["counter" .. _Id].Show then
                MapLocal_StopCountDown()
            end
            Counter["counter" .. _Id] = nil
        end
    end
end

function CountdownTick()
    local empty = true
    for i = 1, Counter.Index do
        if Counter.IsValid("counter" .. i) then
            if Counter.Tick("counter" .. i) then
                Counter["counter" .. i].Finished = true
            end
            if Counter["counter" .. i].Finished and not IsBriefingActive() then
                if Counter["counter" .. i].Show then
                    MapLocal_StopCountDown()
                end
                if type(Counter["counter" .. i].Callback) == "function" then
                    Counter["counter" .. i].Callback()
                end
                Counter["counter" .. i] = nil
            end
            empty = false
        end
    end
    if empty then
        Counter.JobId = nil
        Counter.Index = nil
        return true
    end
end

---
-- Returns true if a countdown is visible.
-- @return [boolean] Visible countdown
--
function CountdownIsVisisble()
    for i = 1, Counter.Index do
        if Counter.IsValid("counter" .. i) and Counter["counter" .. i].Show then
            return true
        end
    end
    return false
end
