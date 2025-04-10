local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ScriptContext = game:GetService("ScriptContext")

local function getGlobalTable()
	return typeof(getfenv().getgenv) == "function" and typeof(getfenv().getgenv()) == "table" and getfenv().getgenv() or _G
end

local WSConnect = 
    (syn and syn.websocket.connect) or 
    (Krnl and (function()
        repeat task.wait() until Krnl.WebSocket and Krnl.WebSocket.connect
        return Krnl.WebSocket.connect
    end)()) or 
    (WebSocket and WebSocket.connect) or 
    (function() error("WebSocket connection not supported in this environment.") end)()

if not WSConnect then
    error("WebSocket connection not supported in this environment.")
end

local WebSocketInstance = nil
local URL = getGlobalTable().WebsocketURL
local retrying = false

function connectWebSocket()
	if WebSocketInstance then
		WebSocketInstance:Close()
		WebSocketInstance = nil
	end

	local success, socket = pcall(function()
		return WSConnect(URL)
	end)
	if success and socket then
		WebSocketInstance = socket
		retrying = false
		print("🐱 Success connect roblox client to VSC")

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
				WebSocketInstance:Close()
				WebSocketInstance = nil
			end
		end)

		WebSocketInstance.OnClose:Connect(function()
			print("💀 WebSocket closed. Reconnecting in 5s...")
			WebSocketInstance = nil
			startReconnect()
		end)

		-- Gửi dữ liệu đăng ký
		WebSocketInstance:Send(HttpService:JSONEncode({
			type = "register",
			clientData = {
				LocalPlayer = {
					Name = Players.LocalPlayer.Name,
					DisplayName = Players.LocalPlayer.DisplayName,
					UserId = Players.LocalPlayer.UserId
				},
				ExploitName = identifyexecutor and identifyexecutor() or "Unknown",
				RobloxClient = version and version() or "Unknown"
			}
		}))

		-- Báo lỗi khi có script lỗi
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
		print("🛑 Failed to connect WebSocket. Retrying in 5s...")
		WebSocketInstance = nil
		retrying = false
		startReconnect()
	end
end

function startReconnect()
	if retrying then return end
	retrying = true
	task.delay(5, connectWebSocket)
end

-- Start connect
connectWebSocket()
