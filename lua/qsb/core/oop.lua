-- ########################################################################## --
-- # OOP                                                                    # --
-- #  --------------------------------------------------------------------  # --
-- #    Author:   totalwarANGEL                                             # --
-- ########################################################################## --

---
-- Small module to create class alike tables that can be instanciated. The
-- objective is to create some oop programming in settlers 5 without using
-- the not saveable metatables.
--
-- A table is transmuted to a class by using the function class(). If any
-- default method should be overwritten it must be declared before calling
-- class() on the table.
--
-- A table can also be transmuted by inheriting from a table that has alredy
-- beeen transmuted by class(). To inherit from such a table the function
-- inherit() is used. If some method of the parend sould be overwritten than
-- it must be declared before calling inherit();
--
-- An object is instanciated by calling new(). The first paramater is the
-- Class table. All following arguments are passed to the construct() method
-- of the class.
--
-- @set sort=true
--


---
-- Copies a table to the destinated table. If a key alredy exists in the 
-- destinated table than this value will be preferd over the source value.
-- The destinated table can be nil. In this case just a copy of the source
-- table will be returned.
--
-- @param[type=table] _Source Source table
-- @param[type=table] _Dest   Destinated table
-- @return[type=table] Copy of table
--
function copy(_Source, _Dest)
    _Dest = _Dest or {};
    assert(_Source ~= nil, "copy: Source is nil!");
    assert(type(_Dest) == "table");

    for k, v in pairs(_Source) do
        if type(v) == "table" then
            _Dest[k] = _Dest[k] or {};
            for kk, vv in pairs(copy(v)) do
                _Dest[k][kk] = _Dest[k][kk] or vv;
            end
        else
            _Dest[k] = _Dest[k] or v;
        end
    end
    return _Dest;
end

---
-- Makes a table to some kind of pseudo class by adding some default stuff a
-- class should have. Metatables will not be used so operator overloading is
-- not possible.
--
-- Functions added:
-- <ul>
-- <li>construct - empty default constructor</li>
-- <li>clone - create a copy of the object</li>
-- <li>toString - displayable representation of the object</li>
-- <li>foreach - call a function for all non-function members</li>
-- <li>equals - compare one object with another</li>
-- </ul>
--
-- @param[type=table] _Table Table to transmute
-- @return[type=table] Class table
--
function class(_Table)
    for k, v in pairs(_G) do 
        if v == _Table then
            _Table.className = k;
        end
    end

    _Table.construct = _Table.construct or function(self, ...)
    end

    _Table.clone = _Table.clone or function(self)
        return copy(self);
    end

    _Table.toString = _Table.toString or function(self)
        local s = "";
        for k, v in pairs(self) do
            if type(v) == "table" and v.toString then
                s = s .. tostring(k) .. ":" .. tostring(v:toString()) .. ";";
            else
                s = s .. tostring(k) .. ":" .. tostring(v) .. ";";
            end
        end
        return "{" ..s.. "}";
    end

    _Table.foreach = _Table.foreach or function(self, _Function)
        for k, v in pairs(self) do
            if v and type(v) ~= "function" and k ~= "parent" then 
                _Function(self, k, v);
            end
        end
    end

    _Table.equals = _Table.equals or function(self, _Other)
        if type(_Other) ~= "table" then 
            return false;
        end
        for k, v in pairs(self) do
            if v ~= _Other[k] then
                return false;
            end
        end
        return true;
    end

    return _Table;
end

---
-- Does the same as class() but also inherits content from the parent class.
--
-- @param[type=table] _Table  Table to transmute
-- @param[type=table] _Parent Parent class
-- @return[type=table] Class table
--
function inherit(_Table, _Parent)
    local c = copy(_Parent, _Table);
    c.parent = _Parent;
    return class(c);
end

---
-- Instanciates a class by calling the construct() method.
--
-- If a parent is defined, new will first be called for the parent class. In
-- that case an instance of the parent class is accessable at the member
-- "parent". Methods for the parent object can be called seperatly and the
-- object will have it's own members.
--
-- @param[type=table] _Class Class table
-- @param ...         Constructor arguments
-- @return[type=table] Instance of class
--
function new(_Class, ...)
    local instance = copy(_Class);
    if instance.parent then
        instance.parent = new(instance.parent, unpack(arg));
    end
    instance:construct(unpack(arg));
    return instance;
end