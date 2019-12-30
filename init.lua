--------------------------------------------------------
-- Minetest :: LiveStats Mod v1.1 (livestats)
--
-- See README.txt for licensing and other information.
-- Copyright (c) 2018-2019, Leslie Ellen Krause
--
-- ./games/minetest_game/mods/livestats/init.lua
--------------------------------------------------------

local export_timer = 0
local export_filespec = "/var/www/html/assets/minetest.js"
local export_player_bounds = { x_min = -400, x_max = 400, z_min = -400, z_max = 400, y_min = -55 }
local server_uptime = 0.0
local server_max_lag = 0.0
local server_avg_lag = 0.0

local rtime = 1
local xtime = 20

minetest.register_globalstep( function( dtime )

	rtime = rtime + dtime
	xtime = xtime + dtime

	-- every 20 seconds export server and player stats
        if export_filespec and xtime >= 20 then
		local file, err = io.open( export_filespec, "w" )
		local ctime = os.time( )
		local env_time = minetest.get_timeofday( ) * 24 * 60
		local env_date = minetest.get_day_count( )

		if err then return end

		file:write( string.format( 'mt_server_stats = { uptime: %d, max_lag: %0.2f, avg_lag: %0.2f };\n', server_uptime, server_max_lag, server_avg_lag ) )
		file:write( string.format( 'mt_locale_stats = { env_date: %d, env_time: %d };\n', env_date, env_time ) )

		file:write( 'mt_player_stats = [\n' )
        	for i, p in ipairs( registry.player_list ) do
			local pos = p.obj:getpos( )
			local hp = p.obj:get_hp( )
			local bounds = export_player_bounds

			if pos.x >= bounds.x_min and pos.x <= bounds.x_max and pos.z >= bounds.z_min and pos.z <= bounds.z_max and pos.y >= bounds.y_min then
	                	file:write( string.format( '\t{ name: "%s", rank: %d, time: %d, skin: "%s", life: %d, horz: %d, vert: %d },\n',
					p.name, p.rank - 1, ctime - p.newtime, skins.skins[ p.name ], hp, pos.x, pos.z ) )
			else
	                	file:write( string.format( '\t{ name: "%s", rank: %d, time: %d, skin: "%s", life: %d, horz: null, vert: null },\n',
					p.name, p.rank - 1, ctime - p.newtime, skins.skins[ p.name ], hp ) )
			end
		end
		file:write( '];\n' )
		file:close( )

		xtime = 0
	end

	-- every second record server max_lag and avg_lag
	if rtime >= 1 then
		local s = minetest.get_server_status( )
server_uptime = s.uptime
server_avg_lag = s.avg_lag
server_max_lag = s.max_lag

--		server_uptime, server_avg_lag = string.match( s, "uptime=([0-9.]+), max_lag=([0-9.]+)" )
--		server_uptime = tonumber( server_uptime )
--		server_avg_lag = tonumber( server_avg_lag )
		server_max_lag = math.max( server_max_lag, server_avg_lag )

		rtime = 0
	end
end )

minetest.register_on_shutdown( function( )
	if not export_filespec then return end

	local file, err = io.open( export_filespec, "w" )
	if err then return end

	file:write( 'mt_server_stats = null;\n' )
	file:close( )
end )

minetest.register_chatcommand( "top", {
        description = "Show realtime information about the server",
        privs = "privs",
        func = function( name, param )
		local page_size = 10
		local page_idx = 1

		local get_formspec = function( )
        	        local server_addr = minetest.setting_get( "server_address" )
	                local server_port = minetest.setting_get( "port" )

			local formspec = "size[10.5,8.5]"
				.. default.gui_bg
				.. default.gui_bg_img

				.. string.format( "label[0.1,0.0;%s]label[0.1,0.5;%s]",
					minetest.colorize( "#888888", "localtime:" ), os.date( "%X" ) )
				.. string.format( "label[4.0,0.0;%s]label[4.0,0.5.0;%dm %02ds]",
					minetest.colorize( "#888888", "uptime:" ), server_uptime / 60, server_uptime % 60 )
				.. string.format( "label[6.0,0.0;%s]label[6.0,0.5;%0.2fs]",
					minetest.colorize( "#888888", "avg_lag:" ), server_avg_lag )
				.. string.format( "label[7.5,0.0;%s]label[7.5,0.5.0;%0.2fs]",
					minetest.colorize( "#888888", "max_lag:" ), server_max_lag )
				.. string.format( "label[9.0,0.0;%s]label[9.0,0.5;%d of %d]",
					minetest.colorize( "#888888", "cur_users:" ), #registry.player_list, minetest.setting_get( "max_users" ) )
				.. string.format( "label[0.1,7.5;%s]label[0.1,8.0;%s]",
					minetest.colorize( "#888888", "address:" ), server_addr ~= "" and server_addr or "localhost" )
				.. string.format( "label[4,7.5.0;%s]label[4.0,8.0;%d]",
					minetest.colorize( "#888888", "port:" ), server_port )
				.. string.format( "label[0.1,1.5;%s]label[1.0,1.5;%s]label[4.0,1.5;%s]label[6.5,1.5;%s]label[9.0,1.5;%s]",
					minetest.colorize( "#888888", "uid:" ), 
					minetest.colorize( "#888888", "name:" ), 
					minetest.colorize( "#888888", "rank:" ), 
					minetest.colorize( "#888888", "address:" ), 
					minetest.colorize( "#888888", "lifetime:" )
				)
				.. "button[7.5,7.5;1,1;prev;<<]"
				.. string.format( "label[8.5,7.8;%d of %d]", page_idx, math.max( math.ceil( #registry.player_list / page_size ) ) )
				.. "button[9.5,7.5;1,1;next;>>]"

				.. "box[0.0,1.2;10.3,0.1;#111111]"
				.. "box[0.0,7.2;10.3,0.1;#111111]"

			local num = 0
			local ctime = os.time( )

			for idx = ( page_idx - 1 ) * page_size + 1, math.min( page_idx * page_size, #registry.player_list ) do
				local p = registry.player_list[ idx ]
				local address = minetest.get_player_information( p.name ).address
				local lifetime =  ctime - p.newtime

				local vert = 2.0 + num * 0.5
				formspec = formspec 
					.. string.format( "label[0.1,%0.1f;%03d]", vert, p.pid )
					.. string.format( "image[1.0,%0.1f;0.3,0.6;%s_preview.png]", vert, skins.skins[ p.name ] )
					.. string.format( "label[1.5,%0.1f;%s]", vert, minetest.colorize( registry.rank_colors[ p.rank ], p.name ) )
					.. string.format( "label[4.0,%0.1f;%s]", vert, registry.rank_titles[ p.rank ] )
					.. string.format( "label[6.5,%0.1f;%s]", vert, address )
					.. string.format( "label[9.0,%0.1f;%dm %02ds]", vert, math.floor( lifetime / 60 ), lifetime % 60 )
				num = num + 1
			end
			return formspec
		end

		minetest.create_form( nil, name, get_formspec( ), function ( meta, player, fields ) 
			if fields.quit == minetest.FORMSPEC_SIGTIME then
				minetest.update_form( player, get_formspec( meta.page ) )

			elseif fields.prev and page_idx > 1 then
				page_idx = page_idx - 1
				minetest.update_form( player, get_formspec( ) )

			elseif fields.next and page_idx < #registry.player_list / page_size then
				page_idx = page_idx + 1
				minetest.update_form( player, get_formspec( ) )
			end
		end )
		minetest.get_form_timer( name ).start( 2.5 )

		return true
	end,
})

