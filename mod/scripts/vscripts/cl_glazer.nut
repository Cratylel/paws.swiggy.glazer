untyped

global function Glazer_Init
global function Glazer_OnChatMessage
global function Glazer_ResetCommand
global function Glazer_StatusCommand
global function Glazer_TestCommand
global function Glazer_WhoCommand
global function Glazer_AddCommand

const float GLAZER_ECHO_WINDOW = 6.0

struct
{
	bool initialized = false
	array<int> bag
	table<string, float> recentlySent
	float lastReplyAt = -1000.0
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

	print( "[Glazer] Loaded with " + GlazeLines.len() + " glaze lines. Set target usernames in Mod Settings." )
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
	array<string> playerNames
	playerNames.append( Glazer_NormalizeName( playerName ) )
	playerNames.append( Glazer_NormalizeName( player.GetPlayerName() ) )
	playerNames.append( Glazer_NormalizeName( player.GetPlayerNameWithClanTag() ) )

	// Chat can provide a clan-tagged display name while settings usually contain
	// the account name. Compare both forms, including a configured tagged name.
	int nameCount = playerNames.len()
	for ( int i = 0; i < nameCount; i++ )
	{
		string untaggedName = Glazer_NormalizeName( Glazer_StripClanTag( playerNames[ i ] ) )
		if ( untaggedName != playerNames[ i ] )
			playerNames.append( untaggedName )
	}

	foreach ( string entry in split( GetConVarString( "glaze_targets" ), "," ) )
	{
		string target = Glazer_NormalizeName( entry )
		if ( target == "" )
			continue

		string untaggedTarget = Glazer_NormalizeName( Glazer_StripClanTag( target ) )
		foreach ( string candidate in playerNames )
		{
			if ( target == candidate || untaggedTarget == candidate )
				return true
		}
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

string function Glazer_NormalizeName( string name )
{
	return strip( name ).tolower()
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

	text = Glazer_SanitizeChatCommand( text )
	if ( text == "" )
		return

	entity localPlayer = GetLocalClientPlayer()
	if ( !IsValid( localPlayer ) )
		return

	file.recentlySent[ text ] <- Time()
	string command = isTeam ? "say_team " : "say "
	localPlayer.ClientCommand( command + text )

	if ( GetConVarBool( "glaze_debug" ) )
		print( "[Glazer] -> " + playerName + ": " + text )
}

string function Glazer_SanitizeChatCommand( string text )
{
	string safeText = ""
	for ( int i = 0; i < text.len(); i++ )
	{
		string character = text.slice( i, i + 1 )
		if ( character == "\"" || character == ";" || character == "%" || character == "\n" || character == "\r" )
			continue

		safeText += character
	}

	return strip( safeText )
}

string function Glazer_Trim( string text, int maxLength )
{
	int contentLength = maxLength - 3
	string cut = text.slice( 0, contentLength )
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

	if ( lastSpace > contentLength / 2 )
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
	print( "[Glazer] targets=\"" + GetConVarString( "glaze_targets" ) + "\"" )
}

void function Glazer_TestCommand( array<string> args = [] )
{
	entity player = GetLocalClientPlayer()
	thread Glazer_Reply( IsValid( player ) ? player.GetPlayerName() : "test", false )
}

void function Glazer_WhoCommand( array<string> args = [] )
{
	print( "[Glazer] Players in this match (remote UIDs are not available to client scripts):" )
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		print( "[Glazer]   " + player.GetPlayerNameWithClanTag() + "  |  account=" + player.GetPlayerName() )
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
