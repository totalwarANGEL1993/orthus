-- ########################################################################## --
-- #  Options menu                                                          # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- This module allows to create a simple menu controlled by the group
-- selection keys.
--
-- <b>Required modules:</b>
-- <ul>
-- <li>qsb.oop</li>
-- </ul>
--
-- @set sort=true
--

function ShowOptionMenu(_Data)
    if OptionMenu:IsShown() then
        return false;
    end
    assert(type(_Data) == "table");
    assert(table.getn(_Data) > 0);
    assert(_Data[1].Parent == nil);
    OptionMenu:Clear();
    for i= 1, table.getn(_Data), 1 do
        OptionMenu:AddPage(_Data[i]);
    end
    OptionMenu:Show(_Data[1].Identifier);
    return true;
end

function CloseOptionMenu(_Data)
    if OptionMenu:IsShown() then
        OptionMenu:Close();
    end
end

---
-- Option menu class
--
OptionMenu = {
    Menu = {
        Pages = {},
        CurrentPage = nil,
        Active = false,
    },

    Texts = {
        Back = {
            de = "Zurück",
            en = "Back",
        },
        Submit = {
            de = "Bestätigen",
            en = "Submit",
        },
        Up = {
            de = "Hoch",
            en = "Up",
        },
        Down = {
            de = "Runter",
            en = "Down",
        },
        Increase = {
            de = "Wert erhöhen",
            en = "Increase value",
        },
        Decrease = {
            de = "Wert verringern",
            en = "Decrease value",
        },
        Select = {
            de = "Auswahl",
            en = "Select",
        },
    }
};

---
-- Installs the option menu.
-- @within OptionMenu
-- @local
--
function OptionMenu:Install()
    self:OverrideGroupSelection();
end

---
-- Displays the prepared option window entering on the given page.
-- @within OptionMenu
-- @local
--
function OptionMenu:Show(_StartPage)
    self.Menu.Active = true;
    self.Menu.CurrentPage = _StartPage;
    self:Render();
end

---
-- Closes the option window
-- @within OptionMenu
-- @local
--
function OptionMenu:Close()
    self.Menu.Active = false;
    self:HideCreditsWindow();
end

---
-- Displays the prepared option window entering on the given page.
-- @return[type=boolean] Option window shown
-- @within OptionMenu
-- @local
--
function OptionMenu:IsShown()
    return self.Menu.Active == true;
end

---
-- Removes all data from the option window.
-- @within OptionMenu
-- @local
--
function OptionMenu:Clear()
    self.Menu.Pages = {};
    self.Menu.CurrentPage = nil;
end

---
-- Adds the configured page to the option window.
-- @param[type=table] _Page Page data
-- @within OptionMenu
-- @local
--
function OptionMenu:AddPage(_Page)
    local Page = new(
        OptionMenuPage,
        _Page.Identifier,
        _Page.Parent,
        _Page.Title,
        _Page.Description,
        _Page.OnClose,
        _Page.BackLink == true,
        _Page.Options or {}
    );
    self.Menu.Pages[_Page.Identifier] = Page;
end

---
-- Removes all data from the option window.
-- @param[type=string] _Identifier Name of page
-- @return[type=table] Page data
-- @within OptionMenu
-- @local
--
function OptionMenu:GetPage(_Identifier)
    return self.Menu.Pages[_Identifier];
end

---
-- Overrides the group selection to be used as a menu.
-- @within OptionMenu
-- @local
--
function OptionMenu:OverrideGroupSelection()
    if not GroupSelection_SelectTroops_Orig_OptionMenu then
        GroupSelection_SelectTroops_Orig_OptionMenu = GroupSelection_SelectTroops
        GroupSelection_SelectTroops = function(_Count)
            if OptionMenu.Menu.Active == false then
                GroupSelection_SelectTroops_Orig_OptionMenu(_Count);
                return;
            end
            self:OnOptionSelected(_Count);
        end
    end
end

---
-- Reacts to the pressed group key if the option menu is shown.
-- @param[type=number] _Count Selected group
-- @within OptionMenu
-- @local
--
function OptionMenu:OnOptionSelected(_Count)
    local Page = self:GetPage(self.Menu.CurrentPage);
    if not Page then
        return;
    end
    if _Count == 10 then
        if Page:GetBackOption() then
            local Target = Page:GetBackOption():GetTarget();
            self.Menu.CurrentPage = Target;
            if Page.m_OnClose then
                Page.m_OnClose();
            end
            self:Render();
            return;
        end
    end
    local Options = Page:GetOptions();
    for i= 1, 8, 1 do
        if i == _Count and Options[i] then
            local Target = Options[i]:GetTarget();
            self.Menu.CurrentPage = Target;
            self:Render();
            return;
        end
    end
end

---
-- Displays the current page of the option menu.
-- @within OptionMenu
-- @local
--
function OptionMenu:Render()
    local Page = self:GetPage(self.Menu.CurrentPage);
    if not Page then
        self:HideCreditsWindow();
        return;
    end

    local Title = Page:GetCaption();

    local Text = "";
    Text = Text .. Page:GetDescription();
    if table.getn(Page:GetOptions()) > 0 then
        local OptionsList = Page:GetOptions();
        Text = Text .. " @color:255,255,255 @cr @cr ";
        for i= 1, 8, 1 do
            if OptionsList[i] then
                if OptionsList[i]:GetKey() ~= -1 then
                    Text = Text .. OptionsList[i]:GetKey();
                    Text = Text .. " @color:0,0,0,0 ___ @color:255,255,255 ";
                    Text = Text .. OptionsList[i]:GetText() .. " @cr ";
                else
                    Text = Text .. " @cr ";
                end
            end
        end
    end
    if Page:GetBackOption() then
        Text = Text .. " @color:255,255,255 @cr @cr ";
        if table.getn(Page:GetOptions()) == 0 then
            Text = Text .. " @cr ";
        end
        Text = Text .. Page:GetBackOption():GetKey() .. "   ";
        Text = Text .. Page:GetBackOption():GetText();
    end
    self:DisplayCreditsWindow(Title, Text);
end

---
-- Prints the text from the current page to the screen by using the
-- credits window.
-- @param[type=string] _Title Title of credits window
-- @param[type=string] _Text  Content of credits window
-- @within OptionMenu
-- @local
--
function OptionMenu:DisplayCreditsWindow(_Title, _Text)
	XGUIEng.ShowWidget( XGUIEng.GetWidgetID("Movie"), 1)
	XGUIEng.ShowWidget( XGUIEng.GetWidgetID("Cinematic_Text"), 0)
	XGUIEng.ShowWidget( XGUIEng.GetWidgetID("CreditsWindowLogo"), 0)
	XGUIEng.ShowWidget( XGUIEng.GetWidgetID("MovieBarTop"), 0)
	XGUIEng.ShowWidget( XGUIEng.GetWidgetID("MovieBarBottom"), 0)
	XGUIEng.ShowWidget( XGUIEng.GetWidgetID("MovieInvisibleClickCatcher"), 0)
	XGUIEng.SetText( XGUIEng.GetWidgetID("CreditsWindowTextTitle"), _Title)
	XGUIEng.SetText( XGUIEng.GetWidgetID("CreditsWindowText"), _Text)
end

---
-- Hides the credits window.
-- @within OptionMenu
-- @local
--
function OptionMenu:HideCreditsWindow()
	XGUIEng.ShowWidget(XGUIEng.GetWidgetID("Movie"), 0);
end



OptionMenuPage = {
    m_Identifier  = nil,
    m_Parent      = nil,
    m_Caption     = nil,
    m_Description = nil,
    m_Options     = {},
};

function OptionMenuPage:construct(_Identifier, _Parent, _Title, _Description, _OnClose, _NoBack, _Options)
    local Language = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";
    if type(_Title) == "table" then
        _Title = _Title[Language];
    end
    if type(_Description) == "table" then
        _Description = _Description[Language];
    end
    
    self.m_Identifier  = _Identifier;
    self.m_Parent      = _Parent;
    self.m_Caption     = _Title;
    self.m_Description = _Description;
    self.m_OnClose     = _OnClose;
    
    if _Parent ~= nil then
        if not _NoBack then
            self.m_ZeroOption = new(
                OptionMenuOption,
                0,
                0,
                OptionMenu.Texts.Back[Language],
                _Parent,
                nil
            );
        end
    else
        if self.m_OnClose then
            self.m_ZeroOption = new(
                OptionMenuOption,
                0,
                0,
                OptionMenu.Texts.Submit[Language],
                nil,
                nil
            );
        end
    end

    local OptionCount = table.getn(_Options);
    if OptionCount > 8 then
        OptionCount = 8;
    end
    for i= 1, 8, 1 do
        if _Options[i] then
            if _Options[i] == -1 then
                local Option = new(OptionMenuOption, i, -1, "", self.m_Identifier, nil);
                self.m_Options[i] = Option;
            else
                local Option = new(
                    OptionMenuOption,
                    i,
                    i,
                    _Options[i].Text,
                    _Options[i].Target,
                    _Options[i]
                );
                self.m_Options[i] = Option;
            end
        end
    end
end
class(OptionMenuPage);

function OptionMenuPage:GetIdentifier()
    return self.m_Identifier;
end

function OptionMenuPage:GetCaption(...)
    if table.getn(arg) > 0 then
        return string.format(self.m_Caption, unpack(arg));
    end
    return self.m_Caption;
end

function OptionMenuPage:GetDescription(...)
    if table.getn(arg) > 0 then
        return string.format(self.m_Description, unpack(arg));
    end
    return self.m_Description;
end

function OptionMenuPage:GetParent()
    return self.m_Parent;
end

function OptionMenuPage:GetBackOption()
    return self.m_ZeroOption;
end

function OptionMenuPage:GetOptions()
    return self.m_Options;
end



OptionMenuOption = {
    m_Key         = 0,
    m_Text        = nil,
    m_Target      = nil,
};

function OptionMenuOption:construct(_Index, _Key, _Text, _Target, _Data)
    local Language = (XNetworkUbiCom.Tool_GetCurrentLanguageShortName() == "de" and "de") or "en";
    if type(_Text) == "table" then
        _Text = _Text[Language];
    end

    self.m_Index    = _Index;
    self.m_Key      = _Key;
    self.m_Text     = _Text;
    self.m_Target   = _Target;
    self.m_Data     = copy(_Data or {});
end
class(OptionMenuOption);

function OptionMenuOption:GetIndex()
    return self.m_Index or -1;
end

function OptionMenuOption:GetKey()
    return self.m_Key or self:GetIndex();
end

function OptionMenuOption:GetText()
    if type(self.m_Text) == "function" then
        return self.m_Text(self.m_Data);
    end
    return self.m_Text;
end

function OptionMenuOption:GetTarget()
    if type(self.m_Target) == "function" then
        return self.m_Target(unpack(self.m_Data));
    end
    return self.m_Target;
end

