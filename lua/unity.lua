local M = {}
M._config = { discover_time = 2000 }

local function find_path(target)
  local path = vim.fn.expand('%:p')
  while true do
    local new_path = vim.fn.fnamemodify(path, ':h')
    if new_path == path then
      return ''
    end
    path = new_path
    local target_path = vim.fn.glob(path .. target)
    if target_path ~= '' then
      return path
    end
  end
end
local function find_editor_instance_json()
  local editor_instance = '/Library/EditorInstance.json'
  return find_path(editor_instance) .. editor_instance
end
local function get_process_id()
  local editor_instance = find_editor_instance_json()
  local file = io.open(editor_instance, 'r')
  if file == nil then
    vim.print('cannot open ' .. editor_instance)
    return nil
  end
  local text = file:read('a')
  local json = vim.json.decode(text)
  file:close()
  return json.process_id
end
local function unity_debugger_port()
  local process_id = get_process_id()
  if process_id == nil then
    return nil
  end
  return 56000 + (process_id % 1000)
end
local function unity_message_port()
  local debugger_port = unity_debugger_port()
  if debugger_port == nil then
    return nil
  end
  return debugger_port + 2
end
local function request(tbl)
  local messager_port = unity_message_port()
  if messager_port == nil then
    return
  end
  local uv = vim.uv
  local udp = uv.new_udp()
  local json = vim.fn.json_encode(tbl)
  uv.udp_send(udp, json, '127.0.0.1', messager_port, function(err)
    if err then
      vim.print('error:', err)
    end
  end)
  uv.close(udp)
end

local function download_debugger(dir, url)
  if vim.fn.isdirectory(dir) == 1 then
    vim.print('vstuc already downloaded ' .. dir)
    return
  end
  local out = dir .. '/tmp.zip'
  vim.fn.mkdir(dir, 'p')
  vim.system({ 'curl', '--compressed', '-L', url, '-o', out }, { text = true }, function(_)
    vim.print('done download.' .. url)
    vim.print('start extract')
    vim.system({ 'tar', 'xf', out, '-C', dir }, { text = true }, function(_)
      vim.print('done extract. ' .. dir)
      os.remove(out)
    end)
  end)
end

local function vstuc_path()
  return vim.fn.fnameescape(vim.fn.stdpath('data') .. '/unity-debugger/vstuc')
end
local function unity_debug_path()
  return vim.fn.fnameescape(vim.fn.stdpath('data') .. '/unity-debugger/unity-debug')
end
local function unity_attach_probs()
  vim.notify('searching proccess...')
  local probs = {}
  local system_obj = vim.system(
    { 'dotnet', vstuc_path() .. '/extension/bin/UnityAttachProbe.dll' },
    { text = true, stdin = true })
  local completed = system_obj:wait(M._config.discover_time)
  local stdout = completed.stdout
  if stdout == nil or #stdout == 0 then
    print('No endpoint found (is unity running?)')
    return nil
  end
  for json in vim.gsplit(stdout, '\n') do
    if json ~= '' then
      local probe = vim.json.decode(json)
      for _, p in pairs(probe) do
        if p.isBackground == false then
          local is_unique = true
          for _, v in pairs(probs) do
            if v.debuggerPort == p.debuggerPort then
              is_unique = false
            end
          end
          if is_unique == true then
            probs[#probs + 1] = p
          end
        end
      end
    end
  end
  vim.notify('done.')
  return probs
end
function M.setup(config)
  config = config or {}
  M._config = vim.tbl_extend('force', M._config, config)
  local functionTbl = {
    'Refresh',
    'Play',
    'Pause',
    'Unpause',
    'Stop',
  }
  for _, v in ipairs(functionTbl) do
    vim.api.nvim_create_user_command('U' .. v, function()
      request({ Type = v, Value = '' })
    end, {})
  end
  vim.api.nvim_create_user_command('InstallUnityDebugger', function()
    download_debugger(vstuc_path(),
      'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/VisualStudioToolsForUnity/vsextensions/vstuc/1.1.0/vspackage')
  end, {})
  vim.api.nvim_create_user_command('InstallUnityDebuggerOld', function()
    download_debugger(unity_debug_path(),
      'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/deitry/vsextensions/unity-debug/3.0.11/vspackage')
  end, {})

  vim.api.nvim_create_user_command('ShowUnityProcess', function()
    local probs = unity_attach_probs()
    if probs == nil then
      vim.print('No endpoint found (is unity running?)')
      return
    end
    for _, p in ipairs(probs) do
      vim.print(p)
    end
  end, {})
end

function M.vstuc_dap_adapter()
  return {
    type = 'executable',
    command = 'dotnet',
    args = { vstuc_path() .. '/extension/bin/UnityDebugAdapter.dll' },
    name = 'Attach to Unity'
  }
end

function M.vstuc_dap_configuration()
  if vim.bo.filetype ~= 'cs' then
    return nil
  end
  local probs = unity_attach_probs()
  if probs == nil then
    vim.notify('No endpoint found (is unity running?)')
    return nil
  end
  local tbl = {}
  for _, p in ipairs(probs) do
    local address = p.address .. ':' .. p.debuggerPort
    local name = string.format('%s(%s:%s) %s pid:%s', p.projectName, p.machine, p.type, address, p.processId)
    if p.unityPlayer ~= vim.NIL then
      name = string.format('%s(%s)', name, p.unityPlayer.packageName)
    end
    tbl[#tbl + 1] = {
      type = 'vstuc',
      request = 'attach',
      name = name,
      logFile = vstuc_path() .. '/vstuc' .. p.type .. '.log',
      projectPath = find_path('/Assets'),
      endPoint = address
    }
  end
  return tbl
end

function M.unity_dap_adapter()
  local unityDebugCommand = unity_debug_path() .. '/extension/bin/UnityDebug.exe'
  local unityDebugArgs = {}
  if vim.fn.has('win32') == 0 then
    unityDebugArgs = { unityDebugCommand }
    unityDebugCommand = 'mono'
  end
  return {
    type = 'executable',
    command = unityDebugCommand,
    args = unityDebugArgs,
    name = 'Unity Editor',
  }
end

function M.unity_dap_configuration()
  return {
    type = 'unity',
    request = 'launch',
    name = 'Unity Editor',
    path = function() return find_editor_instance_json() end
  }
end

function M.setup_vstuc()
  local dap                = require('dap')
  dap.adapters.vstuc       = M.vstuc_dap_adapter()
  dap.providers.configs.cs = function(_) return M.vstuc_dap_configuration() end
end

--- @deprecated
function M.setup_unity_debugger()
  local dap                = require('dap')
  dap.adapters.unity       = M.unity_dap_adapter()
  dap.providers.configs.cs = function(_) return { M.unity_dap_configuration() } end
end

return M
