--[[
Copyright © 2025, from
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of Tab nor the
    names of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL from20020516 BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
_addon.name = 'NoSlowHaste'
_addon.author = 'Atilas'
_addon.version = '1.1'
_addon.command = 'nsh'
_addon.commands = {'help','debug'}
_addon.language = 'english'

--[[ 
-------------INSTRUCTIONS---------------
* Allow to freely target using default TAB, ALT-TAB, F8 or any other custom keys while in combat or locked to a target. 
* ESC will cancel sub-targetting and still allow quick peak at other mobs around.
* ENTER will select the sub-target and engage right away.
* You can map your own additional custom keys or set them to 0 if not needed.
]]

require('sets')
local packets = require('packets')
local res = require('resources')

debugmode = false
trustList = S{'Sylvie','Ygnas','Apururu','Ingrid','Cherukiki','Ferreous Coffin','Karaha-Baruha','Pieuje','Shikaree Z'}

windower.register_event('addon command', function(...)

	local arg = {...}
	if #arg > 1 then
		windower.add_to_chat(167, 'NoSlowHaste - Invalid command. //nsh help for valid options.')

	elseif #arg == 1 and arg[1]:lower() == 'debug' then
		if debugmode == true then
			debugmode = false
			windower.add_to_chat(200, 'NoSlowHaste - Stoping debug mode')
		else
			debugmode = true
			windower.add_to_chat(200, 'NoSlowHaste - Starting debug mode.')
		end

	elseif #arg == 0 or (#arg == 1 and arg[1]:lower() == 'help') then
		windower.add_to_chat(200, 'NoSlowHaste - Allow to automatically cancel Haste received from a trust to allow other trusts to override with HasteII.')
		windower.add_to_chat(200, 'Available Options:')
		windower.add_to_chat(200, '  //nsh debug - Toggle debug mode.')
		windower.add_to_chat(200, '  //nsh help  - Displays this text')
	end
end)


-- Track last spell cast to match with follow-up message
local last_spell_cast = {}

local player = windower.ffxi.get_player()
local player_id = player and player.id

local trust_haste_pending = false
local haste_ii_casted = false
local haste_i_timeout = 5
local haste_i_timer = 0

windower.register_event('incoming chunk', function(id, data)
    if id == 0x028 then
        local packet = packets.parse('incoming', data)

        if packet and packet['Category'] == 4 then
            local spell_id = packet['Param']
            local spell = res.spells[spell_id]
            local target_id = packet['Target 1 ID']
            local actor = windower.ffxi.get_mob_by_id(packet['Actor'])

            if not spell or target_id ~= player_id then return end

            if spell.en == 'Haste II' or spell.en == 'Erratic Flutter' then
				haste_ii_casted = true
				haste_i_timer = os.clock()
                if debugmode then windower.add_to_chat(200, 'HasteII cast detected on you.') end
            elseif spell.en == 'Haste' and actor and trustList[actor.name] then
                trust_haste_pending = true
				haste_i_timer = os.clock()
                if debugmode then windower.add_to_chat(200, 'A trust is casting Haste on you.') end
            end
        end
    end
end)

-- Reset Haste II flag after timeout
windower.register_event('prerender', function()
    if trust_haste_pending then
		if haste_ii_casted then
			trust_haste_pending = false
			haste_ii_casted = false
			if debugmode then windower.add_to_chat(200, 'Cancelling timer. HasteII was casted.') end
		elseif os.clock() - haste_i_timer > haste_i_timeout then
			if debugmode then windower.add_to_chat(200, 'Cancelling trust Haste. No HasteII detected.') end
			windower.ffxi.cancel_buff(33)
			trust_haste_pending = false
			haste_ii_casted = false
		end
	elseif haste_ii_casted then
		if os.clock() - haste_i_timer > haste_i_timeout then
			if debugmode then windower.add_to_chat(200, 'Cancelling HasteII check. Haste was never casted.') end
			haste_ii_casted = false
		end
	end
end)

