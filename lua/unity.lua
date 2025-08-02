local M = {}
local debugger_installer = require('debugger_installer')
M._config = {
  discover_time       = 2000,
  install_path        = vim.fs.joinpath(vim.fn.stdpath('data'), 'unity-debugger', 'extensions'),
  install_path_vscode = vim.fs.joinpath(vim.env.HOME, '.vscode', 'extensions'),
  debugger            = 'vstuc',
  debuggers           =
  {
    vstuc =
    {
      publisher = 'VisualStudioToolsForUnity',
      extension = 'vstuc',
      version   = '1.1.2',
    },
    unity_debug =
    {
      publisher = 'deitry',
      extension = 'unity-debug',
      version   = '3.0.11',
    },
  },
}

local function PortFromLogFile(file_path)
  local file = io.open(file_path, 'r')
  if file == nil then return end
  local lines = file:lines()
  local line_table = {}
  local count = 0
  for line in lines do
    count = count + 1
    line_table[count] = line
  end
  file:close()
  if count < 2 then return end
  if vim.startswith(line_table[count], 'PlayerConnection::Cleanup') then return end
  local one = line_table[1]
  if one == nil then return end
  local two = line_table[2]
  if two == nil then return end
  local port = one:match('Starting managed debugger on port (%d+)')
  if port == nil then return end
  local ip = two:match('(%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?)$')
  if ip == nil then return end
  return ip .. ':' .. port
end

local function GatheringPorts()
  local ports = {}
  local count = 0
  local locallow = ''
  if vim.fn.has('win32') == 1 then
    locallow = vim.fs.normalize(vim.fs.joinpath(os.getenv('USERPROFILE'), 'AppData', 'LocalLow'))
  end
  if vim.fn.has('mac') == 1 then
    locallow = vim.fs.normalize(vim.fs.joinpath(os.getenv('HOME'), 'Library', 'Application Support'))
  end
  if locallow == '' then return end
  local files = vim.fn.findfile('Player.log', locallow .. '/*/*', -1)
  for _, f in pairs(files) do
    local port = PortFromLogFile(f)
    if port ~= nil then
      count = count + 1
      ports[count] = { name = vim.fs.basename(vim.fs.dirname(vim.fs.abspath(f))), port = port }
    end
  end
  return ports
end

local function find_editor_instance_json()
  return vim.fn.findfile(vim.fs.joinpath('Library', 'EditorInstance.json'), '.;')
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
  if messager_port == nil then return end
  local udp = vim.uv.new_udp()
  if udp == nil then return end
  local json = vim.fn.json_encode(tbl)
  vim.uv.udp_send(udp, json, '127.0.0.1', messager_port, function(err)
    if err then
      vim.print('error:', err)
    end
    vim.uv.close(udp)
  end)
end

local function get_path(debugger)
  return debugger_installer.get_path(debugger, M._config)
end

local function unity_attach_probs()
  vim.notify('searching proccess...')
  local probs = {}
  local system_obj = vim.system(
    { 'dotnet', vim.fs.joinpath(get_path('vstuc'), 'bin', 'UnityAttachProbe.dll') },
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

local function vstuc_dap_adapter()
  return {
    type = 'executable',
    command = 'dotnet',
    args = { vim.fs.joinpath(get_path('vstuc'), 'bin', 'UnityDebugAdapter.dll') },
    name = 'Attach to Unity'
  }
end

local function vstuc_dap_configuration()
  if vim.bo.filetype ~= 'cs' then
    return
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
      logFile = vim.fs.joinpath(vim.fn.stdpath('data'), 'dap_vstuc_' .. p.type .. '.log'),
      endPoint = address
    }
  end
  return tbl
end

local function unity_dap_adapter()
  local unityDebugCommand = vim.fs.joinpath(get_path('unity_debug'), 'bin', 'UnityDebug.exe')
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

local function unity_dap_configuration()
  if vim.bo.filetype ~= 'cs' then
    return
  end
  local tbl = {}
  tbl[#tbl + 1] = {
    type = 'unity',
    request = 'launch',
    name = 'Unity Editor',
    path = function() return find_editor_instance_json() end
  }
  local ports = GatheringPorts()
  if ports == nil then
    return tbl
  end
  for _, p in pairs(ports) do
    tbl[#tbl + 1] = {
      type = 'unity',
      request = 'launch',
      name = p.name,
      endPoint = p.port
    }
  end
  return tbl
end

local function setup_dap()
  local success, dap = pcall(require, 'dap')
  if not success then
    return
  end
  dap.providers.configs.cs = function(_)
    if M._config.debugger == 'unity-debug' then
      dap.adapters.unity = unity_dap_adapter()
      return unity_dap_configuration()
    end
    if M._config.debugger == 'vstuc' then
      dap.adapters.vstuc = vstuc_dap_adapter()
      return vstuc_dap_configuration()
    end
  end
end

local function create_user_commands()
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

  debugger_installer.create_user_commands(M._config)
end

function M.setup(config)
  M._config = vim.tbl_deep_extend('force', M._config, config or {})
  setup_dap()
  create_user_commands()
end

return M
