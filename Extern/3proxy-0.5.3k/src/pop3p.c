/*
   3APA3A simpliest proxy server
   (c) 2002-2006 by ZARAZA <3APA3A@security.nnov.ru>

   please read License Agreement

   $Id: pop3p.c,v 1.8 2006/03/10 19:25:50 vlad Exp $
*/

#include "proxy.h"

#define RETURN(xxx) { param->res = xxx; goto CLEANRET; }

void * pop3pchild(void * data) {
#define param ((struct clientparam*)data)
 int i=0, res;
 unsigned char buf[320];
 unsigned char *se;

 if(socksend(param->clisock, (unsigned char *)"+OK Proxy\r\n", 11, conf.timeouts[STRING_S])!=11) {RETURN (611);}
 i = sockgetlinebuf(param, CLIENT, buf, sizeof(buf) - 10, '\n', conf.timeouts[STRING_S]);
 while(i > 4 && strncasecmp((char *)buf, "USER", 4)){
	if(!strncasecmp((char *)buf, "QUIT", 4)){
		socksend(param->clisock, (unsigned char *)"+OK\r\n", 5,conf.timeouts[STRING_S]);	
		RETURN(0);
	}
	socksend(param->clisock, (unsigned char *)"-ERR need USER first\r\n", 22, conf.timeouts[STRING_S]);	
	i = sockgetlinebuf(param, CLIENT, buf, sizeof(buf) - 10, '\n', conf.timeouts[STRING_S]);
 }
 if(i<6) {RETURN(612);}
 
 buf[i] = 0;
 if ((se=(unsigned char *)strchr((char *)buf, '\r'))) *se = 0;
 if (strncasecmp((char *)buf, "USER ", 5)){RETURN (614);}
 if(!param->hostname && param->remsock == INVALID_SOCKET) {
	if(parseconnusername((char *)buf +5, param, 0, 110)){RETURN(615);}
 }
 else if(parseusername((char *)buf + 5, param, 0)) {RETURN(616);}
 param->operation = CONNECT;
 res = (*param->authfunc)(param);
 if(res) {RETURN(res);}
 i = sockgetlinebuf(param, SERVER, buf, sizeof(buf) - 1, '\n', conf.timeouts[STRING_L]);
 if( i < 3 ) {RETURN(621);}
 buf[i] = 0;
 if(strncasecmp((char *)buf, "+OK", 3)||!strncasecmp((char *)buf+4, "PROXY", 5)){RETURN(622);}
 if( socksend(param->remsock, (unsigned char *)"USER ", 5, conf.timeouts[STRING_S])!= 5 || 
	socksend(param->remsock, param->extusername, strlen((char *)param->extusername), conf.timeouts[STRING_S]) <= 0 ||
	socksend(param->remsock, (unsigned char *)"\r\n", 2, conf.timeouts[STRING_S])!=2)
		{RETURN(623);}
 param->statscli += (strlen((char *)param->extusername) + 7);
 RETURN (sockmap(param, 180));
CLEANRET:

 if(param->hostname&&param->extusername) {
	sprintf((char *)buf, "%.64s@%.128s%c%hu", param->extusername, param->hostname, (ntohs(param->sins.sin_port)==110)?0:':', ntohs(param->sins.sin_port));
	 (*param->logfunc)(param, buf);
 }
 else (*param->logfunc)(param, NULL);
 if(param->clisock != INVALID_SOCKET) {
	if ((param->res > 0 && param->res < 100) || (param->res > 611 && param->res <700)) socksend(param->clisock, (unsigned char *)"-ERR\r\n", 6,conf.timeouts[STRING_S]);
 }
 freeparam(param);
 return (NULL);
}

#ifdef WITHMAIN
struct proxydef childdef = {
	pop3pchild,
	110,
	0,
	S_POP3P
};
#include "proxymain.c"
#endif
