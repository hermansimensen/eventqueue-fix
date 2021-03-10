//#define DEBUG

#define PLUGIN_NAME           "EventQueue fix"
#define PLUGIN_AUTHOR         "carnifex"
#define PLUGIN_DESCRIPTION    ""
#define PLUGIN_VERSION        "1.0"
#define PLUGIN_URL            ""

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <shavit>

#pragma semicolon 1

ArrayList g_aPlayerEvents[MAXPLAYERS+1];
bool g_bLateLoad;

enum struct event_t
{
	char target[64];
	char targetInput[64];
	char variantValue[64];
	float delay;
	int activator;
	int caller;
	int outputID;
}

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	LoadDHooks();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	
	return APLRes_Success;
}

public void OnMapStart()
{
	if(g_bLateLoad)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				OnClientPutInServer(client);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	if(g_aPlayerEvents[client] == null)
	{
		g_aPlayerEvents[client] = new ArrayList(sizeof(event_t));
	}
	else
	{
		g_aPlayerEvents[client].Clear();
	}
}

public void OnClientDisconnect(int client)
{
	if(g_aPlayerEvents[client] != null)
	{
		g_aPlayerEvents[client].Clear();
		delete g_aPlayerEvents[client];
	}
}

void LoadDHooks()
{
	GameData gamedataConf = LoadGameConfigFile("eventfix.games");
	
	if(gamedataConf == null)
	{
		SetFailState("Failed to load eventfix gamedata");
	}
	
	/*
	Handle acceptInput = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_CBaseEntity);
	DHookSetFromConf(acceptInput, gamedataConf, SDKConf_Signature, "AcceptInput");
	DHookAddParam(acceptInput, HookParamType_CharPtr);
	DHookAddParam(acceptInput, HookParamType_CBaseEntity);
	DHookAddParam(acceptInput, HookParamType_CBaseEntity);
	DHookAddParam(acceptInput, HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP);
	DHookAddParam(acceptInput, HookParamType_Int);
	if(!DHookEnableDetour(acceptInput, false, DHook_AcceptInput))
		SetFailState("Couldn't enable AcceptInput detour."); 
		
	Handle addEvent = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Ignore);
	DHookSetFromConf(addEvent, gamedataConf, SDKConf_Signature, "AddEvent");
	DHookAddParam(addEvent, HookParamType_CBaseEntity);
	DHookAddParam(addEvent, HookParamType_CharPtr);
	DHookAddParam(addEvent, HookParamType_Float);
	DHookAddParam(addEvent, HookParamType_CBaseEntity);
	DHookAddParam(addEvent, HookParamType_CBaseEntity);
	DHookAddParam(addEvent, HookParamType_Int);
	if(!DHookEnableDetour(addEvent, false, DHook_AddEvent))
		SetFailState("Couldn't enable AddEvent detour.");
	
	Handle addEventTwo = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Ignore);
	DHookSetFromConf(addEventTwo, gamedataConf, SDKConf_Signature, "AddEventTwo");
	DHookAddParam(addEventTwo, HookParamType_CBaseEntity);
	DHookAddParam(addEventTwo, HookParamType_CharPtr);
	DHookAddParam(addEventTwo, HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP);
	DHookAddParam(addEventTwo, HookParamType_Float);
	DHookAddParam(addEventTwo, HookParamType_CBaseEntity);
	DHookAddParam(addEventTwo, HookParamType_CBaseEntity);
	DHookAddParam(addEventTwo, HookParamType_Int);
	if(!DHookEnableDetour(addEventTwo, false, DHook_AddEventTwo))
		SetFailState("Couldn't enable AddEventTwo detour.");*/
	
	Handle addEventThree = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Ignore);
	DHookSetFromConf(addEventThree, gamedataConf, SDKConf_Signature, "AddEventThree");
	DHookAddParam(addEventThree, HookParamType_CharPtr);
	DHookAddParam(addEventThree, HookParamType_CharPtr);
	DHookAddParam(addEventThree, HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP);
	DHookAddParam(addEventThree, HookParamType_Float);
	DHookAddParam(addEventThree, HookParamType_CBaseEntity);
	DHookAddParam(addEventThree, HookParamType_CBaseEntity);
	DHookAddParam(addEventThree, HookParamType_Int);
	if(!DHookEnableDetour(addEventThree, false, DHook_AddEventThree))
		SetFailState("Couldn't enable AddEventThree detour.");
	
	
	delete gamedataConf;
}

/*
public MRESReturn DHook_AcceptInput(int pThis, Handle hReturn, Handle hParams)
{
	if(DHookIsNullParam(hParams, 2))
	{
		return MRES_Ignored;
	}

	int client = DHookGetParam(hParams, 2);
	char input[64];
	DHookGetParamString(hParams, 1, input, 64);
	char variantString[64];
	DHookGetParamObjectPtrString(hParams, 4, 0, ObjectValueType_String, variantString, 64);
	char args[2][64];
	ExplodeString(variantString, " ", args, 2, 64);

	return MRES_Ignored;
 } 

public MRESReturn DHook_AddEvent(Handle hParams)
{
	event_t event;
	int target = DHookGetParam(hParams, 1);
	DHookGetParamString(hParams, 2, event.targetInput, 64);
	event.delay = DHookGetParam(hParams, 3);
	event.activator = DHookGetParam(hParams, 4);
	event.caller = DHookGetParam(hParams, 5);
	event.outputID = DHookGetParam(hParams, 6);
	
	PrintToChatAll("AddEvent: %i, %s, %f, %i, %i, %i", target, event.targetInput, event.delay, event.activator, event.caller, event.outputID);
	return MRES_Ignored;
}


public MRESReturn DHook_AddEventTwo(Handle hParams)
{
	event_t event;
	int target = DHookGetParam(hParams, 1);
	DHookGetParamString(hParams, 2, event.targetInput, 64);
	DHookGetParamObjectPtrString(hParams, 3, 0, ObjectValueType_String, event.variantValue, sizeof(event.variantValue));
	event.delay = DHookGetParam(hParams, 4);
	event.activator = DHookGetParam(hParams, 5);
	event.caller = DHookGetParam(hParams, 6);
	event.outputID = DHookGetParam(hParams, 7);
	
	PrintToChatAll("AddEventTwo: %i, %s, %s, %f, %i, %i, %i", target, event.targetInput, event.variantValue, event.delay, event.activator, event.caller, event.outputID);
	return MRES_Ignored;
}*/

public MRESReturn DHook_AddEventThree(Handle hParams)
{
	if(DHookIsNullParam(hParams, 5))
		return MRES_Ignored;
	
	event_t event;
	DHookGetParamString(hParams, 1, event.target, 64);
	DHookGetParamString(hParams, 2, event.targetInput, 64);
	DHookGetParamObjectPtrString(hParams, 3, 0, ObjectValueType_String, event.variantValue, sizeof(event.variantValue));
	event.delay = DHookGetParam(hParams, 4);
	event.activator = DHookGetParam(hParams, 5);
	event.caller = DHookGetParam(hParams, 6);
	event.outputID = DHookGetParam(hParams, 7);
	
	#if defined DEBUG
		PrintToChatAll("AddEventThree: %s, %s, %s, %f, %i, %i, %i", event.target, event.targetInput, event.variantValue, event.delay, event.activator, event.caller, event.outputID);
	#endif
	
	if(!strcmp("!activator", event.target, false) && (event.activator < 65 && event.activator > 0))
	{
		g_aPlayerEvents[event.activator].PushArray(event);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	for(int i = 0; i < g_aPlayerEvents[client].Length; i++)
	{
		event_t event;
		g_aPlayerEvents[client].GetArray(i, event);
		
		if(event.delay <= 0.0)
		{
			SetVariantString(event.variantValue);
			AcceptEntityInput(client, event.targetInput, client, client, event.outputID); //right now I'm setting the client as the caller, because sourcemod freaks out if the caller isn't a regular CBaseEntity.
			
			#if defined DEBUG
				PrintToChat(client, "Performing output: %s, %i", event.variantValue, event.outputID);
			#endif
			
			g_aPlayerEvents[client].Erase(i);
		} 
		else
		{
			float timescale = Shavit_GetClientTimescale(client) != -1.0 ? Shavit_GetClientTimescale(client) : Shavit_GetStyleSettingFloat(Shavit_GetBhopStyle(client), "speed");
			
			event.delay -= GetTickInterval() * timescale;
			g_aPlayerEvents[client].SetArray(i, event);
		}
	}
}
