/*
   3APA3A simpliest proxy server
   (c) 2002-2006 by ZARAZA <3APA3A@security.nnov.ru>

   please read License Agreement

   $Id: socks.c,v 1.24 2006/07/07 21:24:57 vlad Exp $
*/

#include "proxy.h"

//#define SOCKSTRACE 5

#define RETURN(xxx) { param->res = xxx; goto CLEANRET; }

unsigned char * commands[] = {(unsigned char *)"UNKNOWN", (unsigned char *)"CONNECT", (unsigned char *)"BIND", (unsigned char *)"UDPMAP"};

struct datatable socks_table = {
	STRINGTABLE,
	sizeof(commands)/sizeof(unsigned char *),
	(void *)commands
};

#define BUFSIZE 1024
#define LARGEBUFSIZE 67000

void * sockschild(void * data) {
#define param ((struct clientparam*)data)
 int res;
 unsigned i=0;
 SOCKET s;
 unsigned size;
 SASIZETYPE sasize;
 unsigned char * buf=NULL;
 unsigned char c;
 unsigned char command=0;
 struct in_addr reqaddr;
 struct pollfd fds[3];
 int ver=0;
 int havepass = 0;
 struct sockaddr_in sin;
 int len;


 reqaddr.s_addr = 0;
 param->service = S_SOCKS;

 if(!(buf = myalloc(BUFSIZE))) {RETURN(21);}
 memset(buf, 0, BUFSIZE);
 if ((ver = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_L], 0)) != 5 && ver != 4) {
	 //fprintf(stderr, "version read = %u\n", ver);
	RETURN(401);
 } /* version */
 param->service = ver;
 if(ver == 5){
	 if ((i = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(441);} /* nmethods */
	 for (; i; i--) {
		if ((res = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(442);}
		if (res == 2) {
			havepass = res;
		}
	 }
	 buf[0] = 5;
	 buf[1] = havepass;
	 if(socksend(param->clisock, buf, 2, conf.timeouts[STRING_S])!=2){RETURN(402);}
	 if (havepass) {
		if (((res = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_L], 0))) != 1) {
			RETURN(412);
		}
		if ((i = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(443);}
		if (i && (unsigned)(res = sockgetlinebuf(param, CLIENT, buf, i, 0, conf.timeouts[STRING_S])) != i){RETURN(444);};
		buf[i] = 0;
		if(!param->username)param->username = (unsigned char *)mystrdup((char *)buf);
		if ((i = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(445);}
		if (i && (unsigned)(res = sockgetlinebuf(param, CLIENT, buf, i, 0, conf.timeouts[STRING_S])) != i){RETURN(446);};
		buf[i] = 0;
		if(!param->password)param->password = (unsigned char *)mystrdup((char *)buf);
		buf[0] = 1;
		buf[1] = 0;
		if(socksend(param->clisock, buf, 2, conf.timeouts[STRING_S])!=2){RETURN(402);}
	 }
	 if ((c = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_L], 0)) != 5) {
		RETURN(421);
         } /* version */
 }
 if( (command = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) < 1 || command > 3){command = 0; RETURN(407);} /* command */
 if(ver == 5){
	 if (sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0) == EOF) {RETURN(447);} /* reserved */
	 c = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0); /* atype */
 }
 else {
	if ((res = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(448);}
	buf[0] = (unsigned char) res;
	if ((res = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(449);}
	buf[1] = (unsigned char) res;
	param->sins.sin_port = param->reqport = *(unsigned short*)buf;
	c = 1;
 }
 
 switch(c) {
	case 1:
		for (i = 0; i<4; i++){
			if ((res = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(450);}
			buf[i] = (unsigned char)res;
		}
		param->sins.sin_addr.s_addr = reqaddr.s_addr = *(unsigned long *)buf;
		if(command==1 && !reqaddr.s_addr) {
			RETURN(422);
		}
		myinet_ntoa(param->sins.sin_addr, (char *)buf);
		break;
	case 3:
		if ((size = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(451);} /* nmethods */
		for (i=0; i<size; i++){ /* size < 256 */
			if ((res = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(452);}
			buf[i] = (unsigned char)res;
		}
		buf[i] = 0;
		param->sins.sin_addr.s_addr = reqaddr.s_addr = getip(buf);
		if(command==1 && !reqaddr.s_addr) {
			RETURN(423);
		}
		break;
	default:
		RETURN(998);
 }
 if(param->hostname)myfree(param->hostname);
 param->hostname = (unsigned char *)mystrdup((char *)buf);
 if (ver == 5) {
	 if ((res = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(453);}
	 buf[0] = (unsigned char) res;
	 if ((res = sockgetcharcli(param, conf.timeouts[SINGLEBYTE_S], 0)) == EOF) {RETURN(454);}
	 buf[1] = (unsigned char) res;
	 param->sins.sin_port = param->reqport = *(unsigned short*)buf;
 }
 else {
	sockgetlinebuf(param, CLIENT, buf, BUFSIZE - 1, 0, conf.timeouts[STRING_S]);
	buf[127] = 0;
	if(*buf && !param->username)param->username = (unsigned char *)mystrdup((char *)buf);
	if(param->sins.sin_addr.s_addr && ntohl(param->sins.sin_addr.s_addr)<256){
		param->service = S_SOCKS45;
		sockgetlinebuf(param, CLIENT, buf, BUFSIZE - 1, 0, conf.timeouts[STRING_S]);
		buf[127] = 0;
		if(param->hostname)myfree(param->hostname);
		param->hostname = (unsigned char *)mystrdup((char *)buf);
		param->sins.sin_addr.s_addr = reqaddr.s_addr = getip(buf);
	}
 }
 if(command == 1 && !param->reqport) {RETURN(424);}
 param->sins.sin_family = AF_INET;
 switch(command) { 
	case 1:
	 param->operation = CONNECT;
	 break;
 	case 2:
	 param->sins.sin_addr.s_addr = param->extip;
	 param->sins.sin_port = param->extport?param->extport:param->reqport;
	 if ((param->remsock=socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) == INVALID_SOCKET) {RETURN (11);}
	 param->operation = BIND;
	 break;
	case 3:
	 param->sins.sin_port = param->extport?param->extport:param->reqport;
	 param->sins.sin_addr.s_addr = param->extip;
	 if ((param->remsock=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == INVALID_SOCKET) {RETURN (11);}
	 param->operation = UDPASSOC;
	 break;
	default:
	 RETURN(997);
 }

 if((res = (*param->authfunc)(param))) {RETURN(res);}

 if(command > 1) {
	if(bind(param->remsock,(struct sockaddr *)&param->sins,sizeof(param->sins))) {
		param->sins.sin_port = 0;
		if(bind(param->remsock,(struct sockaddr *)&param->sins,sizeof(param->sins)))RETURN (12);
#if SOCKSTRACE > 0
fprintf(stderr, "%s:%hu binded to communicate with server\n",
			inet_ntoa(param->sins.sin_addr),
			ntohs(param->sins.sin_port)
	);
fflush(stderr);
#endif
	}
	sasize = sizeof(struct sockaddr_in);
	getsockname(param->remsock, (struct sockaddr *)&param->sins,  &sasize);
	if(command == 3) {
		param->ctrlsock = param->clisock;
		param->clisock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
		if(param->clisock == INVALID_SOCKET) {RETURN(11);}
		sin.sin_family = AF_INET;
		sin.sin_addr.s_addr = param->intip;
		sin.sin_port = htons(0);
		if(bind(param->clisock,(struct sockaddr *)&sin,sizeof(struct sockaddr_in))) {RETURN (12);}
#if SOCKSTRACE > 0
fprintf(stderr, "%s:%hu binded to communicate with client\n",
			inet_ntoa(sin.sin_addr),
			ntohs(sin.sin_port)
	);
fflush(stderr);
#endif
	}
 }
 param->res = 0;

CLEANRET:

 if(param->clisock != INVALID_SOCKET){
	sasize = sizeof(struct sockaddr_in);
	if(command != 3) getsockname(param->remsock, (struct sockaddr *)&sin,  &sasize);
	else getsockname(param->clisock, (struct sockaddr *)&sin,  &sasize);
#if SOCKSTRACE > 0
	 //fprintf(stderr, "command = %i\n", command); 
fprintf(stderr, "Sending confirmation to client with code %d for %s with %s:%hu\n",
			param->res,
			commands[command],
			inet_ntoa(sin.sin_addr),
			ntohs(sin.sin_port)
	);
fflush(stderr);
#endif
	if(ver == 5){
		buf[0] = 5;
		buf[1] = param->res%10;
		buf[2] = 0;
		buf[3] = 1;
		memcpy(buf+4, &sin.sin_addr.s_addr, 4);
		memcpy(buf+8, &sin.sin_port, 2);
		socksend((command == 3)?param->ctrlsock:param->clisock, buf, 10, conf.timeouts[STRING_S]);
	}
	else{
		buf[0] = 0;
		buf[1] = 90 + (param->res%10);
		memcpy(buf+2, &sin.sin_port, 2);
		memcpy(buf+4, &sin.sin_addr.s_addr, 4);
		socksend(param->clisock, buf, 8, conf.timeouts[STRING_S]);
	}

	if (param->res == 0) {
		switch(command) {
			case 1:
				if(param->redirectfunc){
					if(buf)myfree(buf);
					return (*param->redirectfunc)(param);
				}
				param->res = sockmap(param, conf.timeouts[CONNECTION_L]);
				break;
			case 2:
				listen (param->remsock, 1);
				
				fds[0].fd = param->remsock;
				fds[1].fd = param->clisock;
				fds[0].events = fds[1].events = POLLIN;
				res = poll(fds, 2, conf.timeouts[(reqaddr.s_addr)?CONNECTION_S:CONNECTION_L] * 1000);
				if (res < 1 || fds[1].revents) {
					res = 460;
					break;
				}
				sasize = sizeof(param->sins);
				s = accept(param->remsock, (struct sockaddr *)&param->sins, &sasize);
				shutdown(param->remsock, SHUT_RDWR);
				closesocket(param->remsock);
				param->remsock = s;
				if(s == INVALID_SOCKET) {
					param->res = 462;
					break;
				}
				if(reqaddr.s_addr && reqaddr.s_addr != param->sins.sin_addr.s_addr) {
					param->res = 470;
					break;
				}
#if SOCKSTRACE > 0
fprintf(stderr, "Sending incoming connection to client with code %d for %s with %s:%hu\n",
			param->res,
			commands[command],
			inet_ntoa(param->sins.sin_addr),
			ntohs(param->sins.sin_port)
	);
fflush(stderr);
#endif
				if(ver == 5){
					memcpy (buf+4, &param->sins.sin_addr, 4);
					memcpy (buf+8, &param->sins.sin_port, 2);
					socksend(param->clisock, buf, 10, conf.timeouts[STRING_S]);
				}
				else {
					memcpy (buf+2, &param->sins.sin_port, 2);
					memcpy (buf+4, &param->sins.sin_addr, 4);
					socksend(param->clisock, buf, 8, conf.timeouts[STRING_S]);
				}

				param->res = sockmap(param, conf.timeouts[CONNECTION_S]);
				break;
			case 3:
				param->sins.sin_addr.s_addr = reqaddr.s_addr;
				param->sins.sin_port = param->reqport;
				myfree(buf);
				if(!(buf = myalloc(LARGEBUFSIZE))) {RETURN(21);}

				for(;;){
					fds[0].fd = param->remsock;
					fds[1].fd = param->clisock;
					fds[2].fd = param->ctrlsock;
					fds[2].events = fds[1].events = fds[0].events = POLLIN;

					res = poll(fds, 3, conf.timeouts[CONNECTION_L]*1000);
					if(res <= 0) {
						param->res = 463;
						break;
					}
					if (fds[2].revents) {
						param->res = 0;
						break;
					}
					if (fds[1].revents) {
						sasize = sizeof(struct sockaddr_in);
						if((len = recvfrom(param->clisock, buf, 65535, 0, (struct sockaddr *)&sin, &sasize)) <= 10) {
							param->res = 464;
							break;
						}
						if(sin.sin_addr.s_addr != param->sinc.sin_addr.s_addr){
							param->res = 465;
							break;
						}
						if(buf[0] || buf[1] || buf[2]) {
							param->res = 466;
							break;
						}
						switch(buf[3]) {
							case 1:
								i = 8;
								memcpy(&param->sins.sin_addr.s_addr, buf+4, 4);
								break;
							case 3:
								size = buf[4];
								for (i=4; size; i++, size--){
									buf[i] = buf[i+1];
								}
								buf[i++] = 0;
								param->sins.sin_addr.s_addr = getip(buf+4);
								break;
							default:
								RETURN(996);
						 }

						memcpy(&param->sins.sin_port, buf+i, 2);
						i+=2;

						sasize = sizeof(param->sins);
						if(len > (int)i){
							if(socksendto(param->remsock, &param->sins, buf+i, len - i, conf.timeouts[SINGLEBYTE_L]*1000) <= 0){
								param->res = 467;
								break;
							}
							param->statscli+=(len - i);
#if SOCKSTRACE > 1
fprintf(stderr, "UDP packet relayed from client to %s:%hu size %d, header %d\n",
			inet_ntoa(param->sins.sin_addr),
			ntohs(param->sins.sin_port),
			(len - i),
			i
	);
fprintf(stderr, "client address is assumed to be %s:%hu\n",
			inet_ntoa(sin.sin_addr),
			ntohs(sin.sin_port)
	);
fflush(stderr);
#endif
						}

					}
					if (fds[0].revents) {
						struct sockaddr_in tsin;
						sasize = sizeof(tsin);
						buf[0]=buf[1]=buf[2]=0;
						buf[3]=1;
						if((len = recvfrom(param->remsock, buf+10, 65535 - 10, 0, (struct sockaddr *)&tsin, &sasize)) <= 0) {
							param->res = 468;
							break;
						}
						param->statssrv+=len;
						memcpy(buf+4, &tsin.sin_addr.s_addr, 4);
						memcpy(buf+8, &tsin.sin_port, 2);
						sasize = sizeof(param->sins);
						if(socksendto(param->clisock, &sin, buf, len + 10, conf.timeouts[SINGLEBYTE_L]*1000) <=0){
							param->res = 469;
							break;
						}
#if SOCKSTRACE > 1
fprintf(stderr, "UDP packet relayed to client from %s:%hu size %d\n",
			inet_ntoa(tsin.sin_addr),
			ntohs(tsin.sin_port),
			len
	);
fflush(stderr);
#endif

					}
				}
				break;
			default:
				param->res = 417;
				break;
		}
	}
 }
 
 if(command > 3) command = 0;
 if(buf){
	 sprintf((char *)buf, "%s ", commands[command]);
	 if(param->hostname){
	  sprintf((char *)buf + strlen((char *)buf), "%.265s", param->hostname);
	 }
	 else myinet_ntoa(reqaddr, (char *)buf+strlen((char *)buf));
         sprintf((char *)buf+strlen((char *)buf), ":%hu", ntohs(param->reqport));
	 (*param->logfunc)(param, buf);
	 myfree(buf);
 }
 freeparam(data);
 return (NULL);
}

