#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>
#include <sourcecomms>
#include <leader>
#include <multicolors>

#define PLUGIN_VERSION "3.4"
#define MAXLEADERS 64
#pragma newdecls required

int currentSprite = -1, spriteEntities[MAXPLAYERS+1], markerEntities[MAXPLAYERS+1], leaderClient = -1;
int voteCount[MAXPLAYERS+1], votedFor[MAXPLAYERS+1];

bool markerActive = false, beaconActive = false, trailActive = false, allowVoting = false;

ConVar g_cVDefendVTF = null;
ConVar g_cVDefendVMT = null;
ConVar g_cVFollowVTF = null;
ConVar g_cVFollowVMT = null;
ConVar g_cTrailVTF = null;
ConVar g_cTrailVMT = null;
ConVar g_cTrailPosition = null;

ConVar g_cVAllowVoting = null;

char DefendVMT[PLATFORM_MAX_PATH];
char DefendVTF[PLATFORM_MAX_PATH];
char FollowVMT[PLATFORM_MAX_PATH];
char FollowVTF[PLATFORM_MAX_PATH];
char TrailVMT[PLATFORM_MAX_PATH];
char TrailVTF[PLATFORM_MAX_PATH];
char leaderTag[64];
char g_sDataFile[128];
char g_sLeaderAuth[MAXLEADERS][64];

int g_BeamSprite = -1;
int g_HaloSprite = -1;
int greyColor[4] = {128, 128, 128, 255};
int g_BeaconSerial[MAXPLAYERS+1] = { 0, ... };
int g_Serial_Gen = 0;
int g_TrailModel[MAXPLAYERS+1] = { 0, ... };

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Leader",
	author = "AntiTeal + Neon + inGame + .Rushaway",
	description = "Allows for a human to be a leader, and give them special functions with it.",
	version = PLUGIN_VERSION,
	url = "https://antiteal.com"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	BuildPath(Path_SM, g_sDataFile, sizeof(g_sDataFile), "configs/leader/leaders.ini");

	CreateConVar("sm_leader_version", PLUGIN_VERSION, "Leader Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	//AddCommandListener(HookPlayerChat, "say");

	RegConsoleCmd("sm_leader", Leader);
	RegConsoleCmd("sm_currentleader", CurrentLeader);
	RegConsoleCmd("sm_wholeader", CurrentLeader);
	RegConsoleCmd("sm_leaders", Leaders);
	RegConsoleCmd("sm_voteleader", VoteLeader);
	RegAdminCmd("sm_removeleader", RemoveTheLeader, ADMFLAG_GENERIC);
	RegAdminCmd("sm_reloadleaders", ReloadLeaders, ADMFLAG_GENERIC);

	g_cVDefendVMT = CreateConVar("sm_leader_defend_vmt", "materials/nide/leader/defend.vmt", "The defend here .vmt file");
	g_cVDefendVTF = CreateConVar("sm_leader_defend_vtf", "materials/nide/leader/defend.vtf", "The defend here .vtf file");
	g_cVFollowVMT = CreateConVar("sm_leader_follow_vmt", "materials/nide/leader/follow.vmt", "The follow me .vmt file");
	g_cVFollowVTF = CreateConVar("sm_leader_follow_vtf", "materials/nide/leader/follow.vtf", "The follow me .vtf file");
	g_cTrailVMT = CreateConVar("sm_leader_trail_vmt", "materials/nide/leader/trail.vmt", "The trail .vmt file");
	g_cTrailVTF = CreateConVar("sm_leader_trail_vtf", "materials/nide/leader/trail.vtf", "The trail .vtf file");
	g_cTrailPosition = CreateConVar("sm_leader_trail_position", "0.0 10.0 10.0", "The trail position (X Y Z)");
	g_cVAllowVoting = CreateConVar("sm_leader_allow_votes", "1", "Determines whether players can vote for leaders.");

	g_cVDefendVMT.AddChangeHook(ConVarChange);
	g_cVDefendVTF.AddChangeHook(ConVarChange);
	g_cVFollowVMT.AddChangeHook(ConVarChange);
	g_cVFollowVTF.AddChangeHook(ConVarChange);
	g_cTrailVMT.AddChangeHook(ConVarChange);
	g_cTrailVTF.AddChangeHook(ConVarChange);
	g_cVAllowVoting.AddChangeHook(ConVarChange);

	AutoExecConfig(true);

	g_cVDefendVTF.GetString(DefendVTF, sizeof(DefendVTF));
	g_cVDefendVMT.GetString(DefendVMT, sizeof(DefendVMT));
	g_cVFollowVTF.GetString(FollowVTF, sizeof(FollowVTF));
	g_cVFollowVMT.GetString(FollowVMT, sizeof(FollowVMT));
	g_cTrailVTF.GetString(TrailVTF, sizeof(TrailVTF));
	g_cTrailVMT.GetString(TrailVMT, sizeof(TrailVMT));

	allowVoting = g_cVAllowVoting.BoolValue;

	RegPluginLibrary("leader");

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
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void CreateBeacon(int client)
{
	g_BeaconSerial[client] = ++g_Serial_Gen;
	CreateTimer(1.0, Timer_Beacon, client | (g_Serial_Gen << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void KillBeacon(int client)
{
	g_BeaconSerial[client] = 0;

	if (IsClientInGame(client))
	{
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void KillAllBeacons()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		KillBeacon(i);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void PerformBeacon(int client)
{
	if (g_BeaconSerial[client] == 0)
	{
		CreateBeacon(client);
		LogAction(client, client, "\"%L\" set a beacon on himself", client);
	}
	else
	{
		KillBeacon(client);
		LogAction(client, client, "\"%L\" removed a beacon on himself", client);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void PerformTrail(int client)
{
	if (g_TrailModel[client] == 0)
	{
		CreateTrail(client);
		LogAction(client, client, "\"%L\" set a trail on himself", client);
	}
	else
	{
		KillTrail(client);
		LogAction(client, client, "\"%L\" removed a trail on himself", client);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Timer_Beacon(Handle timer, any value)
{
	int client = value & 0x7f;
	int serial = value >> 7;

	if (!IsClientInGame(client) || !IsPlayerAlive(client) || g_BeaconSerial[client] != serial)
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
public int AttachSprite(int client, char[] sprite) //https://forums.alliedmods.net/showpost.php?p=1880207&postcount=5
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
public void RemoveSprite(int client)
{
	if (spriteEntities[client] != -1 && IsValidEdict(spriteEntities[client]))
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
public void RemoveMarker(int client)
{
	if (markerEntities[client] != -1 && IsValidEdict(markerEntities[client]))
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
public void SetLeader(int client)
{
	if(IsValidClient(leaderClient))
	{
		RemoveLeader(leaderClient);
		CPrintToChatAll("{green}[SM] {default}The current leader has been removed !");
	}

	if(IsValidClient(client))
	{
		leaderClient = client;

		CS_GetClientClanTag(client, leaderTag, sizeof(leaderTag));
		//CS_SetClientClanTag(client, "[Leader]");

		//leaderMVP = CS_GetMVPCount(client);
		//CS_SetMVPCount(client, 99);

		//leaderScore = CS_GetClientContributionScore(client);
		//CS_SetClientContributionScore(client, 9999);

		currentSprite = -1;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void RemoveLeader(int client)
{
	//CS_SetClientClanTag(client, leaderTag);
	//CS_SetMVPCount(client, leaderMVP);
	//CS_SetClientContributionScore(client, leaderScore);

	RemoveSprite(client);
	RemoveMarker(client);

	if(beaconActive)
		KillBeacon(client);

	if(trailActive)
		KillTrail(client);

	currentSprite = -1;
	leaderClient = -1;
	markerActive = false;
	beaconActive = false;
	trailActive = false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int SpawnMarker(int client, char[] sprite)
{
	if(!IsPlayerAlive(client))
	{
		return -1;
	}

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
bool CreateTrail(int client)
{
	if (!client)
	{
		return false;
	}

	KillTrail(client);
	
	if (!IsPlayerAlive(client) || !(1 < GetClientTeam(client) < 4))
	{
		return true;
	}
	
	g_TrailModel[client] = CreateEntityByName("env_spritetrail");
	if (g_TrailModel[client] != 0) 
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
	
	return true;

}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
void KillTrail(int client)
{
	if (g_TrailModel[client] > MaxClients && IsValidEdict(g_TrailModel[client]))
	{
		AcceptEntityInput(g_TrailModel[client], "kill");
	}
	
	g_TrailModel[client] = 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action CurrentLeader(int client, int args)
{
	if(IsValidClient(leaderClient))
	{
		CPrintToChat(client, "{green}[SM] {default}The current leader is {olive}%N {default}!", leaderClient);
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "{green}[SM] {default}There is no current leader!");
		return Plugin_Handled;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action RemoveTheLeader(int client, int args)
{
	if(IsValidClient(leaderClient))
	{
		CPrintToChatAll("{green}[SM] {default}The current leader has been removed!");
		RemoveLeader(leaderClient);
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "{green}[SM] {default}There is no current leader!");
		return Plugin_Handled;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Leader(int client, int args)
{
	if(CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false))
	{
		if(args == 1)
		{
			char arg1[65];
			GetCmdArg(1, arg1, sizeof(arg1));
			int target = FindTarget(client, arg1, false, false);
			if (target == -1)
			{
				return Plugin_Handled;
			}

			if(target == leaderClient)
			{
				LeaderMenu(target);
				return Plugin_Handled;
			}
			else
			{
				if(IsPlayerAlive(target) && ZR_IsClientHuman(target) || ZR_IsClientZombie(client))
				// Admin Target a player
				{
					SetLeader(target);
					CPrintToChatAll("{green}[SM] {olive}%N {default}is the new leader !", target);
					CPrintToChat(target, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
					LeaderMenu(target);
					return Plugin_Handled;
				}
				else
				{
					CReplyToCommand(client, "{green}[SM] {default}The target has to be an alive Human !");
					return Plugin_Handled;
				}
			}
		}
		else if(args == 0)
		{
			if(client == leaderClient)
			{
				LeaderMenu(client);
				return Plugin_Handled;
			}
			if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
			// Admin have access to sm_leader
			{
				SetLeader(client);
				CPrintToChatAll("{green}[SM] {olive}%N {default}is the new leader !", client);
				CPrintToChat(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
				LeaderMenu(client);
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
			CReplyToCommand(client, "[SM] Usage: sm_leader <optional: client|#userid>");
			return Plugin_Handled;
		}
	}

	if (IsPossibleLeader(client))
	{
		if(client == leaderClient)
		{
			LeaderMenu(client);
			return Plugin_Handled;
		}
		if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
		// Access via leader.ini
		{
			SetLeader(client);
			CPrintToChatAll("{green}[SM] {olive}%N {default}is the new leader !", client);
			CPrintToChat(client, "{green}[SM] {default}Type {green}!leader {default}to open up the leader menu.");
			LeaderMenu(client);
			return Plugin_Handled;
		}
		else
		{
			CReplyToCommand(client, "{green}[SM] {default}You need to be an alive Human !");
			return Plugin_Handled;
		}
	}
	if(client == leaderClient)
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
		if(IsClientInGame(i) && !IsFakeClient(i) && (IsPossibleLeader(i) || i == leaderClient))
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
		if(IsClientInGame(i) && !IsFakeClient(i) && !IsPossibleLeader(i) && i != leaderClient)
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
	if(IsValidClient(leaderClient))
	{
		PushArrayCell(hClients, leaderClient);
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
		if(IsValidClient(i) && (i != leaderClient))
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool IsPossibleLeader(int client)
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
public bool IsLeaderOnline()
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
public void UpdateLeaders()
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
public void LeaderMenu(int client)
{
	Handle menu = CreateMenu(LeaderMenu_Handler);

	char sprite[64], marker[64], beacon[64], trail[64];

	switch (currentSprite)
	{
		case 0: sprite = "Defend";
		case 1: sprite = "Follow";
		default: sprite = "None";
	}

	if(markerActive)
		marker = "Yes";
	else
		marker = "No";

	if(beaconActive)
		beacon = "Yes";
	else
		beacon = "No";

	if(trailActive)
		trail = "Yes";
	else
		trail = "No";

	SetMenuTitle(menu, "Leader Menu\nSprite: %s\nMarker: %s\nBeacon: %s\nTrail: %s", sprite, marker, beacon, trail);
	AddMenuItem(menu, "resign", "Resign from Leader");
	AddMenuItem(menu, "sprite", "Sprite Menu");
	AddMenuItem(menu, "marker", "Marker Menu");
	AddMenuItem(menu, "beacon", "Toggle Beacon");
	AddMenuItem(menu, "trail", "Toggle Trail");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int LeaderMenu_Handler(Handle menu, MenuAction action, int client, int position)
{
	if(leaderClient == client && IsValidClient(client))
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(menu, position, info, sizeof(info));

			if(StrEqual(info, "resign"))
			{
				RemoveLeader(client);
				CPrintToChatAll("{green}[SM] {default}%N {red}has resigned from being leader !", client);
			}
			if(StrEqual(info, "sprite"))
			{
				SpriteMenu(client);
			}
			if(StrEqual(info, "marker"))
			{
				MarkerMenu(client);
			}
			if(StrEqual(info, "beacon"))
			{
				ToggleBeacon(client);
				LeaderMenu(client);
			}
			if(StrEqual(info, "trail"))
			{
				ToggleTrail(client);
				LeaderMenu(client);
			}
		}
		else if(action == MenuAction_End)
		{
			CloseHandle(menu);
		}
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void ToggleBeacon(int client)
{
	if(beaconActive)
		beaconActive = false;
	else
		beaconActive = true;

	PerformBeacon(client);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void ToggleTrail(int client)
{
	if(trailActive)
		trailActive = false;
	else
		trailActive = true;

	PerformTrail(client);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void SpriteMenu(int client)
{
	Handle menu = CreateMenu(SpriteMenu_Handler);

	char sprite[64], marker[64], beacon[64];

	switch (currentSprite)
	{
		case 0:
		sprite = "Defend";
		case 1:
		sprite = "Follow";
		default:
		sprite = "None";
	}

	if(markerActive)
	marker = "Yes";
	else
	marker = "No";

	if(beaconActive)
	beacon = "Yes";
	else
	beacon = "No";

	SetMenuTitle(menu, "Leader Menu\nSprite: %s\nMarker: %s\nBeacon: %s", sprite, marker, beacon);
	AddMenuItem(menu, "none", "No Sprite");
	AddMenuItem(menu, "defend", "Defend Here");
	AddMenuItem(menu, "follow", "Follow Me");

	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int SpriteMenu_Handler(Handle menu, MenuAction action, int client, int position)
{
	if(leaderClient == client && IsValidClient(client))
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(menu, position, info, sizeof(info));

			if(StrEqual(info, "none"))
			{
				RemoveSprite(client);
				CPrintToChat(client, "{green}[SM] {default}Sprite removed.");
				currentSprite = -1;
				LeaderMenu(client);
			}
			if(StrEqual(info, "defend"))
			{
				RemoveSprite(client);
				spriteEntities[client] = AttachSprite(client, DefendVMT);
				CPrintToChat(client, "{green}[SM] {olive}Sprite {default}changed to {green}Defend Here{default}.");
				currentSprite = 0;
				LeaderMenu(client);
			}
			if(StrEqual(info, "follow"))
			{
				RemoveSprite(client);
				spriteEntities[client] = AttachSprite(client, FollowVMT);
				CPrintToChat(client, "{green}[SM] {olive}Sprite {default}changed to {green}Follow Me{default}.");
				currentSprite = 1;
				LeaderMenu(client);
			}
		}
		else if(action == MenuAction_End)
		{
			CloseHandle(menu);
		}
		else if (action == MenuAction_Cancel && position == MenuCancel_ExitBack)
		{
			LeaderMenu(client);
		}
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void MarkerMenu(int client)
{
	Handle menu = CreateMenu(MarkerMenu_Handler);

	char sprite[64], marker[64], beacon[64];

	switch (currentSprite)
	{
		case 0:
		sprite = "Defend";
		case 1:
		sprite = "Follow";
		default:
		sprite = "None";
	}

	if(markerActive)
	marker = "Yes";
	else
	marker = "No";

	if(beaconActive)
	beacon = "Yes";
	else
	beacon = "No";

	SetMenuTitle(menu, "Leader Menu\nSprite: %s\nMarker: %s\nBeacon: %s", sprite, marker, beacon);
	AddMenuItem(menu, "removemarker", "Remove Marker");
	AddMenuItem(menu, "defendmarker", "Defend Marker");

	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int MarkerMenu_Handler(Handle menu, MenuAction action, int client, int position)
{
	if(leaderClient == client && IsValidClient(client))
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(menu, position, info, sizeof(info));

			if(StrEqual(info, "removemarker"))
			{
				RemoveMarker(client);
				CPrintToChat(client, "{green}[SM] {default}Marker removed.");
				markerActive = false;
				LeaderMenu(client);
			}
			if(StrEqual(info, "defendmarker"))
			{
				RemoveMarker(client);
				markerEntities[client] = SpawnMarker(client, DefendVMT);
				CPrintToChat(client, "{green}[SM] {default}Marker {green}Defend Here {default}placed.");
				markerActive = true;
				LeaderMenu(client);
			}
		}
		else if(action == MenuAction_End)
		{
			CloseHandle(menu);
		}
		else if (action == MenuAction_Cancel && position == MenuCancel_ExitBack)
		{
			LeaderMenu(client);
		}
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientDisconnect(int client)
{
	if(client == leaderClient)
	{
		CPrintToChatAll("{green}[SM] {red}The leader has disconnected !");
		RemoveLeader(client);
	}
	voteCount[client] = 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Event_PlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(client == leaderClient)
	{
		CPrintToChatAll("{green}[SM] {red}The leader has died !");
		RemoveLeader(client);
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if(client == leaderClient)
	{
		CPrintToChatAll("{green}[SM] {red}The leader has been infected !");
		RemoveLeader(client);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnMapEnd()
{
	if(IsValidClient(leaderClient))
	{
		RemoveLeader(leaderClient);
	}
	leaderClient = -1;
	KillAllBeacons();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Event_RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	if(IsValidClient(leaderClient))
	{
		RemoveLeader(leaderClient);
	}

	KillAllBeacons();
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action HookPlayerChat(int client, char[] command, int args)
{
	if(IsValidClient(client) && leaderClient == client)
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
	CreateNative("Leader_CurrentLeader", Native_CurrentLeader);
	CreateNative("Leader_SetLeader", Native_SetLeader);
	CreateNative("Leader_IsClientLeader", Native_IsClientLeader);
	CreateNative("Leader_IsLeaderOnline", Native_IsLeaderOnline);
	
	return APLRes_Success;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_CurrentLeader(Handle plugin, int numParams)
{
	return leaderClient;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_SetLeader(Handle plugin, int numParams)
{
	SetLeader(GetNativeCell(1));
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
	if(client == leaderClient)
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
public void PrintRadio(int client, char[] text)
{
	char szClantag[32], szMessage[255];
	CS_GetClientClanTag(client, szClantag, sizeof(szClantag));

	Format(szMessage, sizeof(szMessage), "{green}[LEADER] {yellow}%s {teamcolor}%N {default}(RADIO): %s", szClantag, client, text);
	CPrintToChatAll(szMessage);
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
	if(IsValidClient(leaderClient))
	{
		CReplyToCommand(client, "{green}[SM] {default}There is already a leader !");
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

	if(GetClientFromSerial(votedFor[client]) == target)
	{
		CReplyToCommand(client, "{green}[SM] {default}You've already voted for this person !");
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(target) || ZR_IsClientZombie(target))
	{
		CReplyToCommand(client, "{green}[SM] {default}You have to vote for an alive Human !");
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

	if(voteCount[target] >= GetClientCount(true)/10)
	{
		SetLeader(target);
		CPrintToChatAll("{green}[SM] {olive}%N {default}has been voted to be the new leader!", target);
		LeaderMenu(target);
	}

	return Plugin_Handled;
}
