local shell = require('shell')
local args = {...}
local branch
local repo
local scripts = {
    'action.lua',
    'database.lua',
    'gps.lua',
    'posUtil.lua',
    'scanner.lua',
    'signal.lua',
    'autoStat.lua',
    'autoTier.lua',
    'autoSpread.lua',
    'config.lua',
    'uninstall.lua'
}

-- BRANCH
if #args >= 1 then
    branch = args[1]
else
    branch = 'require-perfect'
end

-- REPO
if #args >= 2 then
    repo = args[2]
else
    repo = 'https://raw.githubusercontent.com/arkhaix/GTNH-CropAutomation/'
end

-- INSTALL
for i=1, #scripts do
    shell.execute(string.format('wget -f %s%s/%s', repo, branch, scripts[i]))
end
