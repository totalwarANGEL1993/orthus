-- ########################################################################## --
-- #  Interaction                                                           # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module adds some briefing improvements. Some are just for cosmetics,
-- some are fixing pittful bugs, some offer helpful new features. This is the
-- version for the vanilla game.
-- For Extra 3 we will using mcbBrief by mcb. This will offer at least equal
-- features or maybe even more advanced.
--
-- @set sort=true
--

Information = {
    Fader = {
        IsFading = false,
        IsFadeIn = false,
        StartTime = 0,
        Duration = 0,
    },
    Constants = {
        BriefingZoomDistance = 4000,
        BriefingZoomAngle    = 48,
        DialogZoomDistance   = 1200,
        DialogZoomAngle      = 25,
    }
};

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
-- @return[type=number] Extension number
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
    -- control over all settings. It is also possible to do cutscene like
    -- camera animations.</li>
    -- <li>ASP: Creates a simplyfied page. A short notation good for dialogs.
    -- can be used in talkative missions.</li>
    -- </ul>
    --
    -- @param[type=table] _briefing Briefing
    -- @return[type=function] AP function
    -- @return[type=function] ASP function
    --
    function AddPages(_briefing)
        local AP = function(_page)
            if _page then
                if type(_page) == "table" then
                    -- Set position before page is add
                    if type(_page.position) ~= "table" then
                        _page.entity   = _page.position;
                        _page.position = GetPosition(_page.position);
                    end
                    -- Set title before page is add
                    if _page.title and string.sub(_page.title, 1, 1) ~= "@" then
                        _page.title = "@center " .. _page.title;
                    end
                    if _page.mc and _page.mc.title and string.sub(_page.mc.title, 1, 1) ~= "@" then
                        _page.mc.title = "@center " .. _page.mc.title;
                    end

                    if _page.action then
                        _page.actionOrig = _page.action;
                    end
                    _page.action = function()
                        local ZoomDistance = Information:AdjustBriefingPageZoom(_page);
                        local ZoomAngle = Information:AdjustBriefingPageAngle(_page);
                        local RotationAngle = Information:AdjustBriefingPageRotation(_page);
                        local PagePosition = Information:AdjustBriefingPageCamHeight(_page);

                        -- Fader
                        Information:InitalizeFaderForBriefingPage(_page);

                        -- Disable fog only on this page
                        -- (does not overwrite global settings)
                        if _page.disableFog then
                            Display.SetRenderFogOfWar(0);
                        end

                        -- Display sky only on this page
                        -- (does not overwrite global settings)
                        if _page.showSky then
                            Display.SetRenderSky(1);
                        end

                        -- Override camera flight
                        Camera.StopCameraFlight();
                        if not _page.flight then
                            Camera.ZoomSetDistance(ZoomDistance);
                            Camera.ZoomSetAngle(ZoomAngle);
                            Camera.RotSetAngle(RotationAngle);
                            Camera.ScrollSetLookAt(_page.position.X, _page.position.Y);
                        else
                            briefingState.nextPageDelayTime = (_page.duration * 10) +1;
                            briefingState.timer = (_page.duration * 10) +1;

                            -- A flight can only be started from page 2 and forward because it needs the position of
                            -- the last page as starting point for the camera movement. Flights aren't a replacement
                            -- for cutscenes so keep your animations short!
                            -- Keep in mind that there is no z achsis with camera animations!

                            if briefingState.page > 0 then
                                local LastPage = briefingBook[1][briefingState.page];

                                Camera.InitCameraFlight();
                                
                                Camera.ZoomSetDistance(LastPage.zoom or BRIEFING_ZOOMDISTANCE);
                                Camera.ZoomSetAngle(LastPage.angle or BRIEFING_ZOOMANGLE);
                                Camera.RotSetAngle(LastPage.rotation or -45);
                                Camera.ScrollSetLookAt(LastPage.position.X, LastPage.position.Y);

                                Camera.ZoomSetDistanceFlight(ZoomDistance, _page.duration);
                                Camera.ZoomSetAngleFlight(ZoomAngle, _page.duration);
                                Camera.RotFlight(RotationAngle, _page.duration);
                                Camera.FlyToLookAt(_page.position.X, _page.position.Y, _page.duration);
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

                -- Jumping to a page
                elseif type(_page) == "string" or type(_page) == "number" then
                    page = {
                        target = _page,
                        action = function(self)
                            local PageID = Information:GetPageID(self.target);
                            if (PageID > 0 and PageID <= table.getn(briefingBook[1])) then
                                briefingState.nextPageDelayTime = 0;
                                briefingState.timer = 0;
                                briefingState.page = PageID;
                                Briefing(briefingBook[1][briefingState.page], briefingState.page == 0);
                                miniMapResetCounter = 0;
                            end
                        end
                    };
                end
                _page.id = table.getn(_briefing);
            end
            table.insert(_briefing, _page);
            return _page;
        end
        
        local ASP = function(...)
            if (table.getn(arg) == 7) then
                table.insert(arg, 1, -1);
            end
            return AP(CreateShortPage(unpack(arg)));
        end

        local ASMC = function(...)
            if (table.getn(arg) == 11) then
                table.insert(arg, 1, -1);
            end
            return AP(CreateShortMCPage(unpack(arg)));
        end
        return AP, ASP, ASMC;
    end

    function CreateShortPage(...)
        local page = {
            name         = arg[1],
            title        = arg[3],
            text         = arg[4],
            position     = arg[2],
            dialogCamera = arg[5] == true,
            action       = arg[6],
            lookAt       = true;
            disableFog   = arg[8],
            showSky      = arg[7],
        };
        return page;
    end

    function CreateShortMCPage(...)
        local page = {
            name         = arg[1],
            position     = arg[2],
            dialogCamera = arg[5] == true,
            action       = arg[6],
            lookAt       = true;
            disableFog   = arg[8],
            showSky      = arg[7],

            mc           = {
                title	       = arg[3],
                text 	       = arg[4],
                firstText      = arg[9],
                secondText     = arg[11],
                firstSelected  = arg[10],
                secondSelected = arg[12],
            },
        };
        return page;
    end
end

---
-- Returns the page id to the page name. If a name is not found a absurd high
-- page ID is providet to prevent lua errors.
-- @param[type=string] _Name Name of page
-- @return[type=number] Page ID
--
function Information:GetPageID(_Name)
    if IsBriefingActive() then
        for k, v in pairs(briefingBook[1]) do
            if type(v) == "table" then
                if type(_Name) == "string" then
                    if v.name == _Name then
                        return k;
                    end
                else
                    return _Name;
                end
            end
        end
    end
    return 999999;
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
-- Overrides the briefing functions that enter or leave the cinematic mode.
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
    StartBriefing_Orig_Information = StartBriefing;
    StartBriefing = function(_briefing)
        assert(type(_briefing) == "table");
        local ID = StartBriefing_Orig_Information(_briefing);
        
        -- Disable escape skipping
        if _briefing.noEscape then
            briefingState.noEscape = true;
        end
        -- Don't render fog
        if _briefing.disableFog then
            Display.SetRenderFogOfWar(0);
        end
        -- Render sky
        if _briefing.showSky then
            Display.SetRenderSky(1);
        end

        if XGUIEng.IsWidgetShown("GameClock") == 1 then
			XGUIEng.ShowWidget("GameClock", 0);
			gvGameClockWasShown = true;
        end
		Game.GameTimeReset();
        GUI.ClearNotes();
        return ID;
    end

    EndBriefing_Orig_Information = EndBriefing;
    EndBriefing = function()
        EndBriefing_Orig_Information();
        if briefingState.noEscape then
            briefingState.noEscape = nil;
        end
        if gvGameClockWasShown then
			XGUIEng.ShowWidget("GameClock", 1);
			gvGameClockWasShown = false;
        end
        Information:SetFaderAlpha(0);
        Information:StopFader();

        Display.SetRenderFogOfWar(1);
        Display.SetRenderSky(0);
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
            -- Get page ID or name
            local PageID;
            if briefingBook[1][briefingState.page].mc.firstSelected ~= nil then
                PageID = briefingBook[1][briefingState.page].mc.firstSelected;
			else
				assert(briefingBook[1][briefingState.page].mc.firstSelectedCallback);
                PageID = briefingBook[1][briefingState.page].mc.firstSelectedCallback(briefingBook[1][briefingState.page]);
            end
            -- Get id if name
            if type(PageID) == "string" then
                PageID = Information:GetPageID(PageID);
            end
            briefingState.page = PageID -1;
        else
            -- Get page ID or name
            local PageID;
			if briefingBook[1][briefingState.page].mc.secondSelected ~= nil then
                PageID = briefingBook[1][briefingState.page].mc.secondSelected;
			else
				assert(briefingBook[1][briefingState.page].mc.secondSelectedCallback);
				PageID = briefingBook[1][briefingState.page].mc.secondSelectedCallback(briefingBook[1][briefingState.page]);
            end
            -- Get id if name
            if type(PageID) == "string" then
                PageID = Information:GetPageID(PageID);
            end
            briefingState.page = PageID -1;
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
        local MinimapFlag = _page.minimap ~= true;
        Information:SetBriefingLooks(MinimapFlag);
        if _page.centeredText == true then
            Information:SetTextCentered(MinimapFlag);
        end
        if _page.creditsText == true then
            Information:SetTextCenteredCredits(MinimapFlag);
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
-- Fakes camera hight on the unusable Z-achis. This function must be called
-- after all camera calculations are done.
-- @param[type=table] _Page Briefing page
-- @within Information
-- @local
--
function Information:AdjustBriefingPageCamHeight(_Page)
    _Page.height = _Page.height or 90;
    if _Page.angle >= 90 then
        _Page.height = 0;
    end
	if _Page.height > 0 and _Page.angle > 0 and _Page.angle < 90 then
		local AngleTangens = _Page.height / math.tan(math.rad(_Page.angle))
		local RotationRadiant = math.rad(_Page.rotation)
        -- New position
        local NewPosition = {
            X = _Page.position.X - math.sin(RotationRadiant) * AngleTangens,
            Y = _Page.position.Y + math.cos(RotationRadiant) * AngleTangens
        };
        -- Update if valid position
		if NewPosition.X > 0 and NewPosition.Y > 0 and NewPosition.X < Logic.WorldGetSize() and NewPosition.Y < Logic.WorldGetSize() then
			_Page.zoom = _Page.zoom + math.sqrt(_Page.height^2) + (AngleTangens^2);
			_Page.position = NewPosition;
		end
	end
end

---
-- Sets the zoom distance of the current briefing page.
-- @param[type=table] _Page Briefing page
-- @within Information
-- @local
--
function Information:AdjustBriefingPageZoom(_Page)
    local ZoomDistance = Information.Constants.BriefingZoomDistance;
    if _Page.dialogCamera then
        ZoomDistance = Information.Constants.DialogZoomDistance;
    end
    ZoomDistance = (_Page.zoom ~= nil and _Page.zoom) or ZoomDistance;
    _Page.zoom = ZoomDistance;
    return ZoomDistance;
end

---
-- Sets the zoom angle of the current briefing page.
-- @param[type=table] _Page Briefing page
-- @within Information
-- @local
--
function Information:AdjustBriefingPageAngle(_Page)
    local ZoomAngle = Information.Constants.BriefingZoomAngle;
    if _Page.dialogCamera then
        ZoomAngle = Information.Constants.DialogZoomAngle;
    end
    ZoomAngle = (_Page.angle ~= nil and _Page.angle) or ZoomAngle;
    _Page.angle = ZoomAngle;
    return ZoomAngle;
end

---
-- Sets the rotation angle of the current briefing page.
-- @param[type=table] _Page Briefing page
-- @within Information
-- @local
--
function Information:AdjustBriefingPageRotation(_Page)
    local RotationAngle = -45;
    if _Page.lookAt and _Page.entity then
        RotationAngle = Logic.GetEntityOrientation(GetID(_Page.entity));
        if Logic.IsBuilding(GetID(_Page.entity)) == 1 then
            RotationAngle = RotationAngle - 90;
        end
        if Logic.IsSettler(GetID(_Page.entity)) == 1 then
            RotationAngle = RotationAngle + 90;
        end
    end
    RotationAngle = (_Page.rotation ~= nil and _Page.rotation) or RotationAngle;
    _Page.rotation = RotationAngle;
    return RotationAngle;
end

---
-- Sets the apperance of the cinematic mode.
-- @param[type=boolean] _DisableMap Hide the minimap
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

    -- Set widget apperance
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Container",0,0,size[1],size[2]);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Button1",200,button1Y,button1SizeX,46);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Button2",570,button2Y,button2SizeX,46);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Text",(200),textPosY,(680),100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Text",(200),textPosY,(680),100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Headline",100,titlePosY,titleSize,15);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Headline",100,titlePosY,titleSize,15);
    XGUIEng.SetWidgetPositionAndSize("CinematicBar01",0,size[2],size[1],185);
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
    XGUIEng.ShowWidget("CinematicBar00", 1);
end

---
-- Moves the text and the title of the cinmatic widget to the screen center.
-- Position is not ajusted by text length!
-- @param[type=boolean] _DisableMap Hide the minimap
-- @within Information
-- @local
--
function Information:SetTextCentered(_DisableMap)
    self:SetBriefingLooks(_DisableMap);

    local size      = {GUI.GetScreenSize()};
    local titleSize = (size[1]-200);
    local titlePosY = (size[2]/2) -95;
    local textPosY  = (size[2]/2) -60;

    -- Set widget apperance
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Text",(100),textPosY,titleSize,100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Text",(100),textPosY,titleSize,100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Headline",100,titlePosY,titleSize,15);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Headline",100,titlePosY,titleSize,15);
end

---
-- Moves the text and the title of the cinmatic widget to the screen center in
-- reversed order. Can be used for movie like map credits.
-- Position is not ajusted by text length!
-- @param[type=boolean] _DisableMap Hide the minimap
-- @within Information
-- @local
--
function Information:SetTextCenteredCredits(_DisableMap)
    self:SetBriefingLooks(_DisableMap);

    local size      = {GUI.GetScreenSize()};
    local titleSize = (size[1]-200);
    local titlePosY = (size[2]/2) -70;
    local textPosY  = (size[2]/2) -95;

    -- Set widget apperance
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Text",(100),textPosY,titleSize,100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Text",(100),textPosY,titleSize,100);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Headline",100,titlePosY,titleSize,15);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Headline",100,titlePosY,titleSize,15);
end

---
-- Initalizes the fader for the briefing page.
-- @param[type=table] _Page Briefing page
-- @within Information
-- @local
--
function Information:InitalizeFaderForBriefingPage(_Page)
    if _Page then
        -- Page duration
        if _Page.duration then
            briefingState.timer = _Page.duration * 10;
        else
            _Page.duration = briefingState.timer;
        end

        -- Fading process
        if _Page.faderAlpha then
            self:StopFader();
            self:SetFaderAlpha(_Page.faderAlpha);
        else
            if not _Page.fadeIn and not _Page.fadeOut then
                self:StopFader();
                self:SetFaderAlpha(0);
            end
            if _Page.fadeIn then
                self:StartFader(_Page.fadeIn, true);
            end
            if _Page.fadeOut then
                local Waittime = (Logic.GetTime() + (_Page.duration)) - _Page.fadeOut;
                self:StartFaderDelayed(Waittime, _Page.fadeOut, false);
            end
        end
    end
end

---
-- Starts a fading process. If it is already fading than the old process will
-- be aborted.
-- @param[type=number] _Duration Duration of fading in seconds
-- @param[type=boolean] _FadeIn  Fade in from black
-- @within Information
-- @local
--
function Information:StartFader(_Duration, _FadeIn)
    self.Fader.Duration = _Duration * 1000;
    self.Fader.StartTime = Logic.GetTimeMs();
    self.Fader.IsFadeIn = _FadeIn == true;
    self:StopFader();
    self.Fader.FaderControllerJobID = StartSimpleHiResJob("Information_FaderVisibilityController");
    self.Fader.IsFading = true;
    self:SetFaderAlpha(self:GetFadingFactor());
end

---
-- Starts the fader delayed by a waittime.
-- @param[type=number] _Waittime Waittime in seconds
-- @param[type=number] _Duration Duration of fading in seconds
-- @param[type=boolean] _FadeIn Fade in from black
-- @within Information
-- @local
--
function Information:StartFaderDelayed(_Waittime, _Duration, _FadeIn)
    self.Fader.Duration = _Duration;
    self.Fader.StartTime = _Waittime * 1000;
    self.Fader.IsFadeIn = _FadeIn == true;
    self:SetFaderAlpha((_FadeIn and 1) or 0);
    self:StopFader();
    self.Fader.FaderDelayJobID = StartSimpleHiResJob("Information_FaderDelayController");
end

---
-- Stops a fading process.
-- @within Information
-- @local
--
function Information:StopFader()
    if self.Fader.FaderControllerJobID and JobIsRunning(self.Fader.FaderControllerJobID) then
        EndJob(self.Fader.FaderControllerJobID);
        self.Fader.FaderControllerJobID = nil;
        self.Fader.IsFading = false;
    end
    if self.Fader.FaderDelayJobID and JobIsRunning(self.Fader.FaderDelayJobID) then
        EndJob(self.Fader.FaderDelayJobID);
        self.Fader.FaderDelayJobID = nil;
    end
end

---
-- Sets the alpha value of the fader mask.
-- @param[type=number] _AlphaFactor Alpha factor
-- @within Information
-- @local
--
function Information:SetFaderAlpha(_AlphaFactor)
    if XGUIEng.IsWidgetShown("Cinematic") == 1 then
        _AlphaFactor = (_AlphaFactor > 1 and 1) or _AlphaFactor;
        _AlphaFactor = (_AlphaFactor < 0 and 0) or _AlphaFactor;

        local sX, sY = GUI.GetScreenSize();
        XGUIEng.SetWidgetPositionAndSize("CinematicBar00", 0, 0, sX, sY);
        XGUIEng.SetMaterialTexture("CinematicBar00", 0, "");
        XGUIEng.ShowWidget("CinematicBar00", 1);
        XGUIEng.SetMaterialColor("CinematicBar00", 0, 0, 0, 0, math.floor(255 * _AlphaFactor));
    end
end

---
-- Returns the factor for the alpha value of the fader mask.
-- @return[type=number] Alpha factor
-- @within Information
-- @local
--
function Information:GetFadingFactor()
    local CurrentTime = Logic.GetTimeMs();
    local FadingFactor = (CurrentTime - self.Fader.StartTime) / self.Fader.Duration;
    FadingFactor = (FadingFactor > 1 and 1) or FadingFactor;
    FadingFactor = (FadingFactor < 0 and 0) or FadingFactor;
    if self.Fader.IsFadeIn then
        FadingFactor = 1 - FadingFactor;
    end
    return FadingFactor;
end

---
-- Controlls the fading process.
-- @within Information
-- @local
--
function Information_FaderVisibilityController()
    if IsBriefingActive() == false then
        return true;
    end
    if Logic.GetTimeMs() > Information.Fader.StartTime + Information.Fader.Duration then
        Information.Fader.IsFading = false;
        return true;
    end
    Information:SetFaderAlpha(Information:GetFadingFactor());
end

---
-- Controlls the delay for a delayed fading.
-- @within Information
-- @local
--
function Information_FaderDelayController()
    if IsBriefingActive() == false then
        return true;
    end
    if Logic.GetTimeMs() > Information.Fader.StartTime then
        Information:StartFader(Information.Fader.Duration, Information.Fader.IsFadeIn);
        return true;
    end
end

-- Countdown code --------------------------------------------------------------

---
-- Starts a visible or invisible countdown.
--
-- <b>Note:</b> There can only be one visible but infinit invisible countdonws.
--
-- @param[type=number] _Limit      Time to count down
-- @param[type=function] _Callback Countdown callback
-- @param[type=boolean] _Show      Countdown visible
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
-- @param[type=number] _Id Countdown ID
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
-- @return[type=boolean] Visible countdown
--
function CountdownIsVisisble()
    for i = 1, Counter.Index do
        if Counter.IsValid("counter" .. i) and Counter["counter" .. i].Show then
            return true
        end
    end
    return false
end