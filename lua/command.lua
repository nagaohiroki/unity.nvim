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
local function unity_command(command, on_success)
  if not has_unity_cli() then return end
  table.insert(command, 1, 'unity')
  table.insert(command, '--format')
  table.insert(command, 'json')
  vim.system(command, { text = true }, function(obj)
    local result = vim.json.decode(obj.stdout)
    if result.success == false then
      vim.schedule(function()
        local errors = result.errors
        local msg = errors and errors[1] and errors[1].message
        vim.notify(msg, vim.log.levels.ERROR)
      end)
      return
    end
    on_success(result)
  end)
end
local function unity_play()
  local cur = current_dir()
  unity_command({ 'status' },
    function(obj)
      local instances = obj.data.instances or {}
      for _, instance in ipairs(instances) do
        local project = vim.fs.normalize(instance.project)
        if project == cur then
          if instance.frameCount ~= nil and instance.playerLoopTicking == true then
            unity_command({ 'cmd', 'editor.playmode', 'stop' }, function(_) end)
          else
            unity_command({ 'cmd', 'editor.playmode', 'start' }, function(_) end)
          end
        end
      end
    end
  )
end
local function unity_recompile()
  local cur = current_dir()
  local wait = 2000
  local function parse_log(log, type)
    local file, line, col, msg = log:match("([%w%s%_%-%./%\\]+)%(?(%d+)%,?(%d*)%)?%:%s*(.*)")
    if not file then return nil end
    return {
      filename = vim.fs.normalize(vim.fs.joinpath(cur, file)),
      lnum = tonumber(line),
      col = tonumber(col) or 1,
      text = msg,
      type = type
    }
  end
  local function poll_status()
    unity_command({ 'cmd', 'recompile_status' }, function(status_obj)
      local data = status_obj.data or {}
      local result = data.result
      if not result or result.status ~= 'completed' then
        vim.defer_fn(poll_status, wait)
        return
      end
      local list = {}
      local errors = result.errors or {}
      for _, log in ipairs(errors) do
        table.insert(list, parse_log(log, 'E'))
      end
      vim.schedule(function()
        if #list == 0 then
          vim.cmd('cclose')
          vim.fn.setqflist({}, 'r')
        else
          vim.fn.setqflist(list, 'r')
          vim.cmd('copen')
        end
      end)
    end)
  end
  unity_command({ 'cmd', 'recompile' }, function(_)
    vim.defer_fn(poll_status, wait)
  end)
end
local function unity_pause()
  unity_command({ 'cmd', 'editor.playmode', 'pause' }, function(_) end)
end
local function unity_open()
  unity_command({ 'open', current_dir() }, function(_) end)
end
local function unity_close()
  unity_command({ 'cmd', 'eval', 'UnityEditor.EditorApplication.Exit(0);' },
    function(_) end)
end
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
