local M = {}
function M.setup()
	local unitydap = require('unitydap')
	unitydap.setup()
	local command = require('command')
	command.setup()
end

return M
