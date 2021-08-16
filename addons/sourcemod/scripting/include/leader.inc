#if defined _leader_included_
  #endinput
#endif
#define _leader_included_

/**
 * Returns current leader
 *
 * @return int    Client index of the leader (-1 = null)
 */
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