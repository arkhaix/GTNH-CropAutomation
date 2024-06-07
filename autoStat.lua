local gps = require('gps')
local action = require('action')
local database = require('database')
local scanner = require('scanner')
local posUtil = require('posUtil')
local config = require('config')
local lowestStat
local lowestStatSlot
local targetCrop

-- =================== MINOR FUNCTIONS ======================

local function isPerfect(crop)
    if crop.gr == config.perfectGrowth and crop.ga == config.perfectGain and crop.re == config.perfectResistance then
        return true
    end

    return false
end

local function getStat(crop)
    local stat = crop.gr + crop.ga - crop.re
    if isPerfect(crop) == true then
        stat = 9999
    end
    return stat
end

local function updateLowest()
    local farm = database.getFarm()
    lowestStat = 99999
    lowestStatSlot = 0

    -- Find lowest stat slot
    for slot=1, config.workingFarmArea, 2 do
        local crop = farm[slot]
        if crop.isCrop then

            if crop.name == 'air' or crop.name == 'emptyCrop' then
                lowestStat = 0
                lowestStatSlot = slot
                break

            elseif crop.name ~= targetCrop then
                local stat = getStat(crop) - 2
                if stat < lowestStat then
                    lowestStat = stat
                    lowestStatSlot = slot
                end

            else
                local stat = getStat(crop)
                if stat < lowestStat then
                    lowestStat = stat
                    lowestStatSlot = slot
                end
            end
        end
    end
end


local function checkChild(slot, crop)
    if crop.isCrop and crop.name ~= 'emptyCrop' then

        if crop.name == 'air' then
            action.placeCropStick(2)

        elseif scanner.isWeed(crop, 'working') then
            action.deweed()
            action.placeCropStick()

        elseif crop.name == targetCrop then
            local stat = getStat(crop)

            if stat > lowestStat then
                action.transplant(posUtil.workingSlotToPos(slot), posUtil.workingSlotToPos(lowestStatSlot))
                action.placeCropStick(2)
                database.updateFarm(lowestStatSlot, crop)
                updateLowest()

            else
                action.deweed()
                action.placeCropStick()
            end

        elseif config.keepMutations and (not database.existInStorage(crop)) then
            action.transplant(posUtil.workingSlotToPos(slot), posUtil.storageSlotToPos(database.nextStorageSlot()))
            action.placeCropStick(2)
            database.addToStorage(crop)

        else
            action.deweed()
            action.placeCropStick()
        end
    end
end


local function checkParent(slot, crop)
    if crop.isCrop and crop.name ~= 'air' and crop.name ~= 'emptyCrop' then
        if scanner.isWeed(crop, 'working') then
            action.deweed()
            database.updateFarm(slot, {isCrop=true, name='emptyCrop'})
            updateLowest()
        end
    end
end

-- ====================== THE LOOP ======================

local function statOnce()
    for slot=1, config.workingFarmArea, 1 do

        -- Terminal Condition
        if #database.getStorage() >= config.storageFarmArea then
            print('autoStat: Storage Full!')
            return false
        end

        -- Terminal Condition
        if (config.requirePerfect == false) and lowestStat >= config.autoStatThreshold then
            print('autoStat: Minimum Stat Threshold Reached!')
            return false
        elseif (config.requirePerfect == true) and (lowestStat >= 9000) then
            print('autoStat: Perfect Stats Reached!')
            return false
        end

        -- Scan
        gps.go(posUtil.workingSlotToPos(slot))
        local crop = scanner.scan()

        if slot % 2 == 0 then
            checkChild(slot, crop)
        else
            checkParent(slot, crop)
        end

        if action.needCharge() then
            action.charge()
        end
    end
    return true
end

-- ======================== MAIN ========================

local function init()
    database.resetStorage()
    database.scanFarm()
    action.restockAll()

    targetCrop = database.getFarm()[1].name
    updateLowest()

    print(string.format('autoStat: Target %s', targetCrop))
end


local function main()
    init()

    -- Loop
    while statOnce() do
        action.restockAll()
    end

    -- Finish
    if config.cleanUp then
        action.cleanUp()
    end

    print('autoStat: Complete!')
end

main()
