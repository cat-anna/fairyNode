local PI = math.pi
local sin = math.sin
local cos = math.cos
local tan = math.tan
local asin = math.asin
local atan = math.atan2
local acos = math.acos
local deg = math.deg
local rad = PI / 180
local e = rad * 23.4397 -- obliquity of the Earth
local daysec = 60 * 60 * 24
local J1970 = 2440588
local J2000 = 2451545

-- https:--github.com/mourner/suncalc/blob/master/suncalc.js

-- sun calculations are based on http:--aa.quae.nl/en/reken/zonpositie.html formulas
local function toDays(time) return time / daysec - 0.5 + J1970 - J2000 end

local function siderealTime(d, lw) return rad * (280.16 + 360.9856235 * d) - lw end

local function rightAscension(l, b)
    return atan(sin(l) * cos(e) - tan(b) * sin(e), cos(l))
end

local function declination(l, b)
    return asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l))
end

local function azimuth(H, phi, dec)
    return atan(sin(H), cos(H) * sin(phi) - tan(dec) * cos(phi))
end

local function altitude(H, phi, dec)
    return asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H))
end

local function astroRefraction(h)
    if h < 0 then -- the following formula works for positive altitudes only.
        h = 0 -- if h = -0.08901179 a div/0 would occur.
    end

    -- formula 16.4 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
    -- 1.02 / tan(h + 10.26 / (h + 5.10)) h in degrees, result in arc minutes -> converted to rad:
    return 0.0002967 / math.tan(h + 0.00312536 / (h + 0.08901179))
end

-- general sun calculations
local function solarMeanAnomaly(d) return rad * (357.5291 + 0.98560028 * d) end

local function eclipticLongitude(M)
    local C = rad * (1.9148 * sin(M) + 0.02 * sin(2 * M) + 0.0003 * sin(3 * M)) -- equation of center
    local P = rad * 102.9372 -- perihelion of the Earth
    return M + C + P + PI
end

local function sunCoords(d)
    local M = solarMeanAnomaly(d)
    local L = eclipticLongitude(M)
    return {dec = declination(L, 0), ra = rightAscension(L, 0)}
end

local SunCalc = {}

function SunCalc.GetSunPosition(lat, lng, time)
    local lw = rad * -lng
    local phi = rad * lat
    local d = toDays(time or os.time())
    local s = sunCoords(d)
    local H = siderealTime(d, lw) - s.ra

    local alt, az = altitude(H, phi, s.dec), azimuth(H, phi, s.dec)

    return {altitude = deg(alt), azimuth = 180 + deg(az)}
end

local function moonCoords(d) -- geocentric ecliptic coordinates of the moon
    local L = rad * (218.316 + 13.176396 * d) -- ecliptic longitude
    local M = rad * (134.963 + 13.064993 * d) -- mean anomaly
    local F = rad * (93.272 + 13.229350 * d) -- mean distance
    local l = L + rad * 6.289 * sin(M) -- longitude
    local b = rad * 5.128 * sin(F) -- latitude
    local dt = 385001 - 20905 * cos(M) -- distance to the moon in km

    return {ra = rightAscension(l, b), dec = declination(l, b), dist = dt}
end

function SunCalc.GetMoonPhase(time)
    local d = toDays(time or os.time())
    local s = sunCoords(d)
    local m = moonCoords(d)

    local sdist = 149598000 --  distance from Earth to Sun in km

    local phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) *
                         cos(s.ra - m.ra))
    local inc = atan(sdist * sin(phi), m.dist - sdist * cos(phi))
    local angle = atan(cos(s.dec) * sin(s.ra - m.ra), sin(s.dec) * cos(m.dec) -
                           cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra))

    return {
        fraction = (1 + cos(inc)) / 2,
        phase = 0.5 + 0.5 * inc * (angle < 0 and -1 or 1) / PI,
        angle = deg(angle)
    }
end

function SunCalc.GetMoonPosition(lat, lng, time)
    local lw = rad * -lng
    local phi = rad * lat
    local d = toDays(time or os.time())
    local c = moonCoords(d)
    local H = siderealTime(d, lw) - c.ra
    local h = altitude(H, phi, c.dec)
    -- formula 14.1 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
    local pa = atan(sin(H), tan(phi) * cos(c.dec) - sin(c.dec) * cos(H));

    h = h + astroRefraction(h); -- altitude correction for refraction

    return {
        azimuth = 180 + deg(azimuth(H, phi, c.dec)),
        altitude = deg(h),
        distance = c.dist,
        parallacticAngle = pa
    }
end

return SunCalc
