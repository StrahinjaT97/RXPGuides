local addonName, addon = ...
local L = addon.locale.Get

if not (addon.game == "CLASSIC" or addon.game == "TBC" or addon.game == "FOREVER") then return end

-- Localize globlas
local _G = _G

addon.professions = addon.professions or {}
addon.professions.utils = addon.professions.utils or {}

-- Local enums
local SECONDS_IN_YEAR = 365 * 24 * 3600 --Leap year is considered later


--Returns scan time in format:
--!%Y-%m-%dT%H:%M:%SZ
function addon.professions.utils:getCurrentDateTime()
    local time = time()
    return date("!%Y-%m-%dT%H:%M:%SZ", time)
end

local function isLeapYear(year)
    return year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0)
end

local function hasThirtyOneDays(month)
    return month == 1 or month == 3 or month == 5 or month == 7 or month == 8 or month == 10 or month == 12
end

local function hasThirtyDays(month)
    return month == 4 or month == 6 or month == 9 or month == 11
end

local function hasTwentyEightDays(year, month)
    return month == 2 and not isLeapYear(year)
end

local function hasTwentyNineDays(year, month)
    return month == 2 and isLeapYear(year)
end

--Checks if its benefitial to calculate
--timeMetric(y, x) instead of timeMetric(x, y).
--Returns boolean and number? equal 0 if both are already equal
local function shouldSwap(x, y)
    if x.year > y.year then return true
    elseif x.year == y.year then
        if x.month > y.month then return true
        elseif x.month == y.month then
            if x.day > y.day then return true
            elseif x.day == y.day then
                if x.hour > y.hour then return true
                elseif x.hour == y.hour then
                    if x.minute > y.minute then return true
                    elseif x.minute == y.minute then
                        if x.second > y.second then return true
                        elseif x.second == y.second then return false, 0 end
                    end
                end
            end
        end
    end
    return false
end

local function minutesToSeconds(minutes)
    return 60 * minutes
end

local function hoursToSeconds(hours)
    return 3600 * hours
end

local function daysToSeconds(days)
    return 24 * 3600 * days
end

local function monthsToSeconds(year, ...)
    local args = {...}
    local days = 0
    for _, monthNumber in ipairs(args) do
        if hasThirtyOneDays(monthNumber) then days = days + 31
        elseif hasThirtyDays(monthNumber) then days = days + 30
        elseif hasTwentyNineDays(year, monthNumber) then days = days + 29
        elseif hasTwentyEightDays(year, monthNumber) then days = days + 28
        end
    end
    return daysToSeconds(days)
end

local function secondsFromYearStart(x)
    local seconds = 0
    local month = 1
    while month < x.month do
        seconds = seconds + monthsToSeconds(x.year, month)
        month = month + 1
    end
    seconds = seconds + daysToSeconds(x.day)
    seconds = seconds + hoursToSeconds(x.hour)
    seconds = seconds + minutesToSeconds(x.minute)
    seconds = seconds + x.second

    return seconds
end

--A metric for time in seconds
function addon.professions.utils:timeMetric(x, y)
    local x = x
    local y = y
    local isSwap, isZero = shouldSwap(x, y)
    if isZero == 0 then return 0 end
    if isSwap then return self:timeMetric(y, x) end

    if x.year == y.year then
        return secondsFromYearStart(y) - secondsFromYearStart(x)
    else
        local secondsTillYearEnd = SECONDS_IN_YEAR
        if (isLeapYear(x.year)) then secondsTillYearEnd = secondsTillYearEnd + 24 * 3600 end
        x.year = x.year + 1
        local seconds = secondsTillYearEnd
        while (x.year ~= y.year) do
            seconds = seconds + SECONDS_IN_YEAR
            if (isLeapYear(x.year)) then seconds = seconds + 24 * 3600 end
            x.year = x.year + 1
        end
        return seconds + secondsFromYearStart(y) - secondsFromYearStart(x)
    end
end


