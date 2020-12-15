-- ########################################################################## --
-- #  Library Loader                                                        # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- Loads libraries used by the QSB if they are not already present.
--
-- Libraries loaded (in this order):
-- <ul>
-- <li>OOP - Creates classes based on deep table copies.</li>
-- <li>QSBTools - Several helper functions.</li>
-- <li>LuaBit - Lua 5.0 implementation of lua bit.</li>
-- <li>MD5 - Library to create simple MD5 hashes.</li>
-- <li>Metatable (S5 Community) - Makes metatables savable.</li>
-- <li>S5Hook (S5 Community) - Allows basic memory manipulation (not compatible
-- to History Edition).</li>
-- </ul>
--
-- @set sort=true
--

-- Load luabit implementation for lua 5.0
if bit_logic_rshift == nil then
    Script.Load(gvBasePath.. "lib/luabit50.lua");
end
-- Load MD5 hash generator lib
if md5 == nil then
    Script.Load(gvBasePath.. "lib/md5.lua");
end
-- Load Metatable fix
if metatable == nil then
    Script.Load(gvBasePath.. "lib/metatable.lua");
end
-- Load S5Hook
if S5HookData == nil then
    Script.Load(gvBasePath.. "lib/s5hook.lua");
end

