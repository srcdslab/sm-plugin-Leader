#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>
#include <sourcecomms>
#include <leader>
#include <clientprefs>
#include <multicolors>

#define PLUGIN_VERSION "3.5"
#define MAXLEADERS 64
#pragma newdecls required

int currentSprite[MAXPLAYERS + 1] = { -1, ... };
int spriteEntities[MAXPLAYERS + 1];
int markerEntities[MAXPLAYERS + 1];
int voteCount[MAXPLAYERS + 1];
int votedFor[MAXPLAYERS + 1];
int g_iClientNextVote[MAXPLAYERS + 1] = { -1, ... };
int g_iClientNextLeader[MAXPLAYERS + 1] = { 0, ... };
int leaders_max = -1;

int g_iClientColor[MAXPLAYERS + 1][4];
int g_iClientColorNum[MAXPLAYERS + 1];

int g_ColorWhite[4] =  {255, 255, 255, 255};
int g_ColorRed[4] =  {255, 0, 0, 255};
int g_ColorLime[4] =  {0, 255, 0, 255};
int g_ColorBlue[4] =  {0, 0, 255, 255};
int g_ColorYellow[4] =  {255, 255, 0, 255};
int g_ColorCyan[4] =  {0, 255, 255, 255};
int g_ColorGold[4] =  {255, 215, 0, 255};

int g_iPropDynamic[MAXPLAYERS + 1] = { -1, ... };
int g_iNeon[MAXPLAYERS + 1] = { -1, ... };
int g_iClientButton[MAXPLAYERS + 1] = { 0, ... };

float g_fNextSpawn[MAXPLAYERS + 1] = { 0.0, ... };

bool allowVoting = false;
bool markerActive[MAXPLAYERS + 1] = { false, ... };
bool beaconActive[MAXPLAYERS + 1] = { false, ... };
bool trailActive[MAXPLAYERS + 1] = { false, ... };
bool g_bIsClientALeader[MAXPLAYERS + 1] = { false, ... };
bool g_bHasLightInMarker[MAXPLAYERS + 1] = { false, ... };
bool g_bIsMarkerEnabled[MAXPLAYERS + 1] = { false, ... };

ConVar g_cVDefendVTF = null;
ConVar g_cVDefendVMT = null;
ConVar g_cVFollowVTF = null;
ConVar g_cVFollowVMT = null;
ConVar g_cTrailVTF = null;
ConVar g_cTrailVMT = null;
ConVar g_cTrailPosition = null;
ConVar g_cVCooldown = null;
ConVar g_cVMaxLeaders = null;
ConVar g_cVAllowVoting = null;
ConVar g_cVMarkerTimer = null;
ConVar g_cVLeaderCooldown = null;
ConVar g_cvExtraLogs = null;

char DefendVMT[PLATFORM_MAX_PATH];
char DefendVTF[PLATFORM_MAX_PATH];
char FollowVMT[PLATFORM_MAX_PATH];
char FollowVTF[PLATFORM_MAX_PATH];
char TrailVMT[PLATFORM_MAX_PATH];
char TrailVTF[PLATFORM_MAX_PATH];
char leaderTag[64];
char g_sDataFile[PLATFORM_MAX_PATH];
char g_sLeaderAuth[MAXLEADERS][64];

int g_BeamSprite = -1;
int g_HaloSprite = -1;
int greyColor[4] = {128, 128, 128, 255};
int g_BeaconSerial[MAXPLAYERS+1] = { 0, ... };
int g_Serial_Gen = 0;
int g_TrailModel[MAXPLAYERS+1] = { 0, ... };

Handle g_hClientLightEnabled = INVALID_HANDLE;
Handle g_hClientMarkerEnabled = INVALID_HANDLE;
Handle g_hClientColor = INVALID_HANDLE;
Handle g_hClientButton = INVALID_HANDLE;
Handle g_hMarkerTimer[MAXPLAYERS + 1] = { null, ... };

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name = "Leader",
	author = "AntiTeal + Neon + inGame + .Rushaway + Dolly",
	description = "Allows for a human to be a leader, and give them special functions with it.",
	version = PLUGIN_VERSION,
	url = "https://antiteal.com"
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	BuildPath(Path_SM, g_sDataFile, sizeof(g_sDataFile), "configs/leader/leaders.ini");

	g_hClientLightEnabled = RegClientCookie("Lights_Enable", "enables/disables light of marker", CookieAccess_Public);
	g_hClientMarkerEnabled = RegClientCookie("Marker_Enable", "enables/disables marker", CookieAccess_Public);
	g_hClientColor = RegClientCookie("client_color", "client color", CookieAccess_Public);
	g_hClientButton = RegClientCookie("client_button", "client button", CookieAccess_Public);
	
	CreateConVar("sm_leader_version", PLUGIN_VERSION, "Leader Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
	//AddCommandListener(HookPlayerChat, "say");

	RegConsoleCmd("sm_leader", Leader);
	RegConsoleCmd("sm_currentleaders", CurrentLeaders);
	RegConsoleCmd("sm_wholeader", CurrentLeaders);
	RegConsoleCmd("sm_leaders", Leaders);
	RegConsoleCmd("sm_voteleader", VoteLeader);
	RegConsoleCmd("sm_marker", Command_Marker);
	RegAdminCmd("sm_removeleader", RemoveTheLeader, ADMFLAG_GENERIC);
	RegAdminCmd("sm_replaceleader", ReplaceLeader, ADMFLAG_GENERIC);
	RegAdminCmd("sm_reloadleaders", ReloadLeaders, ADMFLAG_GENERIC);

	g_cVDefendVMT = CreateConVar("sm_leader_defend_vmt", "materials/nide/leader/defend.vmt", "The defend here .vmt file");
	g_cVDefendVTF = CreateConVar("sm_leader_defend_vtf", "materials/nide/leader/defend.vtf", "The defend here .vtf file");
	g_cVFollowVMT = CreateConVar("sm_leader_follow_vmt", "materials/nide/leader/follow.vmt", "The follow me .vmt file");
	g_cVFollowVTF = CreateConVar("sm_leader_follow_vtf", "materials/nide/leader/follow.vtf", "The follow me .vtf file");
	g_cTrailVMT = CreateConVar("sm_leader_trail_vmt", "materials/nide/leader/trail.vmt", "The trail .vmt file");
	g_cTrailVTF = CreateConVar("sm_leader_trail_vtf", "materials/nide/leader/trail.vtf", "The trail .vtf file");
	g_cTrailPosition = CreateConVar("sm_leader_trail_position", "0.0 10.0 10.0", "The trail position (X Y Z)");
	g_cVAllowVoting = CreateConVar("sm_leader_allow_votes", "1", "Determines whether players can vote for leaders.");
	g_cVCooldown = CreateConVar("sm_leader_votecooldown", "20", "The cooldown of sm_voteleader command");
	g_cVMaxLeaders = CreateConVar("sm_leader_maxleaders", "1", "The max leaders amount");
	g_cVMarkerTimer = CreateConVar("sm_leader_markertime", "20.0", "The Timer of Marker for it to be killed");
	g_cVLeaderCooldown = CreateConVar("sm_leader_leadercooldown", "2", "The cooldown of sm_leader command");
	g_cvExtraLogs = CreateConVar("sm_leader_extraslog", "0", "ExtraLogs [0 = Disabled | 1 = Enabled]", FCVAR_REPLICATED);

	g_cVDefendVMT.AddChangeHook(ConVarChange);
	g_cVDefendVTF.AddChangeHook(ConVarChange);
	g_cVFollowVMT.AddChangeHook(ConVarChange);
	g_cVFollowVTF.AddChangeHook(ConVarChange);
	g_cTrailVMT.AddChangeHook(ConVarChange);
	g_cTrailVTF.AddChangeHook(ConVarChange);
	g_cVAllowVoting.AddChangeHook(ConVarChange);
	g_cVMaxLeaders.AddChangeHook(ConVarChange);

	AutoExecConfig(true);

	g_cVDefendVTF.GetString(DefendVTF, sizeof(DefendVTF));
	g_cVDefendVMT.GetString(DefendVMT, sizeof(DefendVMT));
	g_cVFollowVTF.GetString(FollowVTF, sizeof(FollowVTF));
	g_cVFollowVMT.GetString(FollowVMT, sizeof(FollowVMT));
	g_cTrailVTF.GetString(TrailVTF, sizeof(TrailVTF));
	g_cTrailVMT.GetString(TrailVMT, sizeof(TrailVMT));

	allowVoting = g_cVAllowVoting.BoolValue;

	AddCommandListener(Radio, "compliment");
	AddCommandListener(Radio, "coverme");
	AddCommandListener(Radio, "cheer");
	AddCommandListener(Radio, "takepoint");
	AddCommandListener(Radio, "holdpos");
	AddCommandListener(Radio, "regroup");
	AddCommandListener(Radio, "followme");
	AddCommandListener(Radio, "takingfire");
	AddCommandListener(Radio, "thanks");
	AddCommandListener(Radio, "go");
	AddCommandListener(Radio, "fallback");
	AddCommandListener(Radio, "sticktog");
	AddCommandListener(Radio, "getinpos");
	AddCommandListener(Radio, "stormfront");
	AddCommandListener(Radio, "report");
	AddCommandListener(Radio, "roger");
	AddCommandListener(Radio, "enemyspot");
	AddCommandListener(Radio, "needbackup");
	AddCommandListener(Radio, "sectorclear");
	AddCommandListener(Radio, "inposition");
	AddCommandListener(Radio, "reportingin");
	AddCommandListener(Radio, "getout");
	AddCommandListener(Radio, "negative");
	AddCommandListener(Radio, "enemydown");

	AddMultiTargetFilter("@leaders", Filter_Leaders, "Possible Leaders", false);
	AddMultiTargetFilter("@!leaders", Filter_NotLeaders, "Everyone but Possible Leaders", false);
	AddMultiTargetFilter("@leader", Filter_Leader, "Current Leader", false);
	AddMultiTargetFilter("@!leader", Filter_NotLeader, "Every one but the Current Leader", false);
	
	AddTempEntHook("Player Decal", HookDecal);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(AreClientCookiesCached(i))
				OnClientCookiesCached(i);
		}
	}

}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginEnd()
{
	RemoveMultiTargetFilter("@leaders", Filter_Leaders);
	RemoveMultiTargetFilter("@!leaders", Filter_NotLeaders);
	RemoveMultiTargetFilter("@leader", Filter_Leader);
	RemoveMultiTargetFilter("@!leader", Filter_NotLeader);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void ConVarChange(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	g_cVDefendVTF.GetString(DefendVTF, sizeof(DefendVTF));
	g_cVDefendVMT.GetString(DefendVMT, sizeof(DefendVMT));
	g_cVFollowVTF.GetString(FollowVTF, sizeof(FollowVTF));
	g_cVFollowVMT.GetString(FollowVMT, sizeof(FollowVMT));
	g_cTrailVTF.GetString(TrailVTF, sizeof(TrailVTF));
	g_cTrailVMT.GetString(TrailVMT, sizeof(TrailVMT));

	AddFileToDownloadsTable(DefendVTF);
	AddFileToDownloadsTable(DefendVMT);
	AddFileToDownloadsTable(FollowVTF);
	AddFileToDownloadsTable(FollowVMT);
	AddFileToDownloadsTable(TrailVTF);
	AddFileToDownloadsTable(TrailVMT);

	PrecacheGeneric(DefendVTF, true);
	PrecacheGeneric(DefendVMT, true);
	PrecacheGeneric(FollowVTF, true);
	PrecacheGeneric(FollowVMT, true);
	PrecacheGeneric(TrailVTF, true);
	PrecacheGeneric(TrailVMT, true);
	
	allowVoting = g_cVAllowVoting.BoolValue;
	
	if(CVar == g_cVMaxLeaders)
		leaders_max = StringToInt(newVal);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnMapStart()
{
	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if (gameConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	char buffer[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_BeamSprite = PrecacheModel(buffer);
	}
	if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_HaloSprite = PrecacheModel(buffer);
	}

	UpdateLeaders();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnConfigsExecuted()
{
	AddFileToDownloadsTable(DefendVTF);
	AddFileToDownloadsTable(DefendVMT);
	AddFileToDownloadsTable(FollowVTF);
	AddFileToDownloadsTable(FollowVMT);
	AddFileToDownloadsTable(TrailVTF);
	AddFileToDownloadsTable(TrailVMT);

	PrecacheGeneric(DefendVTF, true);
	PrecacheGeneric(DefendVMT, true);
	PrecacheGeneric(FollowVTF, true);
	PrecacheGeneric(FollowVMT, true);
	PrecacheGeneric(TrailVTF, true);
	PrecacheGeneric(TrailVMT, true);

	PrecacheModel("models/oylsister/misc/signal_marker.mdl", true);
	PrecacheModel("models/oylsister/misc/signal_marker.dx80.vtx", true);
	PrecacheModel("models/oylsister/misc/signal_marker.dx90.vtx", true);
	PrecacheModel("models/oylsister/misc/signal_marker.sw.vtx", true);
	PrecacheModel("models/oylsister/misc/signal_marker.vvd", true);

	PrecacheModel("materials/oylsister/signal_marker/material0.vtf", true);
	PrecacheModel("materials/oylsister/signal_marker/material0.vmt", true);

	AddFileToDownloadsTable("models/oylsister/misc/signal_marker.mdl");
	AddFileToDownloadsTable("models/oylsister/misc/signal_marker.dx80.vtx");
	AddFileToDownloadsTable("models/oylsister/misc/signal_marker.dx90.vtx");
	AddFileToDownloadsTable("models/oylsister/misc/signal_marker.sw.vtx");
	AddFileToDownloadsTable("models/oylsister/misc/signal_marker.vvd");

	AddFileToDownloadsTable("materials/oylsister/signal_marker/material0.vtf");
	AddFileToDownloadsTable("materials/oylsister/signal_marker/material0.vmt");

	leaders_max = g_cVMaxLeaders.IntValue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------

public void OnClientPutInServer(int client)
{
	g_fNextSpawn[client] = 0.0;
	g_bIsClientALeader[client] = false;
	g_iClientNextVote[client] = 0;
}

public void OnClientCookiesCached(int client)
{
	char sBool[6], sBool2[6], sColor[128], sButton[32];

	GetClientCookie(client, g_hClientLightEnabled, sBool, sizeof(sBool));
	GetClientCookie(client, g_hClientMarkerEnabled, sBool2, sizeof(sBool2));
	GetClientCookie(client, g_hClientColor, sColor, sizeof(sColor));
	GetClientCookie(client, g_hClientButton, sButton, sizeof(sButton));

	g_bHasLightInMarker[client] = true;
	g_bIsMarkerEnabled[client] = true;

	if(!StrEqual(sBool, ""))
	{
		g_bHasLightInMarker[client] = view_as<bool>(StringToInt(sBool));
	}

	if(!StrEqual(sBool2, ""))
	{
		g_bIsMarkerEnabled[client] = view_as<bool>(StringToInt(sBool2));
	}

	if(StrEqual(sColor, "0"))
	{
		g_iClientColorNum[client] = 0;
		g_iClientColor[client] = g_ColorWhite;
	}
	else if(StrEqual(sColor, "1"))
	{
		g_iClientColorNum[client] = 1;
		g_iClientColor[client] = g_ColorRed;
	}
	else if(StrEqual(sColor, "2"))
	{
		g_iClientColorNum[client] = 2;
		g_iClientColor[client] = g_ColorLime;
	}
	else if(StrEqual(sColor, "3"))
	{
		g_iClientColorNum[client] = 3;
		g_iClientColor[client] = g_ColorBlue;
	}
	else if(StrEqual(sColor, "4"))
	{
		g_iClientColorNum[client] = 4;
		g_iClientColor[client] = g_ColorYellow;
	}
	else if(StrEqual(sColor, "5"))
	{
		g_iClientColorNum[client] = 5;
		g_iClientColor[client] = g_ColorCyan;
	}
	else if(StrEqual(sColor, "6"))
	{
		g_iClientColorNum[client] = 6;
		g_iClientColor[client] = g_ColorGold;
	}
	else if(StrEqual(sColor, "7"))
	{
		g_iClientColorNum[client] = 7;
	}
	else if(StrEqual(sColor, ""))
	{
		g_iClientColorNum[client] = 0;
		g_iClientColor[client] = g_ColorWhite;
	}

	if(!StrEqual(sButton, ""))
	{
		g_iClientButton[client] = StringToInt(sButton);
	}
	else
	{
		g_iClientButton[client] = 0;
	}
}
			
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void CreateBeacon(int client)
{
	g_BeaconSerial[client] = ++g_Serial_Gen;
	CreateTimer(1.0, Timer_Beacon, client | (g_Serial_Gen << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void KillBeacon(int client)
{
	g_BeaconSerial[client] = 0;

	if(IsClientInGame(client))
		SetEntityRenderColor(client, 255, 255, 255, 255);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void KillAllBeacons()
{
	for(int i = 1; i <= MaxClients; i++)
		KillBeacon(i);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void PerformBeacon(int client)
{
	if(g_BeaconSerial[client] == 0)
	{
		CreateBeacon(client);

		if (g_cvExtraLogs.IntValue >= 1)
			LogAction(client, client, "[Leader] \"%L\" set a beacon on himself", client);
	}
	else
	{
		KillBeacon(client);

		if (g_cvExtraLogs.IntValue >= 1)
			LogAction(client, client, "[Leader] \"%L\" removed a beacon on himself", client);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void PerformTrail(int client)
{
	if(g_TrailModel[client] == 0)
	{
		CreateTrail(client);

		if (g_cvExtraLogs.IntValue >= 1)
			LogAction(client, client, "[Leader] \"%L\" set a trail on himself", client);
	}
	else
	{
		KillTrail(client);

		if (g_cvExtraLogs.IntValue >= 1)
			LogAction(client, client, "[Leader] \"%L\" removed a trail on himself", client);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Timer_Beacon(Handle timer, any value)
{
	int client = value & 0x7f;
	int serial = value >> 7;

	if(!IsClientInGame(client) || !IsPlayerAlive(client) || g_BeaconSerial[client] != serial)
	{
		KillBeacon(client);
		return Plugin_Stop;
	}

	float vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;

	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, greyColor, 10, 0);
	TE_SendToAll();

	int rainbowColor[4];
	float i = GetGameTime();
	float Frequency = 2.5;
	rainbowColor[0] = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	rainbowColor[1] = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	rainbowColor[2] = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);
	rainbowColor[3] = 255;

	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, rainbowColor, 10, 0);

	TE_SendToAll();

	GetClientEyePosition(client, vec);

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock int AttachSprite(int client, char[] sprite) //https://forums.alliedmods.net/showpost.php?p=1880207&postcount=5
{
	if(!IsPlayerAlive(client))
	{
		return -1;
	}

	char iTarget[16], sTargetname[64];
	GetEntPropString(client, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	Format(iTarget, sizeof(iTarget), "Client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	float Origin[3];
	GetClientEyePosition(client, Origin);
	Origin[2] += 45.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent, 0);

	DispatchKeyValue(client, "targetname", sTargetname);

	return Ent;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void RemoveSprite(int client)
{
	if(spriteEntities[client] != -1 && IsValidEdict(spriteEntities[client]))
	{
		char m_szClassname[64];
		GetEdictClassname(spriteEntities[client], m_szClassname, sizeof(m_szClassname));
		if(strcmp("env_sprite", m_szClassname)==0)
		AcceptEntityInput(spriteEntities[client], "Kill");
	}

	spriteEntities[client] = -1;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void RemoveMarker(int client)
{
	if(markerEntities[client] != -1 && IsValidEdict(markerEntities[client]))
	{
		char m_szClassname[64];
		GetEdictClassname(markerEntities[client], m_szClassname, sizeof(m_szClassname));
		if(strcmp("env_sprite", m_szClassname)==0)
		AcceptEntityInput(markerEntities[client], "Kill");
	}

	markerEntities[client] = -1;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void SetLeader(int client, int target)
{
	if(IsValidClient(client) && target == -1)
	{
		g_bIsClientALeader[client] = true;

		CS_GetClientClanTag(client, leaderTag, sizeof(leaderTag));
		//CS_SetClientClanTag(client, "[Leader]");

		//leaderMVP = CS_GetMVPCount(client);
		//CS_SetMVPCount(client, 99);

		//leaderScore = CS_GetClientContributionScore(client);
		//CS_SetClientContributionScore(client, 9999);

		currentSprite[client] = -1;
	}
	else if(IsValidClient(client) && IsValidClient(target))
	{
		RemoveLeader(target);
		g_bIsClientALeader[client] = true;
		currentSprite[client] = -1;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void RemoveLeader(int client)
{
	//CS_SetClientClanTag(client, leaderTag);
	//CS_SetMVPCount(client, leaderMVP);
	//CS_SetClientContributionScore(client, leaderScore);

	RemoveSprite(client);
	RemoveMarker(client);

	if(beaconActive[client])
		KillBeacon(client);

	if(trailActive[client])
		KillTrail(client);

	currentSprite[client] = -1;
	g_bIsClientALeader[client] = false;
	markerActive[client] = false;
	beaconActive[client] = false;
	trailActive[client] = false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock int SpawnMarker(int client, char[] sprite)
{
	if(!IsPlayerAlive(client))
		return -1;

	float Origin[3];
	GetClientEyePosition(client, Origin);
	Origin[2] += 25.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);

	return Ent;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void CreateTrail(int client)
{
	if(!client)
		return;

	KillTrail(client);

	if(!IsPlayerAlive(client) || !(1 < GetClientTeam(client) < 4))
		return;

	g_TrailModel[client] = CreateEntityByName("env_spritetrail");
	if(g_TrailModel[client] != 0) 
	{
		char buffer[PLATFORM_MAX_PATH];
		//float dest_vector[3];
		float origin[3];

		DispatchKeyValueFloat(g_TrailModel[client], "lifetime", 2.0);
		DispatchKeyValue(g_TrailModel[client], "startwidth", "25");
		DispatchKeyValue(g_TrailModel[client], "endwidth", "15");

		GetConVarString(g_cTrailVMT, buffer, sizeof(buffer));
		DispatchKeyValue(g_TrailModel[client], "spritename", buffer);
		DispatchKeyValue(g_TrailModel[client], "renderamt", "255");
		DispatchKeyValue(g_TrailModel[client], "rendercolor", "255 255 255");

		IntToString(1, buffer, sizeof(buffer));
		DispatchKeyValue(g_TrailModel[client], "rendermode", buffer);

		// We give the name for our entities here
		DispatchKeyValue(g_TrailModel[client], "targetname", "trail");

		DispatchSpawn(g_TrailModel[client]);

		char sVectors[64];
		GetConVarString(g_cTrailPosition, sVectors, sizeof(sVectors));

		char angle[64][3];
		float angles[3]; 

		ExplodeString(sVectors, " ", angle, 3, sizeof(angle), false);
		angles[0] = StringToFloat(angle[0]);
		angles[1] = StringToFloat(angle[1]);
		angles[2] = StringToFloat(angle[2]);

		GetClientAbsOrigin(client, origin);
		origin[0] += angles[0];
		origin[1] += angles[1];
		origin[2] += angles[2];

		//GetVectorAngles(dest_vector, angles);

		/*float or[3];
		float ang[3];
		float fForward[3];
		float fRight[3];
		float fUp[3];

		GetClientAbsOrigin(client, or);
		GetClientAbsAngles(client, ang);

		GetAngleVectors(ang, fForward, fRight, fUp);

		or[0] += fRight[0]*dest_vector[0] + fForward[0]*dest_vector[1] + fUp[0]*dest_vector[2];
		or[1] += fRight[1]*dest_vector[0] + fForward[1]*dest_vector[1] + fUp[1]*dest_vector[2];
		or[2] += fRight[2]*dest_vector[0] + fForward[2]*dest_vector[1] + fUp[2]*dest_vector[2];*/

		TeleportEntity(g_TrailModel[client], origin, NULL_VECTOR, NULL_VECTOR);

		SetVariantString("!activator");
		AcceptEntityInput(g_TrailModel[client], "SetParent", client); 
		SetEntPropFloat(g_TrailModel[client], Prop_Send, "m_flTextureRes", 0.05);
		SetEntPropEnt(g_TrailModel[client], Prop_Send, "m_hOwnerEntity", client);
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void KillTrail(int client)
{
	if(g_TrailModel[client] > MaxClients && IsValidEdict(g_TrailModel[client]))
		AcceptEntityInput(g_TrailModel[client], "kill");
	
	g_TrailModel[client] = 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action CurrentLeaders(int client, int args)
{
	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && g_bIsClientALeader[i])
		{
			GetClientName(i, aBuf2, sizeof(aBuf2));
			StrCat(aBuf, sizeof(aBuf), aBuf2);
			StrCat(aBuf, sizeof(aBuf), ", ");
		}
	}

	if(strlen(aBuf))
	{
		aBuf[strlen(aBuf) - 2] = 0;
		CReplyToCommand(client, "{green}[SM] {default}The Current Leaders : {olive}%s", aBuf);
	}
	else
		CReplyToCommand(client, "{green}[SM] {default}The Current Leaders : {olive}None");

	return Plugin_Handled;
}

stock int GetCurrentLeadersCount()
{
	int count = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && g_bIsClientALeader[i])
			count++;
	}

	return count;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action RemoveTheLeader(int client, int args)
{
	if(args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: {olive}sm_removeleader <leader>{default}.");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	int target = FindTarget(client, arg, false, false);
	if(target == -1)
		return Plugin_Handled;

	if(g_bIsClientALeader[target])
	{
		CPrintToChatAll("{green}[SM] {default}Leader {olive}%N has been removed!", target);
		RemoveLeader(target);
		LogAction(client, target, "[Leader] \"%L\" has removed \"%L\" from being a leader.", client, target);
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "{green}[SM] {default}The specified target is not a leader!");
		return Plugin_Handled;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Leader(int client, int args)
{	
	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	if(g_iClientNextLeader[client] < GetTime())
	{			
		if(args >= 1)
		{	
			if(CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false))
			{
				int target = FindTarget(client, arg1, false, false);
				if (target == -1)
				{
					return Plugin_Handled;
				}

				if(g_bIsClientALeader[target])
				{
					LeaderMenu(target);
					return Plugin_Handled;
				}
				else
				{
					if(GetCurrentLeadersCount() != leaders_max)
					{
						if(IsPlayerAlive(target) && ZR_IsClientHuman(target))
						// Admin Target a player
						{
							SetLeader(target, -1);
							CPrintToChatAll("{green}[SM] {olive}%N {default}is now a new leader !", target);
							CPrintToChat(target, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
							LeaderMenu(target);
							LogAction(client, target, "[Leader] \"%L\" is now a new leader ! (Designed by \"%L\")", target, client);
							return Plugin_Handled;
						}
						else
						{
							CReplyToCommand(client, "{green}[SM] {default}The target has to be an alive Human !");
							return Plugin_Handled;
						}
					}
					else if(GetCurrentLeadersCount() == leaders_max && leaders_max != 1)
					{
						CReplyToCommand(client, "{green}[SM] {default}Oops, there are %d leaders which is the max number of available leaders on this map.", leaders_max);
						CReplyToCommand(client, "{green}[SM] {default}Type {olive}sm_replaceleader <a current leader> <target>{default} to replace a current leader with a target");
						return Plugin_Handled;
					}
					else if(GetCurrentLeadersCount() == leaders_max && leaders_max == 1)
					{
						int leader = -1;
						for (int i = 1; i <= MaxClients; i++)
						{
							if(IsValidClient(i) && g_bIsClientALeader[i])			
								leader = i;
						}
						
						if(target != client)
						{
							if(IsPlayerAlive(target) && ZR_IsClientHuman(target))
							{
								SetLeader(target, leader);
								CPrintToChatAll("{green}[SM] {olive}%N {default}is the new leader ! as a replacement of %N", target, leader);
								CReplyToCommand(target, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
								LeaderMenu(target);
								LogAction(client, target, "[Leader] \"%L\" has become a new Leader as a replacement of \"%L\" by Admin \"%L\".", target, leader, client);
								return Plugin_Handled;
							}
							else
							{
								CReplyToCommand(client, "{green}[SM] {default}The target has to be an alive Human !");
								return Plugin_Handled;
							}
						}
					}
				}
			}
			else if(IsPossibleLeader(client))
			{
				int target = FindTarget(client, arg1, false, false);
				if (target == -1)
				{
					return Plugin_Handled;
				}
				
				if(GetCurrentLeadersCount() == leaders_max && leaders_max > 1)
				{
					if(!g_bIsClientALeader[target])
					{
						CReplyToCommand(client, "[SM] {default}The specified target is not a leader.");
						return Plugin_Handled;
					}
					else
					{
						if(target != client)
						{
							if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
							// Access via leader.ini
							{
								SetLeader(client, target);
								CPrintToChatAll("{green}[SM] {olive}%N {default}is now a new leader ! as a replacement of {olive}%N", client, target);
								CReplyToCommand(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
								LeaderMenu(client);
								LogAction(client, target, "[Leader] \"%L\" has become a new Leader as a replacement of \"%L\" by PossibleLeader \"%L\".", client, target, client);
								return Plugin_Handled;
							}
							else
							{
								CReplyToCommand(client, "{green}[SM] {default}You need to be an alive Human !");
								return Plugin_Handled;
							}
						}
					}
				}
				else if(GetCurrentLeadersCount() == leaders_max && leaders_max == 1)
				{
					int leader = -1;
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsValidClient(i) && g_bIsClientALeader[i])			
							leader = i;
					}
					
					if(leader != client)
					{
						if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
						{
							SetLeader(client, leader);
							CPrintToChatAll("{green}[SM] {olive}%N {default}is the new leader ! as a replacement of {olive}%N", client, leader);
							CReplyToCommand(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
							LeaderMenu(client);
							LogAction(client, leader, "[Leader] \"%L\" has become a new Leader as a replacement of \"%L\" by PossibleLeader \"%L\".", client, leader, client);
							return Plugin_Handled;
						}
						else
						{
							CReplyToCommand(client, "{green}[SM] {default}You need to be an alive Human !");
							return Plugin_Handled;
						}
					}
				}
				else if(GetCurrentLeadersCount() != leaders_max)
				{
					if(!g_bIsClientALeader[target])
					{
						CReplyToCommand(client, "[SM] {default}The specified target is not a leader.");
						return Plugin_Handled;
					}
					
					if(!g_bIsClientALeader[client])
					{
						if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
						{
							SetLeader(client, -1);
							CPrintToChatAll("{green}[SM] {olive}%N {default}is now a new Leader !", client);
							CReplyToCommand(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
							LeaderMenu(client);
							LogAction(client, -1, "[Leader] \"%L\" is now a new leader ! (Access: leader.ini)", client);
							return Plugin_Handled;
						}
						else
						{
							CReplyToCommand(client, "{green}[SM] {default}You need to be an alive Human !");
							return Plugin_Handled;
						}
					}
				}
			}
		}		
		else if(args < 1)
		{
			if(CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false))
			{
				if(g_bIsClientALeader[client])
				{
					LeaderMenu(client);
					return Plugin_Handled;
				}
				else
				{
					if(GetCurrentLeadersCount() != leaders_max)
					{
						if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
						{
							SetLeader(client, -1);
							CPrintToChatAll("{green}[SM] {olive}%N {default}is now a new leader !", client);
							CReplyToCommand(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
							LeaderMenu(client);
							LogAction(client, -1, "[Leader] \"%L\" is now a  new leader ! (Access: admin)", client);
							return Plugin_Handled;
						}
						else
						{
							CReplyToCommand(client, "{green}[SM] {default}You have to be an alive Human !");
							return Plugin_Handled;
						}
					}
					else if(GetCurrentLeadersCount() == leaders_max && leaders_max != 1)
					{
						CReplyToCommand(client, "{green}[SM] {default}Oops, there are %d leaders which is the max number of available leaders on this map.", leaders_max);
						CReplyToCommand(client, "{green}[SM] {default}Type {olive}sm_replaceleader <a current leader> <target>{default} to replace a current leader with a target.");
						return Plugin_Handled;
					}
					else if(GetCurrentLeadersCount() == leaders_max && leaders_max == 1)
					{
						int leader = -1;
						for (int i = 1; i <= MaxClients; i++)
						{
							if(IsValidClient(i) && g_bIsClientALeader[i])			
								leader = i;
						}
						
						if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
						{
							SetLeader(client, leader);
							CPrintToChatAll("{green}[SM] {olive}%N {default}is the new leader ! as a replacement of {olive}%N", client, leader);
							CReplyToCommand(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
							LeaderMenu(client);
							LogAction(client, leader, "[Leader] \"%L\" has become a new Leader as a replacement of \"%L\" by Admin \"%L\".", client, leader, client);
							return Plugin_Handled;
						}
						else
						{
							CReplyToCommand(client, "{green}[SM] {default}You have to be an alive Human !");
							return Plugin_Handled;
						}
					}
				}
			}
			else if(IsPossibleLeader(client))
			{
				if(g_bIsClientALeader[client])
				{
					LeaderMenu(client);
					return Plugin_Handled;
				}
				else
				{
					if(GetCurrentLeadersCount() != leaders_max)
					{
						if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
						{
							SetLeader(client, -1);
							CPrintToChatAll("{green}[SM] {olive}%N {default}is now a new Leader !", client);
							CReplyToCommand(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
							LeaderMenu(client);
							LogAction(client, -1, "[Leader] \"%L\" is now a new leader ! (Access: leader.ini)", client);
							return Plugin_Handled;
						}
						else
						{
							CReplyToCommand(client, "{green}[SM] {default}You need to be an alive Human !");
							return Plugin_Handled;
						}
					}
					else if(GetCurrentLeadersCount() == leaders_max && leaders_max == 1)
					{
						int leader = -1;
						for (int i = 1; i <= MaxClients; i++)
						{
							if(IsValidClient(i) && g_bIsClientALeader[i])			
								leader = i;
						}
						
						if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
						{
							SetLeader(client, leader);
							CPrintToChatAll("{green}[SM] {olive}%N {default}is the new leader ! as a replacement of {olive}%N", client, leader);
							CReplyToCommand(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
							LeaderMenu(client);
							LogAction(client, leader, "[Leader] \"%L\" has become a new Leader as a replacement of \"%L\" by PossibleLeader \"%L\".", client, leader, client);
							return Plugin_Handled;
						}
						else
						{
							CReplyToCommand(client, "{green}[SM] {default}You have to be an alive Human !");
							return Plugin_Handled;
						}
					}
					else if(GetCurrentLeadersCount() == leaders_max && leaders_max != 1)
					{
						CReplyToCommand(client, "{green}[SM] {default}There are %d leaders.", GetCurrentLeadersCount());
						CReplyToCommand(client, "{green}[SM] {default}Usage: {olive}sm_leader <A current leader>{default}.");
						return Plugin_Handled;
					}
				}
			}
		}

		g_iClientNextLeader[client] = GetTime() + g_cVLeaderCooldown.IntValue;
	}

	if(g_bIsClientALeader[client])
	{
		LeaderMenu(client);
		return Plugin_Handled;
	}
	//If dont have Admin access and isnt in leader.ini
	CReplyToCommand(client, "{green}[SM] {default}You need to {red}request Leader access !");
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action ReplaceLeader(int client, int args)
{
	char arg1[65], arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	if(args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: {olive}sm_replaceleader <leader> <target>");
		return Plugin_Handled;
	}
	else if(args < 2)
	{
		int leader = FindTarget(client, arg1, false, false);
		if(leader == -1)
		{
			return Plugin_Handled;
		}

		if(g_bIsClientALeader[leader] && leader != client)
		{
			if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
			{
				SetLeader(client, leader);
				CPrintToChatAll("{green}[SM] {olive}%N {default}has been A new leader as a replacement of {olive}%N{default}.", client, leader);
				CReplyToCommand(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
				LeaderMenu(client);
				LogAction(client, leader, "[Leader] \"%L\" has become a new Leader as a replacement of \"%L\" by Admin \"%L\".", client, leader, client);
				return Plugin_Handled;
			}
			else
			{
				CReplyToCommand(client, "{green}[SM] {default}You need to be an alive Human !");
				return Plugin_Handled;
			}
		}
		else
		{
			CReplyToCommand(client, "{green}[SM] {default}The specified target is not a leader.");
			return Plugin_Handled;
		}
	}
	else if(args >= 2)
	{
		int leader = FindTarget(client, arg1, false, false);
		int target = FindTarget(client, arg2, false, false);
		
		if(leader == -1 || target == -1)
		{
			return Plugin_Handled;
		}

		if(g_bIsClientALeader[leader] && leader)
		{
			if(!g_bIsClientALeader[target])
			{
				if(IsPlayerAlive(target) && ZR_IsClientHuman(target))
				{
					SetLeader(target, leader);
					CPrintToChatAll("{green}[SM] {olive}%N {default}has been A new leader as a replacement of {olive}%N{default}.", target, leader);
					CPrintToChat(target, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
					LeaderMenu(target);
					LogAction(client, target, "[Leader] \"%L\" has become a new Leader as a replacement of \"%L\" by Admin \"%L\".", target, leader, client);
					return Plugin_Handled;
				}
				else
				{
					CReplyToCommand(client, "{green}[SM] {default}The target has to be an alive Human !");
					return Plugin_Handled;
				}
			}
			else
			{
				CReplyToCommand(client, "{green}[SM] {default}The specified target is not a leader.");
				return Plugin_Handled;
			}	
		}
		else
		{
			CReplyToCommand(client, "{green}[SM] {default}The specified target is not a leader.");
			return Plugin_Handled;
		}
	}

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Leaders(int client, int args)
{
	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && IsPossibleLeader(i))
		{
			GetClientName(i, aBuf2, sizeof(aBuf2));
			StrCat(aBuf, sizeof(aBuf), aBuf2);
			StrCat(aBuf, sizeof(aBuf), ", ");
		}
	}

	if(strlen(aBuf))
	{
		aBuf[strlen(aBuf) - 2] = 0;
		CReplyToCommand(client, "{green}[SM] {default}Possible Leaders currently online : {olive}%s", aBuf);
	}
	else
		CReplyToCommand(client, "{green}[SM] {default}Possible Leaders currently online : {olive}None");

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action ReloadLeaders(int client, int args)
{
	UpdateLeaders();
	CReplyToCommand(client, "{green}[SM] {default}Reloaded Leader File");
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool Filter_Leaders(const char[] sPattern, Handle hClients)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && (IsPossibleLeader(i) || g_bIsClientALeader[i]))
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool Filter_NotLeaders(const char[] sPattern, Handle hClients)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && !IsPossibleLeader(i) && !g_bIsClientALeader[i])
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool Filter_Leader(const char[] sPattern, Handle hClients)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && g_bIsClientALeader[i])
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool Filter_NotLeader(const char[] sPattern, Handle hClients)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && !g_bIsClientALeader[i])
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock bool IsPossibleLeader(int client)
{
	char sAuth[64];
	GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));

	for (int i = 0; i <= (MAXLEADERS - 1); i++)
	{
		if (StrEqual(sAuth, g_sLeaderAuth[i]))
			return true;
	}
	return false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock bool IsLeaderOnline()
{
	for (int i = 1; i <= (MAXLEADERS); i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && IsPossibleLeader(i))
			return true;
	}
	return false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void UpdateLeaders()
{
	for (int i = 0; i <= (MAXLEADERS - 1); i++)
		g_sLeaderAuth[i] = "";

	File fFile = OpenFile(g_sDataFile, "rt");
	if (!fFile)
	{
		SetFailState("Could not read from: %s", g_sDataFile);
		return;
	}

	char sAuth[64];
	int iIndex = 0;

	while (!fFile.EndOfFile())
	{
		char line[255];
		if (!fFile.ReadLine(line, sizeof(line)))
			break;

		/* Trim comments */
		int len = strlen(line);
		bool ignoring = false;
		for (int i=0; i<len; i++)
		{
			if (ignoring)
			{
				if (line[i] == '"')
					ignoring = false;
			} else {
				if (line[i] == '"')
				{
					ignoring = true;
				} else if (line[i] == ';') {
					line[i] = '\0';
					break;
				} else if (line[i] == '/'
							&& i != len - 1
							&& line[i+1] == '/')
				{
					line[i] = '\0';
					break;
				}
			}
		}

		TrimString(line);

		if ((line[0] == '/' && line[1] == '/')
			|| (line[0] == ';' || line[0] == '\0'))
		{
			continue;
		}

		sAuth = "";
		BreakString(line, sAuth, sizeof(sAuth));
		g_sLeaderAuth[iIndex] = sAuth;
		iIndex ++;
	}
	fFile.Close();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void LeaderMenu(int client)
{
	Menu menu = new Menu(LeaderMenu_Handler);

	char sprite[64], marker[64], beacon[64], trail[64];

	switch (currentSprite[client])
	{
		case 0: sprite = "Defend";
		case 1: sprite = "Follow";
		default: sprite = "None";
	}

	if(markerActive[client])
		marker = "Yes";
	else
		marker = "No";

	if(beaconActive[client])
		beacon = "Yes";
	else
		beacon = "No";

	if(trailActive[client])
		trail = "Yes";
	else
		trail = "No";

	char sTitle[200];
	Format(sTitle, sizeof(sTitle), "Leader Menu\nSprite: %s\nMarker: %s\nBeacon: %s\nTrail: %s", sprite, marker, beacon, trail);
	menu.SetTitle(sTitle);
	menu.AddItem("resign", "Resign from Leader");
	menu.AddItem("sprite", "Sprite Menu");
	menu.AddItem("marker", "Marker Menu");
	menu.AddItem("beacon", "Toggle Beacon");
	menu.AddItem("trail", "Toggle Trail");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int LeaderMenu_Handler(Menu menu, MenuAction action, int client, int position)
{
	if(IsValidClient(client) && g_bIsClientALeader[client])
	{
		if(action == MenuAction_Select)
		{
			switch(position)
			{
				case 0:
				{
					RemoveLeader(client);
					CPrintToChatAll("{green}[SM] {default}%N {red}has resigned from being leader !", client);

					if (g_cvExtraLogs.IntValue >= 1)
						LogAction(client, -1, "[Leader] \"%L\" has resigned from being leader !", client);
				}
				case 1:
				{
					SpriteMenu(client);
				}
				case 2:
				{
					MarkerMenu(client);
				}
				case 3:
				{
					ToggleBeacon(client);
					LeaderMenu(client);
				}
				case 4:
				{
					ToggleTrail(client);
					LeaderMenu(client);
				}
			}
		}
		else if(action == MenuAction_End)
			delete menu;
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void ToggleBeacon(int client)
{
	if(beaconActive[client])
		beaconActive[client] = false;
	else
		beaconActive[client] = true;

	PerformBeacon(client);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void ToggleTrail(int client)
{
	if(trailActive[client])
		trailActive[client] = false;
	else
		trailActive[client] = true;

	PerformTrail(client);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void SpriteMenu(int client)
{
	Menu menu = new Menu(SpriteMenu_Handler);

	char sprite[64], marker[64], beacon[64];

	switch (currentSprite[client])
	{
		case 0:
		sprite = "Defend";
		case 1:
		sprite = "Follow";
		default:
		sprite = "None";
	}

	if(markerActive[client])
	marker = "Yes";
	else
	marker = "No";

	if(beaconActive[client])
	beacon = "Yes";
	else
	beacon = "No";

	char sTitle[200];
	Format(sTitle, sizeof(sTitle), "Leader Menu\nSprite: %s\nMarker: %s\nBeacon: %s", sprite, marker, beacon);
	menu.SetTitle(sTitle);
	menu.AddItem("none", "No Sprite");
	menu.AddItem("defend", "Defend Here");
	menu.AddItem("follow", "Follow Me");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int SpriteMenu_Handler(Menu menu, MenuAction action, int client, int position)
{
	if(IsValidClient(client) && g_bIsClientALeader[client])
	{
		if(action == MenuAction_Select)
		{
			switch(position)
			{
				case 0:
				{
					RemoveSprite(client);
					CPrintToChat(client, "{green}[SM] {default}Sprite removed.");
					currentSprite[client] = -1;
				}
				case 1:
				{
					RemoveSprite(client);
					spriteEntities[client] = AttachSprite(client, DefendVMT);
					CPrintToChat(client, "{green}[SM] {olive}Sprite {default}changed to {green}Defend Here{default}.");
					currentSprite[client] = 0;
				}
				case 2:
				{
					RemoveSprite(client);
					spriteEntities[client] = AttachSprite(client, FollowVMT);
					CPrintToChat(client, "{green}[SM] {olive}Sprite {default}changed to {green}Follow Me{default}.");
					currentSprite[client] = 1;
				}
			}
			
			LeaderMenu(client);
		}
		else if(action == MenuAction_End)
			delete menu;
			
		else if (action == MenuAction_Cancel && position == MenuCancel_ExitBack)
			LeaderMenu(client);
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void MarkerMenu(int client)
{
	Menu menu = new Menu(MarkerMenu_Handler);

	char sprite[64], marker[64], beacon[64];

	switch (currentSprite[client])
	{
		case 0:
		sprite = "Defend";
		case 1:
		sprite = "Follow";
		default:
		sprite = "None";
	}

	if(markerActive[client])
	marker = "Yes";
	else
	marker = "No";

	if(beaconActive[client])
	beacon = "Yes";
	else
	beacon = "No";

	char sTitle[200];
	Format(sTitle, sizeof(sTitle), "Leader Menu\nSprite: %s\nMarker: %s\nBeacon: %s", sprite, marker, beacon);
	menu.SetTitle(sTitle);
	menu.AddItem("removemarker", "Remove Marker");
	menu.AddItem("defendmarker", "Defend Marker");
	menu.AddItem("signal", "Signal Marker with Aim");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int MarkerMenu_Handler(Menu menu, MenuAction action, int client, int position)
{
	if(IsValidClient(client) && g_bIsClientALeader[client])
	{
		if(action == MenuAction_Select)
		{
			switch(position)
			{
				case 0:
				{
					RemoveMarker(client);
					CPrintToChat(client, "{green}[SM] {default}Marker removed.");
					markerActive[client] = false;
					LeaderMenu(client);
				}
				case 1:
				{
					RemoveMarker(client);
					markerEntities[client] = SpawnMarker(client, DefendVMT);
					CPrintToChat(client, "{green}[SM] {default}Marker {green}Defend Here {default}placed.");
					markerActive[client] = true;
					LeaderMenu(client);
				}
				case 2:
				{
					SignalMenu(client);
				}
			}
		}
		else if(action == MenuAction_End)
			delete menu;
			
		else if (action == MenuAction_Cancel && position == MenuCancel_ExitBack)
			LeaderMenu(client);
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void SignalMenu(int client)
{
	Menu menu = new Menu(SignalMenu_Handler);

	char color[64], sButton[64];
	switch(g_iClientColorNum[client])
	{
		case 0:
			color = "White";
		case 1:
			color = "Red";
		case 2:
			color = "Lime";
		case 3:
			color = "Blue";
		case 4:
			color = "Yellow";
		case 5:
			color = "Cyan";
		case 6:
			color = "Gold";
		case 7:
			color = "Random";
	}
	
	switch(g_iClientButton[client])
	{
		case 0:
			sButton = "Right Mouse Attack";
		case 1:
			sButton = "Spray";
	}

	char sTitle[160];
	Format(sTitle, sizeof(sTitle), "Signal Menu\nColor: %s\nLight: %s\nMarker Button: %s", color, g_bHasLightInMarker[client] ? "Enabled" : "Disabled", sButton);
	menu.SetTitle(sTitle);
	menu.AddItem("Color", "Change Signal Color", g_bIsMarkerEnabled[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	char text[64];
	g_bHasLightInMarker[client] ? Format(text, sizeof(text),"Disable Light In Marker") : Format(text, sizeof(text), "Enable Light In Marker");
	menu.AddItem("Light", text, g_bIsMarkerEnabled[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	menu.AddItem("Button", "Change Marker Button", g_bIsMarkerEnabled[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	char textex[64];
	g_bIsMarkerEnabled[client] ? Format(textex, sizeof(textex),"Disable Marker") : Format(textex, sizeof(textex), "Enable Marker");
	menu.AddItem("Disable", textex);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int SignalMenu_Handler(Menu menu, MenuAction action, int client, int position)
{
	if(IsValidClient(client) && g_bIsClientALeader[client])
	{
		if(action == MenuAction_Select)
		{
			switch(position)
			{
				case 0:
				{	
					SignalColorsMenu(client);
				}
				case 1:
				{
					if(!g_bHasLightInMarker[client])
					{
						g_bHasLightInMarker[client] = true;
						CPrintToChat(client, "{green}[SM] {default}You have {olive}Enabled light on marker.");
					}
					else
					{
						g_bHasLightInMarker[client] = false;
						CPrintToChat(client, "{green}[SM] {default}You have {olive}Disabled light on marker.");
					}
				
					char sValue[10];
					IntToString(g_bHasLightInMarker[client], sValue, sizeof(sValue));
					SetClientCookie(client, g_hClientLightEnabled, sValue);
					SignalMenu(client);
				}
				case 2:
				{
					MarkerButtons(client);
				}
				case 3:
				{
					if(g_bIsMarkerEnabled[client])
					{
						g_bIsMarkerEnabled[client] = false;
						CPrintToChat(client, "{green}[SM] {default}You have {olive}Disabled Marker.");
					}
					else
					{
						g_bIsMarkerEnabled[client] = true;
						CPrintToChat(client, "{green}[SM] {default}You have {olive}Enabled Marker.");
					}
					
					char sValue[10];
					IntToString(g_bIsMarkerEnabled[client], sValue, sizeof(sValue));
					SetClientCookie(client, g_hClientMarkerEnabled, sValue);
					SignalMenu(client);
				}
			}
		}
		else if(action == MenuAction_End)
			delete menu;
			
		else if (action == MenuAction_Cancel && position == MenuCancel_ExitBack)
			LeaderMenu(client);
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void SignalColorsMenu(int client)
{
	Menu menu = new Menu(SignalColorsMenu_Handler);

	char color[64], sButton[64];
	switch(g_iClientColorNum[client])
	{
		case 0:
			color = "White";
		case 1:
			color = "Red";
		case 2:
			color = "Lime";
		case 3:
			color = "Blue";
		case 4:
			color = "Yellow";
		case 5:
			color = "Cyan";
		case 6:
			color = "Gold";
		case 7:
			color = "Random";
	}
	
	switch(g_iClientButton[client])
	{
		case 0:
			sButton = "Right Mouse Attack";
		case 1:
			sButton = "Spray";
	}

	char sTitle[160];
	Format(sTitle, sizeof(sTitle), "Signal Menu\nColor: %s\nLight: %s\nMarker Button: %s", color, g_bHasLightInMarker[client] ? "Enabled" : "Disabled", sButton);
	menu.SetTitle(sTitle);
	
	menu.AddItem("White", "White");
	menu.AddItem("Red", "Red");
	menu.AddItem("Lime", "Lime");
	menu.AddItem("Blue", "Blue");
	menu.AddItem("Yellow", "Yellow");
	menu.AddItem("Cyan", "Cyan");
	menu.AddItem("Gold", "Gold");
	menu.AddItem("Random", "Random");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int SignalColorsMenu_Handler(Menu menu, MenuAction action, int client, int position)
{
	if(IsValidClient(client) && g_bIsClientALeader[client])
	{
		if(action == MenuAction_Select)
		{
			switch(position)
			{
				case 0:
				{
					g_iClientColor[client] = g_ColorWhite;
					g_iClientColorNum[client] = 0;
				}
				case 1:
				{
					g_iClientColor[client] = g_ColorRed;
					g_iClientColorNum[client] = 1;
				}					
				case 2:
				{
					g_iClientColor[client] = g_ColorLime;
					g_iClientColorNum[client] = 2;
				}					
				case 3:
				{
					g_iClientColor[client] = g_ColorBlue;
					g_iClientColorNum[client] = 3;				
				}
				case 4:
				{
					g_iClientColor[client] = g_ColorYellow;	
					g_iClientColorNum[client] = 4;
				}
				case 5:
				{
					g_iClientColor[client] = g_ColorCyan;
					g_iClientColorNum[client] = 5;
				}
				case 6:
				{				
					g_iClientColor[client] = g_ColorGold;	
					g_iClientColorNum[client] = 6;
				}
				case 7:
				{
					g_iClientColorNum[client] = 7;
				}
			}

			char sColor[64];
			Format(sColor, sizeof(sColor), "%d", g_iClientColorNum[client]);
			SetClientCookie(client, g_hClientColor, sColor);
			SignalColorsMenu(client);	
		}
		else if(action == MenuAction_End)
			delete menu;

		else if (action == MenuAction_Cancel && position == MenuCancel_ExitBack)
			SignalMenu(client);
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose: Marker Buttons Menu
//----------------------------------------------------------------------------------------------------

stock void MarkerButtons(int client)
{
	Menu menu = new Menu(SignalButtonsMenu_Handler);

	char color[64], sButton[64];
	switch(g_iClientColorNum[client])
	{
		case 0:
			color = "White";
		case 1:
			color = "Red";
		case 2:
			color = "Lime";
		case 3:
			color = "Blue";
		case 4:
			color = "Yellow";
		case 5:
			color = "Cyan";
		case 6:
			color = "Gold";
		case 7:
			color = "Random";
	}
	
	switch(g_iClientButton[client])
	{
		case 0:
			sButton = "Right Mouse Attack";
		case 1:
			sButton = "Spray";
	}

	char sTitle[160];
	Format(sTitle, sizeof(sTitle), "Signal Menu\nColor: %s\nLight: %s\nMarker Button: %s", color, g_bHasLightInMarker[client] ? "Enabled" : "Disabled", sButton);
	menu.SetTitle(sTitle);
	
	menu.AddItem("Attack", "Right Mouse Attack");
	menu.AddItem("Spray", "Spray");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int SignalButtonsMenu_Handler(Menu menu, MenuAction action, int client, int position)
{
	if(IsValidClient(client) && g_bIsClientALeader[client])
	{
		if(action == MenuAction_Select)
		{
			switch(position)
			{
				case 0:	
					g_iClientButton[client] = 0;

				case 1:
					g_iClientButton[client] = 1;	
			}
			
			char sButton[64];
			Format(sButton, sizeof(sButton), "%d", g_iClientButton[client]);
			SetClientCookie(client, g_hClientButton, sButton);
			MarkerButtons(client);				
		}
		else if(action == MenuAction_End)
			delete menu;
			
		else if (action == MenuAction_Cancel && position == MenuCancel_ExitBack)
			SignalMenu(client);
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose: Setup Signal Markers
//----------------------------------------------------------------------------------------------------

public Action Command_Marker(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "Cannot use this command from server rcon");
		return Plugin_Handled;
	}

	if(IsValidClient(client))
	{
		if(g_bIsClientALeader[client])
		{
			if(g_bIsMarkerEnabled[client])
			{
				float fAimPoint[3], fAngles[3];
				TracePlayerAngles(client, fAimPoint);
				GetClientAbsAngles(client, fAngles);
				
				SetupProp(client, fAimPoint, fAngles);
				return Plugin_Handled;
			}
			else
			{
				CReplyToCommand(client, "{green}[SM] {default}You don't have {olive}Markers {default}enable.");
				return Plugin_Handled;
			}
		}
		else
		{
			CReplyToCommand(client, "{green}[SM] {default}You have to be a leader to use the command.");
			return Plugin_Handled;
		}
	}
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse)
{
	if(IsValidClient(client) && g_bIsClientALeader[client] && g_bIsMarkerEnabled[client])
	{
		char SteamID[32];
		switch(g_iClientButton[client])
		{	
			case 0:
			{
				if(buttons & IN_ATTACK2)
				{
					if(g_fNextSpawn[client] < GetGameTime())
					{
						float fAimPoint[3], fAngles[3];
						TracePlayerAngles(client, fAimPoint);
						GetClientAbsAngles(client, fAngles);
				
						if(!GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID)))
						{
							CPrintToChat(client, "{green}[SM] {default}You should have a valid steamid to use markers");
						}
						else
						{
							SetupProp(client, fAimPoint, fAngles);
							g_fNextSpawn[client] = GetGameTime() + 0.2;
						}
					}
				}
			}
			case 1:
			{
				if(!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false))
				{
					if(impulse == 201)
					{
						if(g_fNextSpawn[client] < GetGameTime())
						{
							float fAimPoint[3], fAngles[3];
							TracePlayerAngles(client, fAimPoint);
							GetClientAbsAngles(client, fAngles);
					
							if(!GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID)))
							{
								CPrintToChat(client, "{green}[SM] {default}You should have a valid steamid to use markers");
							}
							else
							{
								SetupProp(client, fAimPoint, fAngles);
								g_fNextSpawn[client] = GetGameTime() + 0.2;
							}
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

stock void SetupProp(int client, float fOrigin[3], float fAngles[3])
{
	if(IsValidEntity(g_iPropDynamic[client]))
	{
		RemoveEntity(g_iPropDynamic[client]);
		delete g_hMarkerTimer[client];
		g_iPropDynamic[client] = -1;
		g_iPropDynamic[client] = CreateEntityByName("prop_dynamic_override");
	}
	else
	{	
		g_iPropDynamic[client] = CreateEntityByName("prop_dynamic_override");
	}
	if(IsValidEntity(g_iNeon[client]))
	{
		RemoveEntity(g_iNeon[client]);
		g_iNeon[client] = -1;
	}

	if(!IsValidEntity(g_iPropDynamic[client]))
		return;

	g_hMarkerTimer[client] = null;
	g_hMarkerTimer[client] = CreateTimer(g_cVMarkerTimer.FloatValue, Marker_Timer, GetClientSerial(client));
	DispatchKeyValue(g_iPropDynamic[client], "model", "models/oylsister/misc/signal_marker.mdl");
	DispatchKeyValue(g_iPropDynamic[client], "solid", "0");
	DispatchKeyValue(g_iPropDynamic[client], "angles", "0 180 0");
	DispatchKeyValue(g_iPropDynamic[client], "skin", "0");
	DispatchKeyValue(g_iPropDynamic[client], "renderamt", "128");
	DispatchKeyValueFloat(g_iPropDynamic[client], "modelscale", 0.8);

	DispatchSpawn(g_iPropDynamic[client]);

	SetVariantString("disablereceiveshadows 1");
	AcceptEntityInput(g_iPropDynamic[client], "AddOutput");

	SetVariantString("disableshadows 1");
	AcceptEntityInput(g_iPropDynamic[client], "AddOutput");

	int color[4];

	if(g_iClientColorNum[client] != 7)
	{	
		color[0] = g_iClientColor[client][0];
		color[1] = g_iClientColor[client][1];
		color[2] = g_iClientColor[client][2];
		color[3] = g_iClientColor[client][3];
		SetEntityRenderColor(g_iPropDynamic[client], color[0], color[1], color[2], color[3]);
	}
	else if(g_iClientColorNum[client] == 7)
	{
		color[0] = GetRandomInt(1, 255);
		color[1] = GetRandomInt(1, 255);
		color[2] = GetRandomInt(1, 255);
		color[3] = GetRandomInt(40, 255);
		SetEntityRenderColor(g_iPropDynamic[client], color[0], color[1], color[2], color[3]);
	}

	fOrigin[2] += 10;

	if(g_bHasLightInMarker[client])
		SetupNeon(client, fOrigin, color);

	TeleportEntity(g_iPropDynamic[client], fOrigin, fAngles, NULL_VECTOR);

	SetVariantInt(56);
	AcceptEntityInput(g_iPropDynamic[client], "alpha");
}

stock void SetupNeon(int client, float fOrigin[3], int color[4])
{
	if(IsValidEntity(g_iNeon[client]))
	{
		RemoveEntity(g_iNeon[client]);
		g_iNeon[client] = -1;
		g_iNeon[client] = CreateEntityByName("light_dynamic");
	}
	else if(g_iNeon[client] == -1)
	{	
		g_iNeon[client] = CreateEntityByName("light_dynamic");
	}

	if(!IsValidEntity(g_iNeon[client]))
		return;

	char sColor[64];
	Format(sColor, sizeof(sColor), "%i %i %i %i", color[0], color[1], color[2], color[3]);

	DispatchKeyValue(g_iNeon[client], "_light", sColor);
	DispatchKeyValue(g_iNeon[client], "brightness", "5");
	DispatchKeyValue(g_iNeon[client], "distance", "150");
	DispatchKeyValue(g_iNeon[client], "spotlight_radius", "50");
	DispatchKeyValue(g_iNeon[client], "style", "0");
	DispatchSpawn(g_iNeon[client]);
	AcceptEntityInput(g_iNeon[client], "TurnOn");

	TeleportEntity(g_iNeon[client], fOrigin, NULL_VECTOR, NULL_VECTOR);
}

stock bool TracePlayerAngles(int client, float fResult[3])
{
	if (!IsClientInGame(client))
		return false;

	float fEyeAngles[3];
	float fEyeOrigin[3];

	GetClientEyeAngles(client, fEyeAngles);
	GetClientEyePosition(client, fEyeOrigin);

	Handle hTraceRay = TR_TraceRayFilterEx(fEyeOrigin, fEyeAngles, MASK_SHOT_HULL, RayType_Infinite, TraceEntityFilter_FilterEntities);

	if (TR_DidHit(hTraceRay))
	{
		TR_GetEndPosition(fResult, hTraceRay);

		delete hTraceRay;

		return true;
	}

	delete hTraceRay;
	return false;
}

stock bool TraceEntityFilter_FilterEntities(int entity, int contentsMask)
{
	return entity > GetMaxEntities();
}

public Action Marker_Timer(Handle timer, int clientserial)
{
	int client = GetClientFromSerial(clientserial);

	g_hMarkerTimer[client] = null;
	if(IsValidEntity(g_iPropDynamic[client]))
	{
		RemoveEntity(g_iPropDynamic[client]);
		g_iPropDynamic[client] = -1;
	}

	if(IsValidEntity(g_iNeon[client]))
	{
		RemoveEntity(g_iNeon[client]);
		g_iNeon[client] = -1;
	}

	return Plugin_Stop;
}

public Action HookDecal(const char[] sTEName, const int[] iClients, int iNumClients, float fSendDelay)
{
	int client = TE_ReadNum("m_nPlayer");
	RequestFrame(CheckAdminSpray, client);
	return Plugin_Continue;
}

stock void CheckAdminSpray(int client)
{
	if(IsValidClient(client) && g_bIsClientALeader[client] && g_bIsMarkerEnabled[client])
	{
		if(g_iClientButton[client] == 1)
		{
			if(g_fNextSpawn[client] < GetGameTime())
			{
				float fAimPoint[3], fAngles[3];
				TracePlayerAngles(client, fAimPoint);
				GetClientAbsAngles(client, fAngles);
		
				char SteamID[32];
				if(!GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID)))
				{
					CPrintToChat(client, "{green}[SM] {default}You should have a valid steamid to use markers");
				}
				else
				{
					SetupProp(client, fAimPoint, fAngles);
					g_fNextSpawn[client] = GetGameTime() + 0.2;
				}
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientDisconnect(int client)
{
	if(g_bIsClientALeader[client])
	{
		CPrintToChatAll("{green}[SM] {default}Leader {olive}%N {default}has disconnected !", client);
		RemoveLeader(client);
	}

	delete g_hMarkerTimer[client];

	if(IsValidEntity(g_iPropDynamic[client]))
	{
		RemoveEntity(g_iPropDynamic[client]);
		g_iPropDynamic[client] = -1;
	}

	if(IsValidEntity(g_iNeon[client]))
	{
		RemoveEntity(g_iNeon[client]);
		g_iNeon[client] = -1;
	}

	g_bIsClientALeader[client] = false;
	g_iClientNextVote[client] = 0;
	voteCount[client] = 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int team = GetEventInt(event, "team");
	if(IsValidClient(client) && g_bIsClientALeader[client])
	{
		if(team == 1)
		{
			RemoveLeader(client);
			CPrintToChatAll("{green}[Leader] {olive}%N {default}has moved to Spectators team !", client);
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(g_bIsClientALeader[client])
	{
		CPrintToChatAll("{green}[Leader] {olive}%N {default}has died !", client);
		RemoveLeader(client);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
	if(g_bIsClientALeader[client])
	{
		CPrintToChatAll("{green}[Leader] {olive}%N {default}has been infected !", client);
		RemoveLeader(client);
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && g_bIsClientALeader[i])
			RemoveLeader(i);

		else if(IsValidClient(i))
			delete g_hMarkerTimer[i];
	}

	KillAllBeacons();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock bool IsValidClient(int client)
{
	if(client <= 0 || client > MaxClients || !IsClientConnected(client) || IsClientSourceTV(client))
		return false;

	return IsClientInGame(client);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && g_bIsClientALeader[i])
			RemoveLeader(i);

		else if(IsValidClient(i))
			delete g_hMarkerTimer[i];
	}

	KillAllBeacons();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			g_iClientNextVote[i] = 0;
			g_fNextSpawn[i] = 0.0;
			g_iClientNextLeader[i] = 0;
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action HookPlayerChat(int client, char[] command, int args)
{
	if(IsValidClient(client) && g_bIsClientALeader[client])
	{
		char LeaderText[256];
		GetCmdArgString(LeaderText, sizeof(LeaderText));
		StripQuotes(LeaderText);
		if(LeaderText[0] == '/' || LeaderText[0] == '@' || strlen(LeaderText) == 0 || IsChatTrigger())
		{
			return Plugin_Handled;
		}
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			CPrintToChatAll("{green}[Leader] {default}%N:{olive} %s", client, LeaderText);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Leader_IsCurrentLeaders", Native_IsClientACurrentLeader);
	CreateNative("Leader_SetLeader", Native_SetLeader);
	CreateNative("Leader_IsClientLeader", Native_IsClientLeader);
	CreateNative("Leader_IsLeaderOnline", Native_IsLeaderOnline);

	RegPluginLibrary("leader");

	return APLRes_Success;
}

public int Native_IsClientACurrentLeader(Handle plugin, int numParams)
{
	return g_bIsClientALeader[GetNativeCell(1)];
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_SetLeader(Handle plugin, int numParams)
{
	SetLeader(GetNativeCell(1), -1);
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_IsClientLeader(Handle plugin, int numParams)
{
	return IsPossibleLeader(GetNativeCell(1));
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_IsLeaderOnline(Handle plugin, int numParams)
{
	return IsLeaderOnline();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Radio(int client, const char[] command, int argc)
{
	if(g_bIsClientALeader[client])
	{
		if(StrEqual(command, "compliment")) PrintRadio(client, "Nice!");
		if(StrEqual(command, "coverme")) PrintRadio(client, "Cover Me!");
		if(StrEqual(command, "cheer")) PrintRadio(client, "Cheer!");
		if(StrEqual(command, "takepoint")) PrintRadio(client, "You take the point.");
		if(StrEqual(command, "holdpos")) PrintRadio(client, "Hold This Position.");
		if(StrEqual(command, "regroup")) PrintRadio(client, "Regroup Team.");
		if(StrEqual(command, "followme")) PrintRadio(client, "Follow me.");
		if(StrEqual(command, "takingfire")) PrintRadio(client, "Taking fire... need assistance!");
		if(StrEqual(command, "thanks"))  PrintRadio(client, "Thanks!");
		if(StrEqual(command, "go"))  PrintRadio(client, "Go go go!");
		if(StrEqual(command, "fallback"))  PrintRadio(client, "Team, fall back!");
		if(StrEqual(command, "sticktog"))  PrintRadio(client, "Stick together, team.");
		if(StrEqual(command, "report"))  PrintRadio(client, "Report in, team.");
		if(StrEqual(command, "roger"))  PrintRadio(client, "Roger that.");
		if(StrEqual(command, "enemyspot"))  PrintRadio(client, "Enemy spotted.");
		if(StrEqual(command, "needbackup"))  PrintRadio(client, "Need backup.");
		if(StrEqual(command, "sectorclear"))  PrintRadio(client, "Sector clear.");
		if(StrEqual(command, "inposition"))  PrintRadio(client, "I'm in position.");
		if(StrEqual(command, "reportingin"))  PrintRadio(client, "Reporting In.");
		if(StrEqual(command, "getout"))  PrintRadio(client, "Get out of there, it's gonna blow!.");
		if(StrEqual(command, "negative"))  PrintRadio(client, "Negative.");
		if(StrEqual(command, "enemydown"))  PrintRadio(client, "Enemy down.");
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void PrintRadio(int client, char[] text)
{
	char szClantag[32], szMessage[255];
	CS_GetClientClanTag(client, szClantag, sizeof(szClantag));

	Format(szMessage, sizeof(szMessage), "{green}[LEADER] {yellow}%s {teamcolor}%N {default}(RADIO): %s", szClantag, client, text);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
			CPrintToChat(i, szMessage);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action VoteLeader(int client, int argc)
{
	if(!allowVoting)
	{
		CReplyToCommand(client, "{green}[SM] {default}Voting for leader is disabled.");
		return Plugin_Handled;
	}
	if(GetCurrentLeadersCount() == leaders_max)
	{
		CReplyToCommand(client, "{green}[SM] {default}There are {olive}%d{default} leaders which is the max number of available leaders on this map.", leaders_max);
		return Plugin_Handled;
	}
	if(argc < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_voteleader <player>");
		return Plugin_Handled;
	}

	int IsGagged = SourceComms_GetClientGagType(client);

	if(IsGagged > 0)
	{
		CReplyToCommand(client, "{green}[Leader] {default}You are not allowed to vote for leader since you are gagged.");
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	int target = FindTarget(client, arg, false, false);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	if(g_bIsClientALeader[target])
	{
		CReplyToCommand(client, "{green}[SM] {default}The specified target is already a leader");
		return Plugin_Handled;
	}

	if(GetClientFromSerial(votedFor[client]) == target)
	{
		CReplyToCommand(client, "{green}[SM] {default}You've already voted for this person !");
		return Plugin_Handled;
	}

	if(!ZR_IsClientHuman(client) && IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{green}[SM] {default}You have to be an alive Human for voting !");
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(target) || ZR_IsClientZombie(target))
	{
		CReplyToCommand(client, "{green}[SM] {default}You have to vote for an alive Human !");
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(target) || ZR_IsClientZombie(target))
	{
		CReplyToCommand(client, "{green}[SM] {default}You have to vote for an alive Human !");
		return Plugin_Handled;
	}

	if(g_iClientNextVote[client] > GetTime())
	{
		CReplyToCommand(client, "{green}[SM] {default}You are currently on cooldown, please wait {olive}%d seconds{default} for your next vote!", g_iClientNextVote[client] - GetTime());
		return Plugin_Handled;
	}

	if(GetClientFromSerial(votedFor[client]) != 0)
	{
		if(IsValidClient(GetClientFromSerial(votedFor[client]))) {
			voteCount[GetClientFromSerial(votedFor[client])]--;
		}
	}
	voteCount[target]++;
	votedFor[client] = GetClientSerial(target);
	CPrintToChatAll("{green}[SM] {teamcolor}%N {default}has voted for {olive}%N {default}to be the leader (%i/%i votes)", client, target, voteCount[target], GetClientCount(true)/10);
	g_iClientNextVote[client] = GetTime() + g_cVCooldown.IntValue;

	if(voteCount[target] >= GetClientCount(true)/10)
	{
		SetLeader(target, -1);
		CPrintToChatAll("{green}[SM] {olive}%N {default}has been voted to be A new leader!", target);
		LogAction(client, target, "[Leader] \"%L\" has been voted to be a leader !", target);
		LeaderMenu(target);
	}

	return Plugin_Handled;
}
