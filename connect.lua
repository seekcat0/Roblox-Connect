local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ScriptContext = game:GetService("ScriptContext")

local function getGlobalTable()
	return typeof(getfenv().getgenv) == "function" and typeof(getfenv().getgenv()) == "table" and getfenv().getgenv() or _G
end

local robloxclient = getfenv().version and getfenv().version() or "Unknown"
local NotConnectMore = false
local isServerDisconnect = false
local triedLocalhost = false
local WebSocketInstance = nil

-- Logging tiện lợi
local function logInfo(msg) print("🔷 [Info] " .. msg) end
local function logSuccess(msg) print("🟢 [Success] " .. msg) end
local function logWarn(msg) warn("🟡 [Warning] " .. msg) end
local function logError(msg) warn("🔴 [Error] " .. msg) end

local WSConnect =
	(syn and syn.websocket.connect) or
	(Krnl and (function()
		repeat task.wait() until Krnl.WebSocket and Krnl.WebSocket.connect
		return Krnl.WebSocket.connect
	end)()) or
	(WebSocket and WebSocket.connect) or
	(function() error("WebSocket connection not supported in this environment.") end)()

local function getUrlToTry()
	if not triedLocalhost then
		return "ws://localhost:10250/"
	else
		local global = getGlobalTable()
		local url = global.WebsocketURL
		if type(url) ~= "string" or not (url:lower():sub(1, 5) == "ws://" or url:lower():sub(1, 6) == "wss://") then
			logError("No valid WebSocket Providers found.")
			return nil
		end
		return url
	end
end

local function startReconnect()
	if NotConnectMore or isServerDisconnect then return end
	task.delay(5, function()
		logWarn("Trying to reconnect WebSocket...")
		connectWebSocket()
	end)
end

function connectWebSocket()
	if NotConnectMore then return end

	local URL = getUrlToTry()
	if not URL then return end

	if WebSocketInstance then
		WebSocketInstance:Close()
		WebSocketInstance = nil
	end

	local success, socket = pcall(function()
		return WSConnect(URL)
	end)

	if success and socket then
		WebSocketInstance = socket
		logSuccess("Connected to: " .. URL)

		WebSocketInstance.OnMessage:Connect(function(msg)
			local ok, data = pcall(function()
				return HttpService:JSONDecode(msg)
			end)
			if not ok or not data then return end

			if data.type == "run_lua" and data.body then
				local runOk, err = pcall(function()
					loadstring(data.body)()
				end)
				if not runOk then
					logError("Execution error: " .. tostring(err))
				end

			elseif data.type == "disconnect" then
				logWarn("Disconnected by server.")
				isServerDisconnect = true
				NotConnectMore = true
				WebSocketInstance:Close()
				WebSocketInstance = nil
			end
		end)

		WebSocketInstance.OnClose:Connect(function()
			if not isServerDisconnect then
				logWarn("WebSocket closed unexpectedly. Reconnecting in 5s...")
				WebSocketInstance = nil
				if not triedLocalhost then
					triedLocalhost = true
				end
				startReconnect()
			end
		end)

		WebSocketInstance:Send(HttpService:JSONEncode({
			type = "register",
			clientData = {
				LocalPlayer = {
					Name = Players.LocalPlayer.Name,
					DisplayName = Players.LocalPlayer.DisplayName,
					UserId = Players.LocalPlayer.UserId
				},
				ExploitName = identifyexecutor and identifyexecutor() or "Unknown",
				RobloxClient = robloxclient
			}
		}))

		ScriptContext.ErrorDetailed:Connect(function(message, stackTrace, script, details, securityLevel)
			if WebSocketInstance then
				WebSocketInstance:Send(HttpService:JSONEncode({
					type = "detailed_error",
					data = {
						message = message,
						stackTrace = stackTrace,
						details = details,
						securityLevel = securityLevel,
					}
				}))
			end
		end)
	else
		logError("Failed to connect to: " .. tostring(URL))
		if not triedLocalhost then
			triedLocalhost = true
		end
		startReconnect()
	end
end

-- 🚀 Khởi động
logInfo("🔌 Starting WebSocket connection...")
connectWebSocket()
