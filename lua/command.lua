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

local function validate(result)
  if result.success == true then return true end
  if result.command == 'recompile' and result.data ~= vim.NIL then return true end
  for _, error in ipairs(result.errors) do
    vim.notify(error.code .. ':' .. error.message, vim.log.levels.ERROR)
  end
  return false
end

local function unity_command(command, on_success)
  if not has_unity_cli() then return end
  local cmdmsg = table.concat(command, ' ')
  vim.notify('wait for : ' .. cmdmsg)
  vim.system(command, { text = true }, function(obj)
    local ok, result = pcall(vim.json.decode, obj.stdout)
    vim.schedule(function()
      if not ok then
        vim.notify('unity.nvim failed to parse output of : ' .. cmdmsg)
        return
      end
      if not validate(result) then return end
      if on_success ~= nil then on_success(result) end
      vim.notify('done : ' .. cmdmsg)
    end)
  end)
end

local function create_command(command)
  table.insert(command, 1, 'unity')
  table.insert(command, '--format')
  table.insert(command, 'json')
  return command
end

local function create_command_project(command)
  table.insert(command, '--project-path')
  table.insert(command, current_dir())
  return create_command(command)
end

local function unity_command_editor(mode, on_success)
  unity_command(create_command({ mode, current_dir() }), on_success)
end

local function unity_command_project(command, on_success)
  unity_command(create_command_project(command), on_success)
end

local function unity_command_editor_playmode(mode, on_success)
  unity_command(create_command_project({ 'cmd', 'editor.playmode', mode }), on_success)
end

local function unity_play()
  unity_command_project({ 'status' }, function(obj)
    local instances = obj.data.instances or {}
    for _, instance in ipairs(instances) do
      if instance.frameCount ~= nil and instance.playerLoopTicking == true then
        unity_command_editor_playmode('stop')
      else
        unity_command_editor_playmode('start')
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
local function unity_pause() unity_command_editor_playmode('pause') end
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
