-- Observable: Simple observer/reactive value system
-- Holds a value, notifies listeners on change
--
-- Usage:
--   local obs = Observable(initialValue)
--   obs:Observe(function(newValue) ... end)
--   obs:Set(newValue)  -- triggers all observers
--   obs:Get()

class "Observable" {
    __init = function(self, value)
        self._value = value
        self._observers = {}
    end;

    Get = function(self)
        return self._value
    end;

    Set = function(self, newValue)
        if self._value ~= newValue then
            self._value = newValue
            self:_Notify()
        end
    end;

    -- Force notify even if value didn't change
    ForceNotify = function(self)
        self:_Notify()
    end;

    Observe = function(self, callback)
        table.insert(self._observers, callback)
        -- Call immediately with current value
        callback(self._value)
    end;

    _Notify = function(self)
        for _, cb in ipairs(self._observers) do
            cb(self._value)
        end
    end;
}
