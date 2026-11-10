local M = {}

local function has_unity_cli()
  if vim.fn.executable('unity') ~= 0 then return true end
  vim.notify(
    'unity.nvim: This feature requires the unity CLI command.\n' ..
    'Please ensure that the Unity CLI (Unity 6 or later) is installed and included in your PATH.',
    vim.log.levels.ERROR)
  return false
end

local function current_dir()
  return vim.fs.root(vim.api.nvim_buf_get_name(0), { 'ProjectSettings', 'Assets' })
end

local function parse(obj)
  local ok, result = pcall(vim.json.decode, obj.stdout)
  if obj.code == 6 or obj.code == 0 then
    if ok then return result end
    return {}
  end
  if ok then
    for _, error in ipairs(result.errors) do
      vim.notify(error.code .. ':' .. error.message, vim.log.levels.ERROR)
    end
  else
    vim.notify(obj.code .. ':' .. obj.stdout, vim.log.levels.ERROR)
  end
  return nil
end

local function unity_command(command, on_success)
  if not has_unity_cli() then return end
  table.insert(command, 1, 'unity')
  local cmdmsg = table.concat(command, ' ')
  vim.notify('wait for : ' .. cmdmsg)
  vim.system(command, { text = true }, function(obj)
    vim.schedule(function()
      local result = parse(obj)
      if not result then return end
      if on_success then on_success(result) end
      vim.notify('done : ' .. cmdmsg)
    end)
  end)
end
local function unity_command_editor(mode, on_success)
  unity_command({ mode, current_dir() }, on_success)
end

local function unity_command_project(command, on_success)
  table.insert(command, '--project-path')
  table.insert(command, current_dir())
  table.insert(command, '--format')
  table.insert(command, 'json')
  unity_command(command, on_success)
end

local function unity_command_playmode(mode, on_success)
  unity_command(
    { 'cmd', 'editor.playmode', mode, '--project-path', current_dir() },
    on_success)
end

local function unity_play()
  unity_command_project({ 'status' }, function(obj)
    local instances = obj.data.instances or {}
    for _, instance in ipairs(instances) do
      if instance.frameCount and instance.playerLoopTicking then
        unity_command_playmode('stop')
      else
        unity_command_playmode('start')
      end
    end
  end)
end

local function unity_recompile()
  local cur = current_dir()
  local function parse_logs(logs, type, list)
    for _, log in ipairs(logs) do
      table.insert(list, {
        filename = vim.fs.normalize(vim.fs.joinpath(cur, log.file)),
        lnum = tonumber(log.line) or 1,
        col = tonumber(log.colmun) or 1,
        text = log.message,
        type = type
      })
    end
  end
  unity_command_project({ 'recompile', '--strict' }, function(obj)
    local list = {}
    local data = obj.data
    if data == vim.NIL then return end
    local errors = data.errors or {}
    parse_logs(errors, 'E', list)
    local warning = data.warnings or {}
    parse_logs(warning, 'W', list)
    if #list == 0 then
      vim.cmd('cclose')
      vim.fn.setqflist({}, 'r')
    else
      vim.fn.setqflist(list, 'r')
      vim.cmd('copen')
    end
  end)
end
local function unity_pause() unity_command_playmode('pause') end
local function unity_open() unity_command_editor('open') end
local function unity_close() unity_command_editor('close') end
local function create_user_commands()
  vim.api.nvim_create_user_command('UPlay', unity_play, {})
  vim.api.nvim_create_user_command('URefresh', unity_recompile, {})
  vim.api.nvim_create_user_command('UPause', unity_pause, {})
  vim.api.nvim_create_user_command('UOpen', unity_open, {})
  vim.api.nvim_create_user_command('UClose', unity_close, {})
end
function M.setup()
  create_user_commands()
end

return M
