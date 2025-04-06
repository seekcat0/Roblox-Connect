local HttpService = game:GetService("HttpService")
local ws = (syn and syn.websocket) or WebSocket
local WebSocketInstance = nil
local URL = "ws://localhost:10000/"
local retrying = false

function connectWebSocket()
	if WebSocketInstance then
		WebSocketInstance:Close()
		WebSocketInstance = nil
	end

	local success, socket = pcall(function()
		return ws.connect(URL)
	end)
	if success and socket then
		WebSocketInstance = socket
		retrying = false
		print("🐱Success connect roblox client to VSC")

		WebSocketInstance.OnMessage:Connect(function(msg)
			local ok, data = pcall(function()
				return HttpService:JSONDecode(msg)
			end)
			if ok and data and data.type == "Run" and data.body then
				local runOk, err = pcall(function()
					loadstring(data.body)()
				end)
				if not runOk then
					warn("[ROBLOX EXECUTE ERROR]", err)
				end
			end
		end)
		WebSocketInstance.OnClose:Connect(function()
			print("💀 WebSocket closed. Reconnecting in 5s...")
			WebSocketInstance = nil
			startReconnect()
		end)
		WebSocketInstance:Send(HttpService:JSONEncode({
			type = "register",
			clientData = {
				LocalPlayer = {
					Name = game.Players.LocalPlayer.Name,
					DisplayName = game.Players.LocalPlayer.DisplayName,
					UserId = game.Players.LocalPlayer.UserId
				},
				ExploitName = identifyexecutor and identifyexecutor() or "Unknown",
				RobloxClient = version and version() or "Unknown"
			}
		}))

		game:GetService("ScriptContext").ErrorDetailed:Connect(function(message, stackTrace, script, details, securityLevel)
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
		print("🛑 Failed to connect WebSocket. Retrying in 5s...")
		WebSocketInstance = nil
        retrying = false
		startReconnect()
	end
end

function startReconnect()
	if retrying then return end
	retrying = true
	task.delay(5, function()
		connectWebSocket()
	end)
end

-- Khởi động
connectWebSocket()
