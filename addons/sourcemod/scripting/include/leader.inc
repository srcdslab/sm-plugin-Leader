#if defined _leader_included_
#endinput
#endif
#define _leader_included_

public SharedPlugin __pl_leader =
{
	name = "leader",
	file = "Leader.smx",
	#if defined REQUIRE_PLUGIN
		required = 1
	#else
		required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_leader_SetNTVOptional()
{
	MarkNativeAsOptional("Leader_SetLeader");
	MarkNativeAsOptional("Leader_IsClientLeader");
	MarkNativeAsOptional("Leader_IsLeaderOnline");
	MarkNativeAsOptional("Leader_IsCurrentLeaders");
}
#endif

/**
 * Returns current leader (Deprecated!!)
 *
 * @return int    Client index of the leader (-1 = null)
 */
#pragma deprecated Use Leader_IsCurrentLeaders() instead.
native int Leader_CurrentLeader();

/**
 * Sets the leader
 *
 * @param client    Client index to be set as leader
 */
native int Leader_SetLeader(int client);

/**
 * Checks if client is leader
 *
 * @param client    Client index to check if leader
 */
native int Leader_IsClientLeader(int client);

/**
 * Checks if any leader online 
 *
 * @return true/false
 */
native int Leader_IsLeaderOnline();

/**
 * Checks if client is a current leader
 *
 * @param client    Client index to check if client is a current leader
 */
native int Leader_IsCurrentLeaders(int client);