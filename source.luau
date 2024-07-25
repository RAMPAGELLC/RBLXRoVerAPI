-- Copyright (c) 2024 RAMPAGE Interactive. All rights reserved.
-- Copyright (c) 2024 Metatable Games. All rights reserved.
-- Written by vq9o <business@vq9o.com>

-- License: MIT
-- GitHub: https://github.com/RAMPAGELLC/RBLXRoVerAPI

local HttpService = game:GetService("HttpService")

local RoVerAPI = {}
RoVerAPI.__index = RoVerAPI

function RoVerAPI.new(apiKey)
    local self = setmetatable({}, RoVerAPI)
    
    self.apiKey = apiKey
    self.rateLimits = {}

    return self
end

function RoVerAPI:Request(method, url, data)
    local bucket = url
    local rateLimit = self.rateLimits[bucket] or {remaining = 1, resetAfter = 0}

    if rateLimit.remaining <= 0 then
        warn("Rate limit exceeded. Waiting for reset...")
        task.wait(rateLimit.resetAfter)
    end

    local response
    local success, errorMessage = pcall(function()
        response = HttpService:RequestAsync({
            Url = url,
            Method = method,
            Headers = {
                ["Authorization"] = "Bearer " .. self.apiKey,
                ["Content-Type"] = "application/json"
            },
            Body = data and HttpService:JSONEncode(data) or nil
        })
    end)

    if not success then
        warn("HTTP request failed: " .. errorMessage)
        return nil, errorMessage
    end

    local headers = response.Headers
    self.rateLimits[bucket] = {
        remaining = tonumber(headers["X-RateLimit-Remaining"]) or 0,
        resetAfter = tonumber(headers["X-RateLimit-Reset-After"]) or 0
    }

    if headers["Retry-After"] then
        warn("Retry-After header received. Waiting...")
        wait(tonumber(headers["Retry-After"]))
    end

    if response.StatusCode == 429 then
        warn("Received 429 Too Many Requests. Waiting for reset...")
        wait(self.rateLimits[bucket].resetAfter)
        return self:Request(method, url, data)
    end

    if response.StatusCode >= 400 then
        if response.Headers["Content-Type"] == "application/json;charset=UTF-8" then
            local errorResponse = HttpService:JSONDecode(response.Body)
            warn("Error: " .. errorResponse.message)
            return nil, errorResponse
        else
            warn("Unexpected error response")
            return nil, response.Body
        end
    end

    return HttpService:JSONDecode(response.Body), nil
end

function RoVerAPI:GET(url)
    return self:Request("GET", url, nil)
end

function RoVerAPI:POST(url, data)
    return self:Request("POST", url, data)
end

return RoVerAPI
