AddCSLuaFile("autorun/client/clipping.lua")
AddCSLuaFile("autorun/client/preview.lua")

util.AddNetworkString("clipping_new_clip")
util.AddNetworkString("clipping_all_prop_clip")
util.AddNetworkString("clipping_request_all_clips")
util.AddNetworkString("clipping_remove_clips")

Clipping = {}

Clipping.EntityClips = {}
Clipping.Queue = {}

local function WriteAngleAsFloat( angle )
	net.WriteFloat( angle.p )
	net.WriteFloat( angle.y )
	net.WriteFloat( angle.r )
end

local function WriteClip( clip )
	WriteAngleAsFloat( clip[1] )
	net.WriteDouble( clip[2] )
end

local function SendEntClip( ent , clip )
	net.Start( "clipping_new_clip" )
		net.WriteEntity( ent )
		WriteClip( clip )
	net.Broadcast()
end

function Clipping.NewClip( ent , clip )
	if not Clipping.EntityClips[ ent ] then
		Clipping.EntityClips[ ent ] = {clip}
	else
		table.insert( Clipping.EntityClips[ ent ] , clip )
	end

	ent:CallOnRemove( "RemoveFromClippedTable" , function( ent ) Clipping.EntityClips[ent] = nil end)
	duplicator.StoreEntityModifier( ent , "clipping_all_prop_clips", Clipping.EntityClips[ ent ] )

	SendEntClip( ent , clip )
end

function Clipping.SendAllPropClips( ent , player )
	net.Start( "clipping_all_prop_clips" )
		net.WriteEntity( ent )
		net.WriteInt( #Clipping.EntityClips[ent] , 16 )

		for k , clip in pairs( Clipping.EntityClips[ent] ) do
			WriteClip( clip )
		end
	net.Send( player )
end


net.Receive("clipping_request_all_clips" , function(_,ply)
	for ent , _ in pairs( Clipping.EntityClips ) do
		if IsValid(ent) and IsValid(ply) then
			Clipping.Queue[ #Clipping.Queue + 1 ] = {ent,ply}
		end
	end
end)

hook.Add( "Think" , "Clipping_Send_All_Clips" , function()
	if #Clipping.Queue > 0 then
		Clipping.SendAllPropClips( Clipping.Queue[ #Clipping.Queue ][1] , Clipping.Queue[ #Clipping.Queue ][2] )

		Clipping.Queue[ #Clipping.Queue ] = nil
	end
end)

function Clipping.RemoveClips( ent )
	Clipping.EntityClips[ ent ] = notification.AddLegacy()

	net.Start( "clipping_remove_clips" )
		net.WriteEntity( ent )
	net.Broadcast()
end

duplicator.RegisterEntityModifier( "clipping_all_prop_clips", function( p , ent , data)
	if !IsValid(ent) or !data then return end

	for _ , clip in pairs(data) do
		Clipping.NewClip( ent , clip)
	end
end)