-- UUID v7 生成（个人定制，独立于上游 lua/uuid.lua，避免同步上游时被覆盖）
-- RFC 9562: 48 位大端 Unix 毫秒时间戳 + 版本号 7 + 12 位随机
--           + 变体位 10xx + 62 位随机
-- Lua 5.1 / LuaJIT 兼容：不使用 5.3 的整数除法 `//` 和位运算符，
-- 用 floor(x / 2^n) % 2^m 拆字节。48 位时间戳在 double 下可精确表示。
local function yield_cand(seg, text)
	local cand = Candidate("", seg.start, seg._end, text, "v7")
	cand.quality = 101  -- 略高于上游 uuid.lua 的 v4（100），使 v7 排在 v4 前面
	yield(cand)
end

local fmt = string.format
local rand = math.random
local randomseed = math.randomseed
local floor = math.floor

local function generate_uuid_v7()
	local ms = os.time() * 1000 + rand(0, 999)

	-- 拆出时间戳的 6 个字节（大端）
	local t5 = floor(ms / 2 ^ 40) % 256
	local t4 = floor(ms / 2 ^ 32) % 256
	local t3 = floor(ms / 2 ^ 24) % 256
	local t2 = floor(ms / 2 ^ 16) % 256
	local t1 = floor(ms / 2 ^ 8) % 256
	local t0 = ms % 256

	-- 版本号 7 占据第 13 个 hex 位（该字节高 4 位固定为 0111）
	local ver_rand_hi = rand(0, 255) % 16 + 0x70
	local rand_a_lo = rand(0, 255)

	-- 变体位 10xx 占据第 17 个 hex 位（该字节高 2 位固定为 10）
	local var_rand_hi = rand(0, 255) % 64 + 0x80

	return fmt(
		"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
		t5,
		t4,
		t3,
		t2,
		t1,
		t0,
		ver_rand_hi,
		rand_a_lo,
		var_rand_hi,
		rand(0, 255),
		rand(0, 255),
		rand(0, 255),
		rand(0, 255),
		rand(0, 255),
		rand(0, 255),
		rand(0, 255)
	)
end

local M = {}

function M.init(env)
	randomseed(math.floor(os.time() + os.clock() * 1000))
	M.uuid = env.engine.schema.config:get_string(env.name_space:gsub("^*", "")) or "uuid"
end

function M.func(input, seg, _)
	if input == M.uuid then
		yield_cand(seg, generate_uuid_v7())
	end
end

return M
