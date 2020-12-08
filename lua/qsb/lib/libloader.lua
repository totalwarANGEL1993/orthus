-- ########################################################################## --
-- #  Library Loader                                                        # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

-- Load oop lib
if inherit == nil then
    Script.Load(gvBasePath.. "lib/oop.lua");
end
-- Load qsb comforts
if QSBTools == nil then
    Script.Load(gvBasePath.. "lib/qsbtools.lua");
end
-- Load luabit implementation for lua 5.0
if bit_logic_rshift == nil then
    Script.Load(gvBasePath.. "lib/luabit50.lua");
end
-- Load MD5 hash generator lib
if md5 == nil then
    Script.Load(gvBasePath.. "lib/md5.lua");
end
-- Load S5Hook
if S5HookData == nil then
    Script.Load(gvBasePath.. "lib/s5hook.lua");
end

