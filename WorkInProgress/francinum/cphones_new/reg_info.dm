/datum/tel_extension
	/// 'name' - the extension number. Used mostly for VV. Canon extension is this thing's key in an exchanges' extensions list.
	var/name
	/// Auth secret. Required to act as this extension.
	var/auth_secret
	/// Caller Name. Replacement for p2p_phone friendly_name. Optional, Uses the extension number otherwise.
	var/cnam
	/// Registered phones, k,v netaddr=exp_time, Registration will expire if not renewed every minute.
	var/list/registered = list()
	/// Registration tokens, k,v netaddr=token. Used for keepalive.
	var/list/reg_tokens = list()

