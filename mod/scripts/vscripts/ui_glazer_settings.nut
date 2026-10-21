untyped

global function Glazer_Settings

void function Glazer_Settings()
{
	ModSettings_AddModTitle( "paws.swiggy.glazer" )
	ModSettings_AddModCategory( "Glaze" )

	ModSettings_AddEnumSetting( "glaze_enabled", "Glazer enabled", [ "Off", "On" ] )
	ModSettings_AddSetting( "glaze_targets", "Target usernames (comma separated)" )
	ModSettings_AddSetting( "glaze_target_uids", "Target UIDs (comma separated)" )

	ModSettings_AddSliderSetting( "glaze_chance", "Chance to reply per message (%)", 0.0, 100.0, 5.0 )
	ModSettings_AddSliderSetting( "glaze_cooldown", "Minimum seconds between replies", 0.0, 30.0, 0.5 )
	ModSettings_AddSliderSetting( "glaze_delay", "Delay before replying (seconds)", 0.0, 10.0, 0.25 )

	ModSettings_AddSetting( "glaze_prefix", "Prefix before each glaze (optional)" )
	ModSettings_AddSetting( "glaze_maxlen", "Maximum reply length (0 = no limit)" )
	ModSettings_AddEnumSetting( "glaze_reply_team", "Reply channel", [ "Always global", "Same as target" ] )
	ModSettings_AddEnumSetting( "glaze_debug", "Console debug output", [ "Off", "On" ] )
}
