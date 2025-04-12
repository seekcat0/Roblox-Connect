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
		return getGlobalTable().WebsocketURL
	end
end

local function startReconnect()
	if NotConnectMore or isServerDisconnect then return end
	task.delay(5, function()
		connectWebSocket()
	end)
end

function connectWebSocket()
	if NotConnectMore then return end

	local URL = getUrlToTry()

	if WebSocketInstance then
		WebSocketInstance:Close()
		WebSocketInstance = nil
	end

	local success, socket = pcall(function()
		return WSConnect(URL)
	end)

	if success and socket then
		WebSocketInstance = socket
		print("✅ Connected to " .. URL)

		WebSocketInstance.OnMessage:Connect(function(msg)
			local ok, data = pcall(function()
				return HttpService:JSONDecode(msg)
			end)
			if not ok or not data then return end

			if data.type == "Run" and data.Lua then
				local runOk, err = pcall(function()
					loadstring(data.Lua)()
				end)
				if not runOk then
					warn("[ROBLOX EXECUTE ERROR]", err)
				end

			elseif data.type == "disconnect" then
				print("🛑 Disconnected by server.")
				isServerDisconnect = true
				NotConnectMore = true
				WebSocketInstance:Close()
				WebSocketInstance = nil
			end
		end)

		WebSocketInstance.OnClose:Connect(function()
			if not isServerDisconnect then
				print("💀 WebSocket closed. Reconnecting in 5s...")
				WebSocketInstance = nil
				if not triedLocalhost then
					triedLocalhost = true
				end
				startReconnect()
			end
		end)

		-- Send client info
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

		-- Script error reporting
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
		print("🛑 Failed to connect to " .. URL)
		if not triedLocalhost then
			triedLocalhost = true
		end
		startReconnect()
	end
end

-- Start connection
connectWebSocket()
