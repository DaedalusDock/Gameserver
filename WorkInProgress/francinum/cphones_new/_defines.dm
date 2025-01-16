#define NETCLASS_EXCHANGE "PNET_TELEX"
#define NETCLASS_SIPPHONE "PNET_TELSUB"

/// Ping Reply staple for telephone office identification
#define PACKET_FIELD_OFFICE_CODE "office_code"

/// data[command] 2.0
#define PACKET_FIELD_VERB "verb"

/// A high level 'group' of verbs
#define PACKET_FIELD_PROTOCOL "proto"
	#define PACKET_PROTOCOL_SIP "sip"
		// ----REGISTRATION----
		#define PACKET_SIP_VERB_REGISTER "register"
			#define PACKET_SIP_FIELD_USER "user"
			#define PACKET_SIP_FIELD_REGISTER_SECRET "auth"
		#define PACKET_SIP_VERB_REAUTH "reauth"
			#define PACKET_SIP_FIELD_AUTH_TOKEN "auth_token"
		#define PACKET_SIP_VERB_ACKNOWLEDGE "ack"
			//shares PACKET_SIP_FIELD_AUTH_TOKEN
		#define PACKET_SIP_VERB_NEGATIVE_ACKNOWLEDGE "nack"
			#define PACKET_SIP_FIELD_NACK_CAUSE "cause"
				#define PACKET_SIP_NACK_CAUSE_BAD_SECRET "badsecret"

		// ----CALL CONTROL----
		#define PACKET_SIP_FIELD_CALLID "call-id"
		#define PACKET_SIP_VERB_INVITE "invite"
			/// Sender
			#define PACKET_SIP_INVITE_FIELD_FROM "from"
			/// Invite recipient number.
			#define PACKET_SIP_INVITE_FIELD_TO "to"
		#define PACKET_SIP_VERB_SESSION "session"
			#define PACKET_SIP_SESSION_
	#define PACKET_PROTOCOL_RTP "rtp"


// SIP State values
#define SIP_STATE_CODE 1 //List Index
	#define SIP_STATE_CODE_START_RINGING 1 //No data
	#define SIP_STATE_CODE_STOP_RINGING 2 //No data
	#define SIP_STATE_TERMINATE 3 // data: Cause Code
	#define SIP_STATE_REG_FAILURE 4 //No data
#define SIP_STATE_DATA 2 //List Index

#error HEY DIPSHIT TEAR OUT A LOT OF YOUR SHIT AND IMPLIMENT STATUS CODES INSTEAD OF SHITTING YOURSELF LIKE A MONKEY
