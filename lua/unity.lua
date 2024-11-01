local M = {}

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
		else
			uv.close(udp)
		end
	end)
	uv.run()
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
function M.setup()
	local functionTbl = {
		'Refresh',
		'Play',
		'Pause',
		'Unpause',
		'Stop',
		'PlayToggle',
		'PauseToggle',
	}
	for _, v in ipairs(functionTbl) do
		vim.api.nvim_create_user_command('U' .. v, function()
			request({ Type = v, Value = '' })
		end, {})
	end
	vim.api.nvim_create_user_command('InstallUnityDebugger', function()
		download_debugger(vstuc_path(),
			'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/VisualStudioToolsForUnity/vsextensions/vstuc/1.0.4/vspackage')
	end, {})
	vim.api.nvim_create_user_command('InstallUnityDebuggerOld', function()
		download_debugger(unity_debug_path(),
			'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/deitry/vsextensions/unity-debug/3.0.11/vspackage')
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
	return {
		type = 'vstuc',
		request = 'attach',
		name = 'Attach to Unity',
		logFile = vstuc_path() .. '/vstuc.log',
		projectPath = function()
			return find_path('/Assets')
		end,
		endPoint = function()
			return string.format('127.0.0.1:%d', unity_debugger_port())
		end
	}
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

return M
