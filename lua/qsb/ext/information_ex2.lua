-- ########################################################################## --
-- #  Information (Extra 1/2)                                               # --
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
    },
    ClockWasShown = false,
    ForbidEscaping = false,
};

---
-- Returns the page id to the page name. If a name is not found a absurd high
-- page ID is providet to prevent lua errors.
-- @param[type=string] _Name Name of page
-- @return[type=number] Page ID
-- @within Methods
--
function GetPageID(_Name)
    return Information:GetPageID(_Name);
end

-- -------------------------------------------------------------------------- --

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
    -- @within Methods
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
                    
                    -- Set normal text
                    _page = QuestSystem:ReplacePlaceholders(_page);
                    if _page.title then
                        if type(_page.title) == "table" then
                            _page.title = _page.title[QSBTools.GetLanguage()];
                        end
                        if not string.find(string.sub(_page.title, 1, 2), "@") then
                            _page.title = "@center " .. _page.title;
                        end
                    end
                    if _page.text then
                        if type(_page.text) == "table" then
                            _page.text = _page.text[QSBTools.GetLanguage()];
                        end
                    end

                    -- Set mc text
                    if _page.mc and _page.mc.title then
                        if type(_page.mc.title) == "table" then
                            _page.mc.title = _page.mc.title[QSBTools.GetLanguage()];
                        end
                        if not string.find(string.sub(_page.mc.title, 1, 2), "@") then
                            _page.mc.title = "@center " .. _page.mc.title;
                        end
                    end
                    if _page.mc and _page.mc.text then
                        if type(_page.mc.text) == "table" then
                            _page.mc.text = _page.mc.text[QSBTools.GetLanguage()];
                        end
                    end

                    if _page.action then
                        _page.actionOrig = _page.action;
                    end
                    _page.action = function()
                        _page = QuestSystem:ReplacePlaceholders(_page);
                        if _page.entity then
                            _page.position = GetPosition(_page.entity);
                        end
                        _page.zoom = Information:AdjustBriefingPageZoom(_page);
                        _page.angle = Information:AdjustBriefingPageAngle(_page);
                        _page.rotation = Information:AdjustBriefingPageRotation(_page);
                        _page = Information:AdjustBriefingPageCamHeight(_page);

                        -- Fader
                        Information:InitalizeFaderForBriefingPage(_page);

                        -- Disable fog
                        local showFoW = (_briefing.disableFog and 0) or 1;
                        if _page.disableFog then
                            showFoW = 0;
                        end
                        Display.SetRenderFogOfWar(showFoW);

                        -- Display sky
                        local showSky = (_briefing.showSky and 1) or 0;
                        if _page.showSky then
                            showSky = 1;
                        end
                        Display.SetRenderSky(showSky);

                        -- Override camera flight
                        Camera.StopCameraFlight();
                        if not _page.flight then
                            Camera.ZoomSetDistance(_page.zoom);
                            Camera.ZoomSetAngle(_page.angle);
                            Camera.RotSetAngle(_page.rotation);
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

                                Camera.ZoomSetDistanceFlight(_page.zoom, _page.duration);
                                Camera.ZoomSetAngleFlight(_page.angle, _page.duration);
                                Camera.RotFlight(_page.rotation, _page.duration);
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
            text         = arg[7],
            position     = arg[2],
            dialogCamera = arg[4] == true,
            action       = arg[8],
            lookAt       = true;
            disableFog   = arg[6],
            showSky      = arg[5],
        };
        return page;
    end

    function CreateShortMCPage(...)
        local page = {
            name         = arg[1],
            position     = arg[2],
            dialogCamera = arg[4] == true,
            action       = arg[12],
            lookAt       = true;
            disableFog   = arg[5],
            showSky      = arg[6],

            mc           = {
                title	       = arg[3],
                text 	       = arg[11],
                firstText      = arg[7],
                secondText     = arg[9],
                firstSelected  = arg[8],
                secondSelected = arg[10],
            },
        };
        return page;
    end
end

---
-- Returns the page id to the page name. If a name is not found a absurd high
-- page ID is provided to prevent lua errors.
-- @param[type=string] _Name Name of page
-- @return[type=number] Page ID
-- @local
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
            if Information.ForbidEscaping then
                return;
            end
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
    StartBriefing = function(_briefing, _ID, _Quest)
        assert(type(_briefing) == "table");
        local ID = StartBriefing_Orig_Information(_briefing, _ID, _Quest);
        if _briefing.noEscape then
            Information.ForbidEscaping = true;
        end
        if XGUIEng.IsWidgetShown("GameClock") == 1 then
			XGUIEng.ShowWidget("GameClock", 0);
			Information.ClockWasShown = true;
        end
		Game.GameTimeReset();
        GUI.ClearNotes();
        return ID;
    end

    EndBriefing_Orig_Information = EndBriefing;
    EndBriefing = function()
        EndBriefing_Orig_Information();
        if Information.ForbidEscaping then
            Information.ForbidEscaping = nil;
        end
        if Information.ClockWasShown then
			XGUIEng.ShowWidget("GameClock", 1);
			Information.ClockWasShown = false;
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
        if _page.wallText == true then
            Information:SetTextWall();
        end

        -- Display multiple choice
		if _page.mc ~= nil then
			if _page.mc.text ~= nil then
				assert(_page.mc.title ~= nil);
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
-- @return[type=table] Page
-- @within Information
-- @local
--
function Information:AdjustBriefingPageCamHeight(_Page)
    _Page.height = _Page.height or 90;
    if _Page.angle >= 90 then
        _Page.height = 0;
    end

	if _Page.height > 0 and _Page.angle > 0 and _Page.angle < 90 then
		local AngleTangens = _Page.height / math.tan(math.rad(_Page.angle));
        local RotationRadiant = math.rad(_Page.rotation);
        -- Save backup for when page is visited again
        if not _Page.positionOriginal then
            _Page.positionOriginal = _Page.position;
        end

        -- New position
        local NewPosition = {
            X = _Page.positionOriginal.X - math.sin(RotationRadiant) * AngleTangens,
            Y = _Page.positionOriginal.Y + math.cos(RotationRadiant) * AngleTangens
        };
        -- Update if valid position
        if NewPosition.X > 0 and NewPosition.Y > 0 and NewPosition.X < Logic.WorldGetSize() and NewPosition.Y < Logic.WorldGetSize() then
            -- Save backup for when page is visited again
            if not _Page.zoomOriginal then
                _Page.zoomOriginal = _Page.zoom;
            end
			_Page.zoom = _Page.zoomOriginal + math.sqrt(_Page.height^2 + AngleTangens^2);
			_Page.position = NewPosition;
		end
    end
    return _Page;
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
    if _Page.entity then
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
-- Moves the text and the title of the cinmatic widget to the screen center in
-- reversed order. Can be used for movie like map credits.
-- Position is not ajusted by text length!
-- @param[type=boolean] _DisableMap Hide the minimap
-- @within Information
-- @local
--
function Information:SetTextWall()
    self:SetBriefingLooks(true);

    local Size   = {GUI.GetScreenSize()};
    local TextH  = math.ceil(468 * (Size[2]/768));
    local TextX  = math.ceil((262 * (Size[2]/768)) - (50 * (Size[1]/1920)));
    local TextY  = math.ceil(200 * (Size[2]/768));

    -- Set widget apperance
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Text", TextX, TextY, 500, TextH);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Text", TextX, TextY, 500, TextH);
    XGUIEng.SetWidgetPositionAndSize("CinematicMC_Headline", TextX, TextY -50, 500, 50);
    XGUIEng.SetWidgetPositionAndSize("Cinematic_Headline", TextX, TextY -50, 500, 50);
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

