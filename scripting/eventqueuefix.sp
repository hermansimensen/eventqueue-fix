
//#define DEBUG
//#define CSGO_WIN

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

// How many bits to use to encode an edict.
#define    MAX_EDICT_BITS                11            // # of bits needed to represent max edicts
// Max # of edicts in a level
#define    MAX_EDICTS                    (1<<MAX_EDICT_BITS)

// Used for networking ehandles.
#define NUM_ENT_ENTRY_BITS        (MAX_EDICT_BITS + 1)
#define NUM_ENT_ENTRIES            (1 << NUM_ENT_ENTRY_BITS)
#define ENT_ENTRY_MASK            (NUM_ENT_ENTRIES - 1)
#define INVALID_EHANDLE_INDEX    0xFFFFFFFF

ArrayList g_aPlayerEvents[MAXPLAYERS+1];
ArrayList g_aOutputWait[MAXPLAYERS+1];
bool g_bLateLoad;
Handle g_hFindEntityByName;
int g_iRefOffset;

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

enum struct entity_t
{
	int caller;
	float waitTime;
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
	HookEntityOutput("trigger_multiple", "OnTrigger", OnTrigger);
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
	
	if(g_aOutputWait[client] == null)
	{
		g_aOutputWait[client] = new ArrayList(sizeof(entity_t));
	}
	else
	{
		g_aOutputWait[client].Clear();
	}
}

public void OnClientDisconnect(int client)
{
	if(g_aPlayerEvents[client] != null)
	{
		g_aPlayerEvents[client].Clear();
	}
	
	if(g_aOutputWait[client] != null)
	{
		g_aOutputWait[client].Clear();
		delete g_aOutputWait[client];
	}
}

void LoadDHooks()
{
	GameData gamedataConf = LoadGameConfigFile("eventfix.games");

	if(gamedataConf == null)
	{
		SetFailState("Failed to load eventfix gamedata");
	}
	
	int m_RefEHandleOff = gamedataConf.GetOffset("m_RefEHandle");
	int ibuff = gamedataConf.GetOffset("m_angRotation");
	g_iRefOffset = ibuff + m_RefEHandleOff;
	
	#if defined CSGO_WIN
		StartPrepSDKCall(SDKCall_Static);
	#else
		StartPrepSDKCall(SDKCall_EntityList);
	#endif
	
	PrepSDKCall_SetFromConf(gamedataConf, SDKConf_Signature, "FindEntityByName");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hFindEntityByName = EndPrepSDKCall();

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
		SetFailState("Couldn't enable AddEventTwo detour.");
	*/

	Handle addEventThree = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Ignore);
	DHookSetFromConf(addEventThree, gamedataConf, SDKConf_Signature, "AddEventThree");
	DHookAddParam(addEventThree, HookParamType_CharPtr);
	DHookAddParam(addEventThree, HookParamType_CharPtr);
	DHookAddParam(addEventThree, HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP);
	DHookAddParam(addEventThree, HookParamType_Float);
	DHookAddParam(addEventThree, HookParamType_Int);
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
		return MRES_Ignored;

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
} */

//Credits to gammacase for this workaround.
int EntityToBCompatRef(Address player)
{
	if(player == Address_Null)
		return INVALID_EHANDLE_INDEX;
	
	int m_RefEHandle = LoadFromAddress(player + view_as<Address>(g_iRefOffset), NumberType_Int32);
	
	if(m_RefEHandle == INVALID_EHANDLE_INDEX)
		return INVALID_EHANDLE_INDEX;
	
	// https://github.com/perilouswithadollarsign/cstrike15_src/blob/29e4c1fda9698d5cebcdaf1a0de4b829fa149bf8/public/basehandle.h#L137
	int entry_idx = m_RefEHandle & ENT_ENTRY_MASK;
	
	if(entry_idx >= MAX_EDICTS)
		return m_RefEHandle | (1 << 31);
	
	return entry_idx;
}

public MRESReturn DHook_AddEventThree(Handle hParams)
{
	event_t event;
	DHookGetParamString(hParams, 1, event.target, 64);
	DHookGetParamString(hParams, 2, event.targetInput, 64);
	DHookGetParamObjectPtrString(hParams, 3, 0, ObjectValueType_String, event.variantValue, sizeof(event.variantValue));
	event.delay = DHookGetParam(hParams, 4);
	event.activator = EntityToBCompatRef(view_as<Address>(DHookGetParam(hParams, 5)));
	event.caller = DHookGetParam(hParams, 6);
	event.outputID = DHookGetParam(hParams, 7);
	
	#if defined DEBUG
		PrintToChatAll("AddEventThree: %s, %s, %s, %f, %i, %i, %i", event.target, event.targetInput, event.variantValue, event.delay, event.activator, event.caller, event.outputID);
	#endif
	
	if((event.activator < 65 && event.activator > 0))
	{
		g_aPlayerEvents[event.activator].PushArray(event);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public Action OnTrigger(const char[] output, int caller, int activator, float delay)
{
	if(activator <= MAXPLAYERS && activator > 0)
	{
		float m_flWait = GetEntPropFloat(caller, Prop_Data, "m_flWait");
		
		bool bFound;
		entity_t ent;
		for(int i = 0; i < g_aOutputWait[activator].Length; i++)
		{
			g_aOutputWait[activator].GetArray(i, ent);
			
			if(caller == ent.caller)
			{
				bFound = true;
				break;
			}
		}
		
		if(!bFound)
		{
			ent.caller = caller;
			ent.waitTime = m_flWait;
			g_aOutputWait[activator].PushArray(ent);	
			return Plugin_Continue;
		}
		else
		{
			return Plugin_Handled;
		}
	} 
	return Plugin_Continue;
}

public void ServiceEvent(event_t event)
{
	SetVariantString(event.variantValue);
	int targetEntity;
	if(!strcmp("!activator", event.target, false))
	{
		targetEntity = event.activator;
		AcceptEntityInput(targetEntity, event.targetInput, event.activator, event.caller, event.outputID);
	}
	else if(!strcmp("!caller", event.target, false))
	{
		targetEntity = event.caller;
		AcceptEntityInput(targetEntity, event.targetInput, event.activator, event.caller, event.outputID);
	}
	else if(!strcmp("!self", event.target, false))
	{
		targetEntity = event.caller;
		AcceptEntityInput(targetEntity, event.targetInput, event.activator, event.caller, event.outputID);
	}
	else
	{
		if(!strcmp("kill", event.targetInput, false))
		{
			for(int i = 0; i < 32; i++)
			{
				targetEntity = SDKCall(g_hFindEntityByName, 0, event.target, event.caller, event.activator, event.caller, 0);
				if(targetEntity != -1)
				{
					AcceptEntityInput(targetEntity, event.targetInput, event.activator, event.caller, event.outputID);
				} else
				{
					break;
				}
			}
		} 
		else
		{
			targetEntity = SDKCall(g_hFindEntityByName, 0, event.target, event.caller, event.activator, event.caller, 0);
			if(targetEntity != -1)
			{
				AcceptEntityInput(targetEntity, event.targetInput, event.activator, event.caller, event.outputID);
			}
		}
	}

	#if defined DEBUG
		PrintToChat(event.activator, "Performing output: %s, %i, %i, %s %s, %i, %f", event.target, targetEntity, event.caller, event.targetInput, event.variantValue, event.outputID, GetGameTime());
	#endif
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	float timescale = Shavit_GetClientTimescale(client) != -1.0 ? Shavit_GetClientTimescale(client) : Shavit_GetStyleSettingFloat(Shavit_GetBhopStyle(client), "speed");
	
	for(int i = 0; i < g_aOutputWait[client].Length; i++)
	{
		entity_t ent;
		g_aOutputWait[client].GetArray(i, ent);
		
		if(ent.waitTime <= GetTickInterval() * timescale)
		{
			g_aOutputWait[client].Erase(i);
			i--;
		}
		else
		{
			ent.waitTime -= GetTickInterval() * timescale;
			g_aOutputWait[client].SetArray(i, ent);
		}
	}
	
	for(int i = 0; i < g_aPlayerEvents[client].Length; i++)
	{
		event_t event;
		g_aPlayerEvents[client].GetArray(i, event);

		if(event.delay <= GetTickInterval() * timescale)
		{
			ServiceEvent(event);
			g_aPlayerEvents[client].Erase(i);
			i--;
		}
		else
		{
			event.delay -= GetTickInterval() * timescale;
			g_aPlayerEvents[client].SetArray(i, event);
		}
	}
}