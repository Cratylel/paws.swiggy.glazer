untyped

global function Glazer_Init
global function Glazer_OnChatMessage
global function Glazer_ResetCommand
global function Glazer_StatusCommand
global function Glazer_TestCommand
global function Glazer_WhoCommand
global function Glazer_AddCommand
global function Glazer_AddUIDCommand

const float GLAZER_ECHO_WINDOW = 6.0

struct
{
	bool initialized = false
	array<int> bag
	table<string, float> recentlySent
	float lastReplyAt = -1000.0
	table playerUIDs
} file

void function Glazer_Init()
{
	// This runs at every map spawn, so each match starts with a fresh bag.
	Glazer_ResetBag()
	file.recentlySent.clear()
	file.lastReplyAt = -1000.0

	if ( file.initialized )
		return

	file.initialized = true

	if ( !( "AddCallback_OnReceivedSayTextMessage" in getroottable() ) )
	{
		print( "[Glazer] This Northstar version is too old for the chat callback. Update Northstar (1.6.0 or newer)." )
		return
	}

	AddCallback_OnReceivedSayTextMessage( Glazer_OnChatMessage )

	AddDestroyCallback( "player", void function( entity player )
	{
		if ( player in file.playerUIDs )
			delete file.playerUIDs[ player ]
	} )

	print( "[Glazer] Loaded with " + GlazeLines.len() + " glaze lines. Set target names/UIDs in Mod Settings." )
}

ClClient_MessageStruct function Glazer_OnChatMessage( ClClient_MessageStruct message )
{
	if ( Glazer_ShouldReply( message ) )
		thread Glazer_Reply( message.playerName, message.isTeam )

	return message
}

bool function Glazer_ShouldReply( ClClient_MessageStruct message )
{
	if ( !GetConVarBool( "glaze_enabled" ) )
		return false

	if ( message.player == null || !IsValid( message.player ) )
		return false

	if ( message.message == "" )
		return false

	if ( Glazer_IsEcho( message ) )
		return false

	if ( Time() - file.lastReplyAt < GetConVarFloat( "glaze_cooldown" ) )
		return false

	if ( RandomInt( 100 ) >= GetConVarInt( "glaze_chance" ) )
		return false

	return Glazer_IsTarget( message.player, message.playerName )
}

bool function Glazer_IsEcho( ClClient_MessageStruct message )
{
	entity localPlayer = GetLocalClientPlayer()
	if ( !IsValid( localPlayer ) || message.player != localPlayer )
		return false

	if ( !( message.message in file.recentlySent ) )
		return false

	return Time() - file.recentlySent[ message.message ] < GLAZER_ECHO_WINDOW
}

bool function Glazer_IsTarget( entity player, string playerName )
{
	string uid = Glazer_PlayerUID( player )
	if ( uid != "" && uid != "0" )
	{
		foreach ( string entry in split( GetConVarString( "glaze_target_uids" ), "," ) )
		{
			if ( strip( entry ) == uid )
				return true
		}
	}

	string taggedName = playerName.tolower()
	string plainName = player.GetPlayerName().tolower()
	string untaggedName = Glazer_StripClanTag( taggedName )

	foreach ( string entry in split( GetConVarString( "glaze_targets" ), "," ) )
	{
		string target = strip( entry ).tolower()
		if ( target == "" )
			continue

		if ( target == taggedName || target == plainName || target == untaggedName )
			return true
	}

	return false
}

string function Glazer_StripClanTag( string name )
{
	if ( name.len() < 3 || name.slice( 0, 1 ) != "[" )
		return name

	var closeBracket = name.find( "]" )
	if ( closeBracket == null )
		return name

	return strip( name.slice( expect int( closeBracket ) + 1 ) )
}

string function Glazer_PlayerUID( entity player )
{
	if ( !IsValid( player ) )
		return ""

	if ( !( player in file.playerUIDs ) )
	{
		// Player slots get reused when someone leaves, so drop stale entities.
		array<entity> stalePlayers
		foreach ( entity cachedPlayer, var entry in file.playerUIDs )
		{
			if ( !IsValid( cachedPlayer ) )
				stalePlayers.append( cachedPlayer )
		}

		foreach ( entity cachedPlayer in stalePlayers )
			delete file.playerUIDs[ cachedPlayer ]

		file.playerUIDs[ player ] <- { uid = "", nextRead = 0.0 }
	}

	var entry = file.playerUIDs[ player ]
	if ( entry.uid != "" || Time() < expect float( entry.nextRead ) )
		return expect string( entry.uid )

	// Some builds spam the console on every GetUID call, so throttle retries.
	entry.nextRead = Time() + 2.0
	string uid = GetUID( player )
	if ( uid != "" && uid != "0" )
		entry.uid = uid

	return uid
}

void function Glazer_Reply( string playerName, bool isTeam )
{
	file.lastReplyAt = Time()

	float delay = max( 0.0, GetConVarFloat( "glaze_delay" ) )
	if ( delay > 0.0 )
		wait delay
	else
		WaitFrame()

	string line = Glazer_NextLine()
	if ( line == "" )
		return

	if ( !GetConVarBool( "glaze_reply_team" ) )
		isTeam = false

	string text = GetConVarString( "glaze_prefix" ) + line

	int maxLength = GetConVarInt( "glaze_maxlen" )
	if ( maxLength > 3 && text.len() > maxLength )
		text = Glazer_Trim( text, maxLength )

	file.recentlySent[ text ] <- Time()
	NSSendMessage( text, true, isTeam )

	if ( GetConVarBool( "glaze_debug" ) )
		print( "[Glazer] -> " + playerName + ": " + text )
}

string function Glazer_Trim( string text, int maxLength )
{
	string cut = text.slice( 0, maxLength )
	int lastSpace = -1
	int searchFrom = 0

	while ( true )
	{
		var space = cut.find( " ", searchFrom )
		if ( space == null )
			break

		lastSpace = expect int( space )
		searchFrom = lastSpace + 1
	}

	if ( lastSpace > maxLength / 2 )
		cut = cut.slice( 0, lastSpace )

	return strip( cut ) + "..."
}

string function Glazer_NextLine()
{
	if ( GlazeLines.len() == 0 )
		return ""

	if ( file.bag.len() == 0 )
		Glazer_ResetBag()

	int index = file.bag.pop()
	if ( index < 0 || index >= GlazeLines.len() )
		return ""

	return GlazeLines[ index ]
}

void function Glazer_ResetBag()
{
	file.bag.clear()

	int count = GlazeLines.len()
	for ( int i = 0; i < count; i++ )
		file.bag.append( i )

	for ( int i = count - 1; i > 0; i-- )
	{
		int j = RandomInt( i + 1 )
		int swap = file.bag[ i ]
		file.bag[ i ] = file.bag[ j ]
		file.bag[ j ] = swap
	}
}

void function Glazer_ResetCommand( array<string> args = [] )
{
	Glazer_ResetBag()
	print( "[Glazer] Used-line history cleared, all " + GlazeLines.len() + " lines are available again." )
}

void function Glazer_StatusCommand( array<string> args = [] )
{
	print( "[Glazer] enabled=" + GetConVarBool( "glaze_enabled" ) + " remaining=" + file.bag.len() + " total=" + GlazeLines.len() )
	print( "[Glazer] targets=\"" + GetConVarString( "glaze_targets" ) + "\" uids=\"" + GetConVarString( "glaze_target_uids" ) + "\"" )
}

void function Glazer_TestCommand( array<string> args = [] )
{
	entity player = GetLocalClientPlayer()
	thread Glazer_Reply( IsValid( player ) ? player.GetPlayerName() : "test", false )
}

void function Glazer_WhoCommand( array<string> args = [] )
{
	print( "[Glazer] Players in this match:" )
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		string uid = Glazer_PlayerUID( player )
		print( "[Glazer]   " + player.GetPlayerName() + "  |  uid=" + ( uid == "" ? "unknown" : uid ) )
	}
}

void function Glazer_AddCommand( array<string> args = [] )
{
	if ( args.len() == 0 )
	{
		print( "[Glazer] Usage: glaze_add <username>" )
		return
	}

	string name = strip( args[ 0 ] )
	string current = strip( GetConVarString( "glaze_targets" ) )
	SetConVarString( "glaze_targets", current == "" ? name : current + "," + name )
	print( "[Glazer] Target list: " + GetConVarString( "glaze_targets" ) )
}

void function Glazer_AddUIDCommand( array<string> args = [] )
{
	if ( args.len() == 0 )
	{
		print( "[Glazer] Usage: glaze_adduid <uid>" )
		return
	}

	string uid = strip( args[ 0 ] )
	string current = strip( GetConVarString( "glaze_target_uids" ) )
	SetConVarString( "glaze_target_uids", current == "" ? uid : current + "," + uid )
	print( "[Glazer] UID list: " + GetConVarString( "glaze_target_uids" ) )
}
