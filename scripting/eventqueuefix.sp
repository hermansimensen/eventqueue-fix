
//#define DEBUG

#define PLUGIN_NAME           "EventQueue fix"
#define PLUGIN_AUTHOR         "carnifex"
#define PLUGIN_DESCRIPTION    ""
#define PLUGIN_VERSION        "1.3.3"
#define PLUGIN_URL            ""

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <eventqueuefix>

#pragma semicolon 1

#define FLT_EPSILON 1.192092896e-07
// How many bits to use to encode an edict.
#define    MAX_EDICT_BITS                11            // # of bits needed to represent max edicts
// Max # of edicts in a level
#define    MAX_EDICTS                    (1<<MAX_EDICT_BITS)

// Used for networking ehandles.
#define NUM_ENT_ENTRY_BITS        (MAX_EDICT_BITS + 1)
#define NUM_ENT_ENTRIES            (1 << NUM_ENT_ENTRY_BITS)
#define ENT_ENTRY_MASK            (NUM_ENT_ENTRIES - 1)
#define INVALID_EHANDLE_INDEX    0xFFFFFFFF

ArrayList g_aPlayerEvents[MAXPLAYERS + 1];
ArrayList g_aOutputWait[MAXPLAYERS + 1];
bool g_bPaused[MAXPLAYERS + 1];
bool g_bLateLoad;
Handle g_hFindEntityByName;
int g_iRefOffset;

float g_fTimescale[MAXPLAYERS + 1];

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
	CreateNative("GetClientEvents", Native_GetClientEvents);
	CreateNative("SetClientEvents", Native_SetClientEvents);
	CreateNative("ClearClientEvents", Native_ClearClientEvents);
	CreateNative("SetEventsTimescale", Native_SetEventsTimescale);
	CreateNative("IsClientEventsPaused", Native_IsClientPaused);
	CreateNative("SetClientEventsPaused", Native_SetClientPaused);
	
	g_bLateLoad = late;
	
	RegPluginLibrary("eventqueuefix");
	
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
	g_fTimescale[client] = 1.0;
	g_bPaused[client] = false;
	
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

public void OnClientDisconnect_Post(int client)
{
	delete g_aPlayerEvents[client];
	delete g_aOutputWait[client];
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_button"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Hook_Button_OnTakeDamage);
	}
}

void LoadDHooks()
{
	GameData gamedataConf = new GameData("eventfix.games");

	if(gamedataConf == null)
	{
		SetFailState("Failed to load eventfix gamedata");
	}
	
	int m_RefEHandleOff = gamedataConf.GetOffset("m_RefEHandle");
	int ibuff = gamedataConf.GetOffset("m_angRotation");
	g_iRefOffset = ibuff + m_RefEHandleOff;
	
	if (gamedataConf.GetOffset("FindEntityByName_StaticCall") == 1)
		StartPrepSDKCall(SDKCall_Static);
	else
		StartPrepSDKCall(SDKCall_EntityList);
	
	if(!PrepSDKCall_SetFromConf(gamedataConf, SDKConf_Signature, "FindEntityByName"))
		SetFailState("Faild to find FindEntityByName signature.");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue); 
	g_hFindEntityByName = EndPrepSDKCall();

	Handle addEventThree = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Ignore);
	if(!DHookSetFromConf(addEventThree, gamedataConf, SDKConf_Signature, "AddEventThree"))
		SetFailState("Faild to find AddEventThree signature.");
	DHookAddParam(addEventThree, HookParamType_CharPtr);
	DHookAddParam(addEventThree, HookParamType_CharPtr);
	if (gamedataConf.GetOffset("LINUX") == 1)
		DHookAddParam(addEventThree, HookParamType_ObjectPtr);
	else
		DHookAddParam(addEventThree, HookParamType_Object, 20);
	DHookAddParam(addEventThree, HookParamType_Float);
	DHookAddParam(addEventThree, HookParamType_Int);
	DHookAddParam(addEventThree, HookParamType_Int);
	DHookAddParam(addEventThree, HookParamType_Int);
	if(!DHookEnableDetour(addEventThree, false, DHook_AddEventThree))
		SetFailState("Couldn't enable AddEventThree detour.");
	
	Handle activateMultiTrigger = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if(!DHookSetFromConf(activateMultiTrigger, gamedataConf, SDKConf_Signature, "ActivateMultiTrigger"))
		SetFailState("Faild to find ActivateMultiTrigger signature.");
	DHookAddParam(activateMultiTrigger, HookParamType_CBaseEntity);
	if(!DHookEnableDetour(activateMultiTrigger, false, DHook_ActivateMultiTrigger))
		SetFailState("Couldn't enable ActivateMultiTrigger detour.");
	
	delete gamedataConf;
}

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
	event.activator = EntityToBCompatRef(view_as<Address>(DHookGetParam(hParams, 5)));
	int entIndex = EntRefToEntIndex(event.activator);

	if (entIndex < 1 || entIndex > MaxClients)
	{
		return MRES_Ignored;
	}
	
	DHookGetParamString(hParams, 1, event.target, 64);
	DHookGetParamString(hParams, 2, event.targetInput, 64);
	ResolveVariantValue(hParams, event);
	
	int ticks = RoundToCeil((view_as<float>(DHookGetParam(hParams, 4)) - FLT_EPSILON) / GetTickInterval());
	event.delay = float(ticks);
	event.caller = EntityToBCompatRef(view_as<Address>(DHookGetParam(hParams, 6)));
	event.outputID = DHookGetParam(hParams, 7);

	#if defined DEBUG
		PrintToServer("[%i] AddEventThree: %s, %s, %s, %f, %i, %i, %i, time: %f", GetGameTickCount(), event.target, event.targetInput, event.variantValue, event.delay, entIndex, EntRefToEntIndex(event.caller), event.outputID, GetGameTime());
	#endif

	g_aPlayerEvents[entIndex].PushArray(event);
	return MRES_Supercede;
}

public void ResolveVariantValue(Handle &params, event_t event)
{
	int type = DHookGetParamObjectPtrVar(params, 3, 16, ObjectValueType_Int);
	
	switch(type)
	{
		//Float
		case 1:
		{
			float fVar = DHookGetParamObjectPtrVar(params, 3, 0, ObjectValueType_Float);
			
			//Type recognition is difficult, even for valve programmers. Sometimes floats are integers, lets fix that.
			if(FloatAbs(fVar - RoundFloat(fVar)) < 0.000001)
			{
				IntToString(RoundFloat(fVar), event.variantValue, sizeof(event.variantValue));
			} else
			{
				FloatToString(fVar, event.variantValue, sizeof(event.variantValue));
			}
		}
		
		//Integer
		case 5:
		{
			int iVar = DHookGetParamObjectPtrVar(params, 3, 0, ObjectValueType_Int);
			IntToString(iVar, event.variantValue, sizeof(event.variantValue));
		}
		
		//Color32
		case 9:
		{
			int iVar = DHookGetParamObjectPtrVar(params, 3, 0, ObjectValueType_Int);
			FormatEx(event.variantValue, sizeof(event.variantValue), "%d %d %d", (iVar&0xFF), (iVar&0xFF00) >> 8, (iVar&0xFF0000) >> 16);
		}
		
		default:
		{
			DHookGetParamObjectPtrString(params, 3, 0, ObjectValueType_String, event.variantValue, sizeof(event.variantValue));
		}
	}
}

public MRESReturn DHook_ActivateMultiTrigger(int pThis, DHookParam hParams)
{
	int client = hParams.Get(1);
	
	if(!(0 < client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client))
		return MRES_Ignored;
	
	float m_flWait = GetEntPropFloat(pThis, Prop_Data, "m_flWait");
	
	bool bFound;
	entity_t ent;
	for(int i = 0; i < g_aOutputWait[client].Length; i++)
	{
		g_aOutputWait[client].GetArray(i, ent);
		
		if(pThis == EntRefToEntIndex(ent.caller))
		{
			bFound = true;
			break;
		}
	}
	
	if(!bFound)
	{
		ent.caller = EntIndexToEntRef(pThis);
		int ticks = RoundToCeil((m_flWait - FLT_EPSILON) / GetTickInterval());
		ent.waitTime = float(ticks);
		g_aOutputWait[client].PushArray(ent);
		SetEntProp(pThis, Prop_Data, "m_nNextThinkTick", 0);
		return MRES_Ignored;
	}
	
	return MRES_Supercede;
}

int FindEntityByName(int startEntity, char[] targetname, int searchingEnt, int activator, int caller)
{
	Address targetEntityAddr = SDKCall(g_hFindEntityByName, startEntity, targetname, searchingEnt, activator, caller, 0);
	
	if(targetEntityAddr == Address_Null)
		return -1;
		
	return EntRefToEntIndex(EntityToBCompatRef(targetEntityAddr));
}

public void ServiceEvent(event_t event)
{
	int targetEntity = -1;
	
	int caller = EntRefToEntIndex(event.caller);
	int activator = EntRefToEntIndex(event.activator);
	
	if(!IsValidEntity(caller))
		caller = -1;

	bool byTargetname = false;
	
	// In the context of the event, the searching entity is also the caller
	while ((targetEntity = FindEntityByName(targetEntity, event.target, caller, activator, caller)) != -1)
	{
		byTargetname = true;

		SetVariantString(event.variantValue);
		AcceptEntityInput(targetEntity, event.targetInput, activator, caller, event.outputID);
		
		#if defined DEBUG
			PrintToServer("[%i] Performing output: %s, %i, %i, %s %s, %i, %f", GetGameTickCount(), event.target, targetEntity, caller, event.targetInput, event.variantValue, event.outputID, GetGameTime());
		#endif
	} 

	if (!byTargetname)
	{
		// In the context of the event, the searching entity is also the caller
		while ((targetEntity = FindEntityByClassname(targetEntity, event.target)) != -1)
		{
			SetVariantString(event.variantValue);
			AcceptEntityInput(targetEntity, event.targetInput, activator, caller, event.outputID);

			#if defined DEBUG
				PrintToServer("[%i] Performing output (w/ classname): %s, %i, %i, %s %s, %i, %f", GetGameTickCount(), event.target, targetEntity, caller, event.targetInput, event.variantValue, event.outputID, GetGameTime());
			#endif
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(g_bPaused[client])
		return Plugin_Continue;
	
	float timescale = g_fTimescale[client];

	for(int i = 0; i < g_aOutputWait[client].Length; i++)
	{
		entity_t ent;
		g_aOutputWait[client].GetArray(i, ent);
		
		ent.waitTime -= 1.0 * timescale;
		g_aOutputWait[client].SetArray(i, ent);
		
		if(ent.waitTime <= 1.0 * timescale)
		{
			g_aOutputWait[client].Erase(i);
			i--;
		}
	}
	
	for(int i = 0; i < g_aPlayerEvents[client].Length; i++)
	{
		event_t event;
		g_aPlayerEvents[client].GetArray(i, event);
		
		event.delay -= 1.0 * timescale;
		
		g_aPlayerEvents[client].SetArray(i, event);
		if(event.delay <= -1.0 * timescale)
		{
			ServiceEvent(event);
			g_aPlayerEvents[client].Erase(i);
			i--;
		}
	}
	
	return Plugin_Continue;
}

public Action Hook_Button_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// func_button fires the OnDamage output before setting m_hActivator to the attacker.
	// This means m_hActivator can be unset or a previous attacker.
	// This is a problem at bhop_badges level 13 and also the booster in the ladder room.
	SetEntPropEnt(victim, Prop_Data, "m_hActivator", attacker);
	return Plugin_Continue;
}

public any Native_GetClientEvents(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return false;

	ArrayList pe = g_aPlayerEvents[client].Clone();
	ArrayList ow = g_aOutputWait[client].Clone();

	eventpack_t ep;
	ep.playerEvents = view_as<ArrayList>(CloneHandle(pe, plugin));
	ep.outputWaits = view_as<ArrayList>(CloneHandle(ow, plugin));

	delete pe;
	delete ow;
	
	SetNativeArray(2, ep, sizeof(eventpack_t));
	return true;
}

public any Native_SetClientEvents(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return false;
		
	eventpack_t ep;
	GetNativeArray(2, ep, sizeof(eventpack_t));
	
	delete g_aPlayerEvents[client];
	delete g_aOutputWait[client];
	
	g_aPlayerEvents[client] = ep.playerEvents.Clone();
	g_aOutputWait[client] = ep.outputWaits.Clone();
	
 	int length = g_aPlayerEvents[client].Length;

	for (int i = 0; i < length; i++)
    {
        event_t event;
        g_aPlayerEvents[client].GetArray(i, event);
        event.activator = EntIndexToEntRef(client);
        g_aPlayerEvents[client].SetArray(i, event);
    }
	
	return true;
}

public any Native_SetEventsTimescale(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return false;
	
	g_fTimescale[client] = GetNativeCell(2);
	
	return true;
}

public any Native_ClearClientEvents(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return false;
	
	g_aOutputWait[client].Clear();
	g_aPlayerEvents[client].Clear();
	
	return true;
}

public any Native_SetClientPaused(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool pauseState = GetNativeCell(2);
	
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return false;
		
	g_bPaused[client] = pauseState;
	
	return true;
}

public any Native_IsClientPaused(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(client < 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client))
		return ThrowNativeError(032, "Client is invalid.");
		
	return g_bPaused[client];
}
